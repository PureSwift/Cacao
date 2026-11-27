//
//  DBusMenuReader.swift
//  CacaoDBusMenu
//
//  Created by Alsey Coleman Miller on 11/24/26.
//

public import DBus
internal import StatusNotifier

/// Reads an app's menu from its `com.canonical.dbusmenu` object, follows
/// its changes, and tells the app what the user did: what a global menu
/// bar needs.
///
/// ```swift
/// let reader = DBusMenuReader(connection: connection, service: service, path: path)
/// try await reader.start()
/// show(await reader.menu)
/// Task {
///     for await menu in reader.changes { show(menu) }
/// }
/// // As a menu opens: its items are brought up to date first.
/// try await reader.aboutToShow(item.id)
/// // As an item is chosen:
/// try await reader.click(item.id)
/// ```
public actor DBusMenuReader {

    /// The connection the menu is read on.
    public nonisolated let connection: DBusConnection

    /// The app's bus name, as it was given: unique or well-known.
    public nonisolated let service: DBusBusName

    /// The menu's object path.
    public nonisolated let path: DBusObjectPath

    /// The menu after each change, from `start()` on: the latest, if they
    /// come faster than they're read. Finishes when the app leaves the bus
    /// or the reader stops.
    public nonisolated let changes: AsyncStream<DBusMenuItem>

    /// Items the app asks the bar to show, as when their shortcuts are
    /// pressed: their identifiers.
    public nonisolated let activationRequests: AsyncStream<Int32>

    /// The menu: the root item, whose children are the menus of the bar.
    public private(set) var menu: DBusMenuItem = .root([])

    /// The layout's revision, as the app last gave it.
    public private(set) var revision: UInt32 = 0

    /// The interface version the app serves.
    public private(set) var version: UInt32?

    /// Whether the menu asks for attention.
    public private(set) var status: DBusMenuStatus = .normal

    /// The direction the labels read in.
    public private(set) var textDirection: DBusMenuTextDirection = .leftToRight

    /// The unique name of the connection serving the menu, once started.
    public private(set) var owner: DBusBusName?

    /// How long to wait for each reply.
    public nonisolated let timeout: Duration

    private let changesContinuation: AsyncStream<DBusMenuItem>.Continuation

    private let activationContinuation: AsyncStream<Int32>.Continuation

    private var following: [Task<Void, Never>] = []

    public init(
        connection: DBusConnection,
        service: DBusBusName,
        path: DBusObjectPath = DBusMenuInterface.defaultPath,
        timeout: Duration = .seconds(2)
    ) {
        self.connection = connection
        self.service = service
        self.path = path
        self.timeout = timeout
        (changes, changesContinuation) = AsyncStream.makeStream(bufferingPolicy: .bufferingNewest(1))
        (activationRequests, activationContinuation) = AsyncStream.makeStream(bufferingPolicy: .bufferingNewest(8))
    }

    deinit {
        following.forEach { $0.cancel() }
        changesContinuation.finish()
        activationContinuation.finish()
    }

    // MARK: Following

    /// Reads the menu and its properties, and follows its changes.
    ///
    /// - Throws: If the app isn't on the bus or doesn't serve a menu at
    ///   the path.
    public func start() async throws {
        guard following.isEmpty else { return }
        // Signals carry the sender's unique name, so that's what's matched.
        let owner = service.rawValue.hasPrefix(":") ? service : try await connection.getNameOwner(service)
        self.owner = owner

        let menuSignals = try await connection.signals(matching: .signal(interface: DBusMenuInterface.name, path: path, sender: owner))
        let propertySignals = try await connection.signals(matching: .propertiesChanged(interface: DBusMenuInterface.name, path: path, sender: owner))
        let ownerSignals = try await connection.signals(matching: .nameOwnerChanged(name: owner))
        following = [
            Task { [weak self] in
                for await signal in menuSignals {
                    await self?.handleMenuSignal(signal)
                }
            },
            Task { [weak self] in
                for await signal in propertySignals {
                    await self?.handlePropertiesChanged(signal)
                }
            },
            Task { [weak self] in
                for await signal in ownerSignals {
                    // (name, old owner, new owner): an empty new owner is gone.
                    if signal.arguments.count == 3, signal.arguments[2].string == "" {
                        await self?.ownerLeft()
                    }
                }
            },
        ]
        do {
            try await refresh()
        } catch {
            await stop()
            throw error
        }
        await readProperties()
    }

    /// Stops following the menu.
    public func stop() async {
        following.forEach { $0.cancel() }
        following = []
        changesContinuation.finish()
        activationContinuation.finish()
    }

    // MARK: Reading

    /// Reads the whole menu again.
    public func refresh() async throws {
        let (revision, root) = try await layout(of: DBusMenuItem.rootID)
        self.revision = revision
        menu = root
        changesContinuation.yield(menu)
    }

    /// Reads an item and its submenus again.
    public func refresh(_ id: Int32) async throws {
        guard id != DBusMenuItem.rootID, menu.item(withID: id) != nil else {
            try await refresh()
            return
        }
        let (revision, item) = try await layout(of: id)
        self.revision = revision
        // It may have gone while it was read.
        if !menu.modifyItem(withID: id, { $0 = item }) {
            try await refresh()
            return
        }
        changesContinuation.yield(menu)
    }

    /// Tells the app a submenu is about to open, so it can bring its items
    /// up to date, and reads them again if it did. Returns whether they
    /// changed.
    @discardableResult
    public func aboutToShow(_ id: Int32) async throws -> Bool {
        let needsUpdate: Bool
        if timeout == DBusConnection.defaultTimeout {
            needsUpdate = try await client().aboutToShow(id: id)
        } else {
            let reply = try await call(DBusMenuInterface.aboutToShow, [.int32(id)])
            guard let value = reply.first?.boolean else {
                throw DBusMenuError.invalidReply("AboutToShow didn't answer with a b")
            }
            needsUpdate = value
        }
        if needsUpdate {
            try await refresh(id)
        }
        return needsUpdate
    }

    // MARK: Events

    /// Tells the app an item was chosen.
    public func click(_ id: Int32, timestamp: UInt32 = 0) async throws {
        try await send(DBusMenuEvent(id: id, kind: .clicked, timestamp: timestamp))
    }

    /// Tells the app a submenu opened: `aboutToShow(_:)` and then this.
    public func opened(_ id: Int32, timestamp: UInt32 = 0) async throws {
        try await send(DBusMenuEvent(id: id, kind: .opened, timestamp: timestamp))
    }

    /// Tells the app a submenu closed.
    public func closed(_ id: Int32, timestamp: UInt32 = 0) async throws {
        try await send(DBusMenuEvent(id: id, kind: .closed, timestamp: timestamp))
    }

    /// Tells the app about an event.
    public func send(_ event: DBusMenuEvent) async throws {
        if timeout == DBusConnection.defaultTimeout {
            try await client().event(id: event.id, eventId: event.kind.rawValue, data: .init(event.data), timestamp: event.timestamp)
            return
        }
        try await call(DBusMenuInterface.event, [
            .int32(event.id),
            .string(event.kind.rawValue),
            .variant(.init(event.data)),
            .uint32(event.timestamp),
        ])
    }

    // MARK: Signals

    private func handleMenuSignal(_ signal: DBusMessage) async {
        switch signal.member {
        case DBusMenuInterface.layoutUpdated:
            guard signal.arguments.count == 2,
                  let revision = signal.arguments[0].uint32,
                  let parent = signal.arguments[1].int32 else { return }
            guard revision != self.revision || revision == 0 else { return }
            try? await refresh(parent)
        case DBusMenuInterface.itemsPropertiesUpdated:
            guard signal.arguments.count == 2,
                  case let .array(updated) = signal.arguments[0],
                  case let .array(removed) = signal.arguments[1] else { return }
            applyPropertiesUpdated(updated: Array(updated), removed: Array(removed))
        case DBusMenuInterface.itemActivationRequested:
            if let id = signal.arguments.first?.int32 {
                activationContinuation.yield(id)
            }
        default:
            break
        }
    }

    /// Applies `ItemsPropertiesUpdated`: `a(ia{sv})` and `a(ias)`.
    private func applyPropertiesUpdated(updated: [DBusMessageArgument], removed: [DBusMessageArgument]) {
        var changed = false
        for element in updated {
            guard case let .struct(structure) = element, structure.count == 2,
                  let id = structure[0].int32,
                  case let .dictionary(properties) = structure[1] else { continue }
            changed = menu.modifyItem(withID: id) { item in
                for entry in properties {
                    if let name = entry.key.string {
                        item.setProperty(name, to: entry.value)
                    }
                }
            } || changed
        }
        for element in removed {
            guard case let .struct(structure) = element, structure.count == 2,
                  let id = structure[0].int32,
                  case let .array(names) = structure[1] else { continue }
            changed = menu.modifyItem(withID: id) { item in
                for name in names.compactMap(\.string) {
                    item.setProperty(name, to: nil)
                }
            } || changed
        }
        if changed {
            changesContinuation.yield(menu)
        }
    }

    private func handlePropertiesChanged(_ signal: DBusMessage) {
        guard signal.arguments.count >= 2, case let .dictionary(changed) = signal.arguments[1] else { return }
        for entry in changed {
            if let name = entry.key.string {
                apply(property: name, value: entry.value)
            }
        }
    }

    private func ownerLeft() async {
        menu = .root([])
        changesContinuation.yield(menu)
        await stop()
    }

    // MARK: Calls

    /// The layout of an item and all its submenus, with every property.
    private func layout(of id: Int32) async throws -> (UInt32, DBusMenuItem) {
        let empty = DBusMessageArgument.Array(type: .string)
        if timeout == DBusConnection.defaultTimeout {
            let (revision, layout) = try await client().getLayout(parentId: id, recursionDepth: -1, propertyNames: empty)
            return (revision, try DBusMenuItem(layout: .struct(layout)))
        }
        let reply = try await call(DBusMenuInterface.getLayout, [.int32(id), .int32(-1), .array(empty)])
        guard reply.count == 2, let revision = reply[0].uint32 else {
            throw DBusMenuError.invalidReply("GetLayout didn't answer with a u(ia{sv}av)")
        }
        return (revision, try DBusMenuItem(layout: reply[1]))
    }

    /// Reads `Version`, `Status` and `TextDirection`, leaving those the app
    /// doesn't serve as they are.
    private func readProperties() async {
        guard let all = try? await client().properties() else {
            return
        }
        for (name, value) in all {
            apply(property: name, value: value)
        }
    }

    private func apply(property name: String, value: DBusMessageArgument) {
        var value = value
        while case let .variant(variant) = value {
            value = variant.element
        }
        switch name {
        case "Version":
            version = value.uint32
        case "Status":
            status = value.string.flatMap(DBusMenuStatus.init(rawValue:)) ?? .normal
        case "TextDirection":
            textDirection = value.string.flatMap(DBusMenuTextDirection.init(rawValue:)) ?? .leftToRight
        default:
            break
        }
    }

    private func client() throws -> StatusNotifier.Menu {
        try StatusNotifier.Menu(connection: connection, destination: (owner ?? service).rawValue, path: path.rawValue)
    }

    // The generated methods use DBusConnection.defaultTimeout.
    @discardableResult
    private func call(_ method: DBusMember, _ arguments: [DBusMessageArgument]) async throws -> [DBusMessageArgument] {
        try await connection.callMethod(
            destination: owner ?? service,
            path: path,
            interface: DBusMenuInterface.name,
            method: method,
            arguments: arguments,
            timeout: timeout
        )
    }
}
