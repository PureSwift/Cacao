//
//  DBusMenuExporter.swift
//  CacaoDBusMenu
//
//  Created by Alsey Coleman Miller on 11/24/26.
//

public import DBus

/// Serves a menu as `com.canonical.dbusmenu`, so a global menu bar can show
/// it and tell the app what the user chose.
///
/// ```swift
/// let exporter = DBusMenuExporter(connection: connection, menu: .root([
///     DBusMenuItem(id: 1, title: "File", children: [
///         DBusMenuItem(id: 2, title: "Quit", shortcut: DBusMenuShortcut("q", modifiers: .control)),
///     ]),
/// ])) { event in
///     if event.kind == .clicked, event.id == 2 { quit() }
/// } onAboutToShow: { id in
///     // Bring the items of the submenu up to date, with `update(_:)`.
/// }
/// await exporter.export()
/// ```
///
/// Each `update(_:)` tells the bar what changed: `ItemsPropertiesUpdated`
/// for properties of items that stay, and `LayoutUpdated` when items come,
/// go or move.
public actor DBusMenuExporter {

    /// Called for each event, in order, after the call that brought it
    /// has been answered.
    public typealias EventHandler = @Sendable (DBusMenuEvent) async -> Void

    /// Called before a submenu opens, with its item's identifier: the time
    /// to bring its items up to date (titles, enabled states) with
    /// `update(_:)`. The bar is answered once it returns.
    public typealias AboutToShowHandler = @Sendable (Int32) async -> Void

    /// The connection the menu is served on.
    public nonisolated let connection: DBusConnection

    /// The object path the menu is served at.
    public nonisolated let path: DBusObjectPath

    /// The menu: the root item, whose children are the menus of the bar.
    public private(set) var menu: DBusMenuItem

    /// The layout's revision, which goes up each time items come, go or move.
    public private(set) var revision: UInt32 = 1

    /// Whether the menu asks for attention.
    public private(set) var status: DBusMenuStatus = .normal

    /// The direction the labels read in.
    public private(set) var textDirection: DBusMenuTextDirection

    /// The names of icon theme folders to look icons up in first.
    public private(set) var iconThemePath: [String] = []

    /// Whether the menu is on the bus.
    public private(set) var isExported = false

    /// Counts updates that changed something, so `AboutToShow` can say
    /// whether the bar must read the menu again.
    private var changeCount = 0

    private let onEvent: EventHandler

    private let onAboutToShow: AboutToShowHandler

    /// Events, delivered one at a time.
    private let events: AsyncStream<DBusMenuEvent>.Continuation

    private let delivering: Task<Void, Never>

    /// - Parameters:
    ///   - menu: The root item: its identifier is made 0. Every other item
    ///     needs an identifier of its own.
    public init(
        connection: DBusConnection,
        path: DBusObjectPath = DBusMenuInterface.defaultPath,
        menu: DBusMenuItem = .root([]),
        textDirection: DBusMenuTextDirection = .leftToRight,
        onEvent: @escaping EventHandler = { _ in },
        onAboutToShow: @escaping AboutToShowHandler = { _ in }
    ) {
        self.connection = connection
        self.path = path
        self.menu = Self.rooted(menu)
        self.textDirection = textDirection
        self.onEvent = onEvent
        self.onAboutToShow = onAboutToShow
        let (stream, continuation) = AsyncStream<DBusMenuEvent>.makeStream()
        self.events = continuation
        self.delivering = Task {
            for await event in stream {
                await onEvent(event)
            }
        }
    }

    deinit {
        events.finish()
        delivering.cancel()
    }

    // MARK: Serving

    /// Puts the menu on the bus at `path`.
    public func export() async {
        guard !isExported else { return }
        isExported = true
        await connection.export(DBusExportedObject([makeInterface()]), at: path)
    }

    /// Takes the menu off the bus.
    public func unexport() async {
        guard isExported else { return }
        isExported = false
        await connection.unexport(at: path)
    }

    // MARK: Changing

    /// Replaces the menu, and tells the bar what changed.
    public func update(_ menu: DBusMenuItem) async {
        let new = Self.rooted(menu)
        let old = self.menu
        guard new != old else { return }
        self.menu = new
        changeCount += 1

        let oldItems = Self.itemsByID(old)
        let newItems = Self.itemsByID(new)

        // Properties of items in both.
        var updated: [DBusMessageArgument] = []
        var removed: [DBusMessageArgument] = []
        for (id, item) in newItems.sorted(by: { $0.key < $1.key }) {
            guard let previous = oldItems[id] else { continue }
            let before = previous.properties
            let after = item.properties
            let changed = after.filter { before[$0.key] != $0.value }
            let gone = before.keys.filter { after[$0] == nil }
            if !changed.isEmpty {
                updated.append(item.itemPropertiesArgument(names: Set(changed.keys.map(\.rawValue))))
            }
            if !gone.isEmpty {
                let names = DBusMessageArgument.Array(type: .string, gone.map(\.rawValue).sorted().map { .string($0) })!
                removed.append(.struct(DBusMessageArgument.Structure([.int32(id), .array(names)])!))
            }
        }

        // Items that came, went or moved: the submenus whose children changed.
        let changedParents = newItems.keys.filter { id in
            oldItems[id]?.children.map(\.id) != newItems[id]?.children.map(\.id)
                && !(oldItems[id] == nil && newItems[id]?.children.isEmpty == true)
        }
        let layoutChanged = !changedParents.isEmpty || oldItems.count != newItems.count
        if layoutChanged {
            revision &+= 1
        }

        guard isExported else { return }
        if !updated.isEmpty || !removed.isEmpty {
            await emit(DBusMenuInterface.itemsPropertiesUpdated, arguments: [
                .array(DBusMessageArgument.Array(type: Self.itemPropertiesType, updated)!),
                .array(DBusMessageArgument.Array(type: Self.removedPropertiesType, removed)!),
            ])
        }
        if layoutChanged {
            // One submenu changed: the bar reads it again. Otherwise, all of it.
            let parent = changedParents.count == 1 && oldItems[changedParents[0]] != nil ? changedParents[0] : DBusMenuItem.rootID
            await emit(DBusMenuInterface.layoutUpdated, arguments: [.uint32(revision), .int32(parent)])
        }
    }

    /// Sets whether the menu asks for attention.
    public func setStatus(_ status: DBusMenuStatus) async {
        guard status != self.status else { return }
        self.status = status
        if isExported {
            try? await connection.emitPropertiesChanged(at: path, interface: DBusMenuInterface.name, changed: ["Status": .string(status.rawValue)])
        }
    }

    /// Sets the direction the labels read in.
    public func setTextDirection(_ direction: DBusMenuTextDirection) async {
        guard direction != textDirection else { return }
        textDirection = direction
        if isExported {
            try? await connection.emitPropertiesChanged(at: path, interface: DBusMenuInterface.name, changed: ["TextDirection": .string(direction.rawValue)])
        }
    }

    /// Asks the bar to show an item, as when its shortcut is pressed: the
    /// bar opens its menu and highlights it.
    public func requestActivation(of id: Int32, timestamp: UInt32 = 0) async {
        guard isExported, menu.item(withID: id) != nil else { return }
        await emit(DBusMenuInterface.itemActivationRequested, arguments: [.int32(id), .uint32(timestamp)])
    }

    // MARK: Methods

    private func getLayout(parent: Int32, depth: Int32, propertyNames: [String]) throws -> [DBusMessageArgument] {
        guard let item = menu.item(withID: parent) else {
            throw Self.unknownItem(parent)
        }
        return [.uint32(revision), item.layoutArgument(depth: depth, propertyNames: Set(propertyNames))]
    }

    private func getGroupProperties(ids: [Int32], propertyNames: [String]) -> [DBusMessageArgument] {
        var items: [DBusMenuItem] = []
        if ids.isEmpty {
            menu.forEach { items.append($0) }
        } else {
            items = ids.compactMap { menu.item(withID: $0) }
        }
        let names = Set(propertyNames)
        return [.array(DBusMessageArgument.Array(type: Self.itemPropertiesType, items.map { $0.itemPropertiesArgument(names: names) })!)]
    }

    private func getProperty(id: Int32, name: String) throws -> [DBusMessageArgument] {
        guard let item = menu.item(withID: id) else {
            throw Self.unknownItem(id)
        }
        guard let property = DBusMenuItem.Property(rawValue: name) else {
            throw DBusError(name: .invalidArguments, message: "There's no property \(name)")
        }
        return [.variant(.init(item.properties[property] ?? Self.defaultValue(of: property)))]
    }

    /// Queues an event for the handler. Returns whether the item exists.
    private func receive(_ event: DBusMenuEvent) -> Bool {
        guard menu.item(withID: event.id) != nil else { return false }
        events.yield(event)
        return true
    }

    /// Lets the app update a submenu, and says whether it changed.
    private func aboutToShow(_ ids: [Int32]) async -> (updated: [Int32], errors: [Int32]) {
        var updated: [Int32] = []
        var errors: [Int32] = []
        for id in ids {
            guard menu.item(withID: id) != nil else {
                errors.append(id)
                continue
            }
            let before = changeCount
            await onAboutToShow(id)
            if changeCount != before {
                updated.append(id)
            }
        }
        return (updated, errors)
    }

    /// The interface, whose methods call back into this actor.
    private func makeInterface() -> DBusInterfaceImplementation {
        DBusInterfaceImplementation(
            name: DBusMenuInterface.name,
            methods: [
                .init(
                    name: DBusMenuInterface.getLayout,
                    inputSignature: DBusSignature(rawValue: "iias")!,
                    outputSignature: DBusSignature(rawValue: "u(ia{sv}av)")!,
                    inputNames: ["parentId", "recursionDepth", "propertyNames"],
                    outputNames: ["revision", "layout"]
                ) { [weak self] call in
                    guard let self else { throw Self.unexported }
                    let arguments = call.arguments
                    guard let parent = arguments[0].int32, let depth = arguments[1].int32 else { return [] }
                    return try await getLayout(parent: parent, depth: depth, propertyNames: Self.strings(arguments[2]))
                },
                .init(
                    name: DBusMenuInterface.getGroupProperties,
                    inputSignature: DBusSignature(rawValue: "aias")!,
                    outputSignature: DBusSignature(rawValue: "a(ia{sv})")!,
                    inputNames: ["ids", "propertyNames"],
                    outputNames: ["properties"]
                ) { [weak self] call in
                    guard let self else { throw Self.unexported }
                    return await getGroupProperties(ids: Self.int32s(call.arguments[0]), propertyNames: Self.strings(call.arguments[1]))
                },
                .init(
                    name: DBusMenuInterface.getProperty,
                    inputSignature: DBusSignature(rawValue: "is")!,
                    outputSignature: DBusSignature(rawValue: "v")!,
                    inputNames: ["id", "name"],
                    outputNames: ["value"]
                ) { [weak self] call in
                    guard let self else { throw Self.unexported }
                    guard let id = call.arguments[0].int32, let name = call.arguments[1].string else { return [] }
                    return try await getProperty(id: id, name: name)
                },
                .init(
                    name: DBusMenuInterface.event,
                    inputSignature: DBusSignature(rawValue: "isvu")!,
                    inputNames: ["id", "eventId", "data", "timestamp"]
                ) { [weak self] call in
                    guard let self else { throw Self.unexported }
                    guard let event = Self.event(call.arguments) else { return [] }
                    guard await receive(event) else {
                        throw Self.unknownItem(event.id)
                    }
                    return []
                },
                .init(
                    name: DBusMenuInterface.eventGroup,
                    inputSignature: DBusSignature(rawValue: "a(isvu)")!,
                    outputSignature: DBusSignature(rawValue: "ai")!,
                    inputNames: ["events"],
                    outputNames: ["idErrors"]
                ) { [weak self] call in
                    guard let self else { throw Self.unexported }
                    guard case let .array(group) = call.arguments[0] else { return [] }
                    var errors: [Int32] = []
                    for element in group {
                        guard case let .struct(structure) = element, let event = Self.event(Array(structure)) else { continue }
                        if await !receive(event) {
                            errors.append(event.id)
                        }
                    }
                    return [Self.int32Array(errors)]
                },
                .init(
                    name: DBusMenuInterface.aboutToShow,
                    inputSignature: DBusSignature(rawValue: "i")!,
                    outputSignature: DBusSignature(rawValue: "b")!,
                    inputNames: ["id"],
                    outputNames: ["needUpdate"]
                ) { [weak self] call in
                    guard let self else { throw Self.unexported }
                    guard let id = call.arguments[0].int32 else { return [] }
                    let (updated, errors) = await aboutToShow([id])
                    if !errors.isEmpty {
                        throw Self.unknownItem(id)
                    }
                    return [.boolean(!updated.isEmpty)]
                },
                .init(
                    name: DBusMenuInterface.aboutToShowGroup,
                    inputSignature: DBusSignature(rawValue: "ai")!,
                    outputSignature: DBusSignature(rawValue: "aiai")!,
                    inputNames: ["ids"],
                    outputNames: ["updatesNeeded", "idErrors"]
                ) { [weak self] call in
                    guard let self else { throw Self.unexported }
                    let (updated, errors) = await aboutToShow(Self.int32s(call.arguments[0]))
                    return [Self.int32Array(updated), Self.int32Array(errors)]
                },
            ],
            properties: [
                .init(name: "Version", type: .uint32, get: {
                    .uint32(DBusMenuInterface.version)
                }),
                .init(name: "TextDirection", type: .string, get: { [weak self] in
                    .string(await self?.textDirection.rawValue ?? DBusMenuTextDirection.leftToRight.rawValue)
                }),
                .init(name: "Status", type: .string, get: { [weak self] in
                    .string(await self?.status.rawValue ?? DBusMenuStatus.normal.rawValue)
                }),
                .init(name: "IconThemePath", type: .array(.string), get: { [weak self] in
                    .array(DBusMessageArgument.Array(type: .string, (await self?.iconThemePath ?? []).map { .string($0) })!)
                }),
            ],
            signals: [
                .init(
                    name: DBusMenuInterface.itemsPropertiesUpdated,
                    signature: DBusSignature(rawValue: "a(ia{sv})a(ias)")!,
                    argumentNames: ["updatedProps", "removedProps"]
                ),
                .init(
                    name: DBusMenuInterface.layoutUpdated,
                    signature: DBusSignature(rawValue: "ui")!,
                    argumentNames: ["revision", "parent"]
                ),
                .init(
                    name: DBusMenuInterface.itemActivationRequested,
                    signature: DBusSignature(rawValue: "iu")!,
                    argumentNames: ["id", "timestamp"]
                ),
            ]
        )
    }

    private func emit(_ signal: DBusMember, arguments: [DBusMessageArgument]) async {
        // A closed connection has no one to tell.
        try? await connection.emit(
            DBusMessage.Signal(path: path, interface: DBusMenuInterface.name, name: signal),
            arguments: arguments
        )
    }

    // MARK: Helpers

    /// The menu with the root's identifier.
    private static func rooted(_ menu: DBusMenuItem) -> DBusMenuItem {
        var menu = menu
        menu.id = DBusMenuItem.rootID
        return menu
    }

    /// Every item of a menu, by identifier.
    private static func itemsByID(_ menu: DBusMenuItem) -> [Int32: DBusMenuItem] {
        var items: [Int32: DBusMenuItem] = [:]
        menu.forEach { items[$0.id] = $0 }
        return items
    }

    /// `(ia{sv})`
    static let itemPropertiesType = DBusSignature.ValueType.struct(DBusSignature.StructureType(rawValue: "(ia{sv})")!)

    /// `(ias)`
    static let removedPropertiesType = DBusSignature.ValueType.struct(DBusSignature.StructureType(rawValue: "(ias)")!)

    /// What a call is answered with after the exporter is gone.
    private static var unexported: DBusError {
        DBusError(name: .unknownObject, message: "The menu is no longer served")
    }

    private static func unknownItem(_ id: Int32) -> DBusError {
        DBusError(name: .invalidArguments, message: "There's no menu item \(id)")
    }

    /// What a property is when an item leaves it out.
    private static func defaultValue(of property: DBusMenuItem.Property) -> DBusMessageArgument {
        switch property {
        case .type: .string("standard")
        case .enabled, .visible: .boolean(true)
        case .iconData: .array(DBusMessageArgument.Array(type: .byte))
        case .shortcut: .array(DBusMessageArgument.Array(type: .array(.string)))
        case .toggleState: .int32(-1)
        case .disposition: .string("normal")
        case .label, .iconName, .toggleType, .childrenDisplay, .accessibleDescription: .string("")
        }
    }

    /// An event from `Event`'s arguments, or an element of `EventGroup`'s.
    private static func event(_ arguments: [DBusMessageArgument]) -> DBusMenuEvent? {
        guard arguments.count == 4,
              let id = arguments[0].int32,
              let name = arguments[1].string,
              case let .variant(data) = arguments[2],
              let timestamp = arguments[3].uint32 else {
            return nil
        }
        return DBusMenuEvent(id: id, kind: .init(rawValue: name), data: data.element, timestamp: timestamp)
    }

    private static func strings(_ argument: DBusMessageArgument) -> [String] {
        guard case let .array(array) = argument else { return [] }
        return array.compactMap(\.string)
    }

    private static func int32s(_ argument: DBusMessageArgument) -> [Int32] {
        guard case let .array(array) = argument else { return [] }
        return array.compactMap(\.int32)
    }

    private static func int32Array(_ values: [Int32]) -> DBusMessageArgument {
        .array(DBusMessageArgument.Array(type: .int32, values.map { .int32($0) })!)
    }
}
