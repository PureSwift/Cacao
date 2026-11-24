//
//  DBusMainMenu.swift
//  CacaoSDL
//
//  Created by Alsey Coleman Miller on 11/24/26.
//

#if os(Linux)
import Foundation
import Cacao
import CacaoHost
internal import CacaoDBusMenu
internal import DBus

/// The app's commands in the desktop's global menu bar, served over
/// `com.canonical.dbusmenu`.
///
/// The menu is the main window's: the app menu, File, Edit, the app's own
/// menus, Window and Help, with the commands the window's scene adds to
/// each. The main window is the key window, or the last one while none
/// has focus, as when the menu bar takes it to open a menu; windows in
/// layers of the screen don't count. It's served at `/MenuBar` on a session bus connection of its own,
/// tied to each window with the compositor's appmenu protocol, and found
/// by the app's `app_id` through the bus name `AppMenuDiscovery` makes, for
/// compositors without the protocol. It's read again as the key window
/// changes, every half second while the app runs, and before a menu opens,
/// so titles and enabled states are current; a click runs the command in
/// the main window.
@MainActor
enum DBusMainMenu {

    /// The window that last had keyboard focus.
    private static weak var lastMainWindow: HostWindow?

    /// The window whose commands the menu shows and runs: the key window,
    /// or else the last one that had focus, or else the first.
    static var mainWindow: HostWindow? {
        if let key = HostRuntime.keyWindow, !key.isInLayer {
            lastMainWindow = key
            return key
        }
        if let last = lastMainWindow, HostRuntime.windows.contains(where: { $0 === last }) {
            return last
        }
        return HostRuntime.windows.first { !$0.isInLayer }
    }

    /// The main window's view graph.
    private static var mainGraph: ViewGraph? {
        (mainWindow?.scene as? WindowScene)?.graph
    }

    private static var connection: DBusConnection?

    private static var exporter: DBusMenuExporter?

    /// What each item does, from the last time the menu was made.
    private static var actions: [Int32: @MainActor () -> Void] = [:]

    /// The identifiers given to items, by where they are, so an item keeps
    /// its identifier while it stays.
    private static var identifiers: [String: Int32] = [:]

    private static var nextIdentifier: Int32 = 1

    /// The menu last served.
    private static var served: DBusMenuItem?

    /// When the menu was last made, and for which window.
    private static var lastRefresh: Double = 0
    private static var lastRefreshWindow: ObjectIdentifier?

    /// How often the menu is made again while the app runs.
    private static let refreshInterval: Double = 0.5

    /// Whether a menu bar shows the menu: the compositor ties windows to
    /// it, or a menu bar owns `com.canonical.AppMenu.Registrar`.
    private(set) static var isShownByDesktop = false

    private static var registrarIsPresent = false {
        didSet { updateIsShownByDesktop() }
    }

    private static var following: Task<Void, Never>?

    /// Serves the menu, once the session bus answers.
    static func install() {
        updateIsShownByDesktop()
        HostRuntime.addWakeHook {
            refreshIfDue()
        }
        Task {
            await start()
        }
    }

    /// Stops serving the menu, as the app ends: waits up to a second for
    /// the connection to close, so replies to the menu bar, such as the one
    /// to the Quit item's click, go out before the app does.
    static func stop() {
        HostRuntime.menuAddress = nil
        following?.cancel()
        following = nil
        let exporter = exporter
        let connection = connection
        self.exporter = nil
        self.connection = nil
        served = nil
        actions = [:]
        guard let connection else { return }
        let closed = DispatchSemaphore(value: 0)
        // Off the main actor, which this waits on.
        Task.detached {
            await exporter?.unexport()
            // A call to the bus is answered after the messages sent before
            // it are written, the replies among them.
            _ = try? await connection.getBusID()
            await connection.close()
            closed.signal()
        }
        _ = closed.wait(timeout: .now() + 1)
    }

    private static func start() async {
        guard let connection = try? await DBusConnection.connect(to: .session) else {
            print("Cacao: no session bus, so the app's menus aren't served")
            return
        }
        let menu = makeMenu()
        let exporter = DBusMenuExporter(connection: connection, menu: menu) { event in
            guard event.kind == .clicked else { return }
            await DBusMainMenu.perform(event.id)
        } onAboutToShow: { _ in
            await DBusMainMenu.refresh()
        }
        await exporter.export()
        self.connection = connection
        self.exporter = exporter
        served = menu
        if let appID = HostRuntime.appIdentifier {
            _ = try? await AppMenuDiscovery.claimName(forAppID: appID, on: connection)
        }
        if let service = await connection.uniqueName {
            HostRuntime.menuAddress = HostMenuAddress(service: service.rawValue, path: AppMenuDiscovery.path.rawValue)
        }
        updateIsShownByDesktop()
        if let presence = try? await AppMenuDiscovery.menuBarPresence(on: connection) {
            following = Task {
                for await isPresent in presence {
                    registrarIsPresent = isPresent
                }
            }
        }
    }

    private static func updateIsShownByDesktop() {
        isShownByDesktop = HostRuntime.compositorShowsMenus || registrarIsPresent
    }

    // MARK: Updating

    /// Makes the menu again if the main window changed or it's been a while.
    private static func refreshIfDue() {
        guard exporter != nil else { return }
        let main = mainWindow.map(ObjectIdentifier.init)
        let now = HostRuntime.now
        guard main != lastRefreshWindow || now - lastRefresh >= refreshInterval else { return }
        lastRefreshWindow = main
        lastRefresh = now
        Task {
            await refresh()
        }
    }

    /// Makes the menu again, and serves it if it changed.
    static func refresh() async {
        lastRefresh = HostRuntime.now
        guard let exporter else { return }
        let menu = makeMenu()
        guard menu != served else { return }
        served = menu
        await exporter.update(menu)
    }

    /// Runs an item's command, from the menu as it is now.
    static func perform(_ id: Int32) {
        _ = makeMenu()
        actions[id]?()
        HostRuntime.wake()
    }

    // MARK: Making the menu

    /// The menu bar's menus, with what each item does.
    private static func makeMenu() -> DBusMenuItem {
        var builder = Builder()
        let main = mainWindow
        let commands = mainGraph?.commandMenus() ?? []
        let standard: Set<String> = ["", "File", "Edit", "Window", "Help"]
        func sceneCommands(_ name: String) -> [CommandItem] {
            commands.first { $0.name == name }?.items ?? []
        }
        let appName = Self.appName

        var menus: [DBusMenuItem] = []
        // The app menu: Settings… and what else the app adds, then Quit.
        menus.append(builder.menu("app", title: appName) { builder in
            var items = builder.commands(sceneCommands(""), in: "app")
            if !items.isEmpty {
                items.append(builder.separator("app"))
            }
            items.append(builder.item("app/quit", title: "Quit \(appName)") {
                HostRuntime.quit()
            })
            return items
        })
        // File: the app's commands, then Close Window.
        menus.append(builder.menu("File", title: "File") { builder in
            var items = builder.commands(sceneCommands("File"), in: "File")
            if !items.isEmpty {
                items.append(builder.separator("File"))
            }
            items.append(builder.item("File/close", title: "Close Window", isEnabled: main != nil) {
                if let window = mainWindow {
                    HostRuntime.close(window)
                }
            })
            return items
        })
        // Edit: what the focused text view does with the same keys.
        menus.append(builder.menu("Edit", title: "Edit") { builder in
            let isEnabled = main != nil
            var items = [
                builder.editItem("undo", title: "Undo", key: "z", isEnabled: isEnabled),
                builder.editItem("redo", title: "Redo", key: "z", shift: true, isEnabled: isEnabled),
                builder.separator("Edit"),
                builder.editItem("cut", title: "Cut", key: "x", isEnabled: isEnabled),
                builder.editItem("copy", title: "Copy", key: "c", isEnabled: isEnabled),
                builder.editItem("paste", title: "Paste", key: "v", isEnabled: isEnabled),
                builder.editItem("selectAll", title: "Select All", key: "a", isEnabled: isEnabled),
            ]
            let commands = builder.commands(sceneCommands("Edit"), in: "Edit")
            if !commands.isEmpty {
                items.append(builder.separator("Edit"))
                items += commands
            }
            return items
        })
        // The app's own menus, in the order the scene gives them.
        for menu in commands where !standard.contains(menu.name) {
            menus.append(builder.menu("menu/\(menu.name)", title: menu.name) { builder in
                builder.commands(menu.items, in: "menu/\(menu.name)")
            })
        }
        // Window: the main window's size, then every window, to raise.
        menus.append(builder.menu("Window", title: "Window") { builder in
            var items = [
                builder.item("Window/minimize", title: "Minimize", isEnabled: main != nil) {
                    mainWindow?.minimize()
                },
                builder.item("Window/zoom", title: "Zoom", isEnabled: main?.isResizable ?? false) {
                    mainWindow?.toggleMaximized()
                },
            ]
            let commands = builder.commands(sceneCommands("Window"), in: "Window")
            if !commands.isEmpty {
                items.append(builder.separator("Window"))
                items += commands
            }
            let windows = HostRuntime.windows.filter { !$0.isInLayer }
            if !windows.isEmpty {
                items.append(builder.separator("Window"))
            }
            for window in windows {
                let title = window.window.title
                var item = builder.item("Window/window/\(window.id)", title: title.isEmpty ? appName : title) { [weak window] in
                    window?.raise()
                }
                item.toggleType = .radio
                item.toggleState = window === main ? .on : .off
                items.append(item)
            }
            return items
        })
        // Help, when the app adds to it.
        let help = sceneCommands("Help")
        if !help.isEmpty {
            menus.append(builder.menu("Help", title: "Help") { builder in
                builder.commands(help, in: "Help")
            })
        }
        actions = builder.actions
        return .root(menus)
    }

    /// The app's name, for its menu.
    private static var appName: String {
        if let name = Bundle.main.object(forInfoDictionaryKey: "CFBundleName") as? String, !name.isEmpty {
            return name
        }
        return ProcessInfo.processInfo.processName
    }

    /// Makes items, with identifiers that stay with them.
    @MainActor
    private struct Builder {

        var actions: [Int32: @MainActor () -> Void] = [:]

        /// How many items with each key were made, so repeated titles get
        /// identifiers of their own.
        private var counts: [String: Int] = [:]

        /// The identifier of the item at a place.
        mutating func identifier(_ key: String) -> Int32 {
            let count = counts[key, default: 0]
            counts[key] = count + 1
            let key = count == 0 ? key : "\(key)#\(count)"
            if let identifier = DBusMainMenu.identifiers[key] {
                return identifier
            }
            let identifier = DBusMainMenu.nextIdentifier
            DBusMainMenu.nextIdentifier += 1
            DBusMainMenu.identifiers[key] = identifier
            return identifier
        }

        mutating func menu(_ key: String, title: String, items: (inout Builder) -> [DBusMenuItem]) -> DBusMenuItem {
            let id = identifier("menu:" + key)
            return DBusMenuItem(id: id, title: title, children: items(&self))
        }

        mutating func item(
            _ key: String,
            title: String,
            isEnabled: Bool = true,
            shortcut: DBusMenuShortcut? = nil,
            action: @escaping @MainActor () -> Void
        ) -> DBusMenuItem {
            let id = identifier(key)
            actions[id] = action
            return DBusMenuItem(id: id, title: title, isEnabled: isEnabled, shortcut: shortcut)
        }

        mutating func separator(_ menu: String) -> DBusMenuItem {
            .separator(id: identifier(menu + "/separator"))
        }

        /// An Edit item: the key it stands for, pressed in the main window.
        mutating func editItem(_ key: String, title: String, key character: Character, shift: Bool = false, isEnabled: Bool) -> DBusMenuItem {
            var modifiers: DBusMenuShortcut.Modifiers = [.control]
            var keyModifiers = KeyModifiers.shortcut
            if shift {
                modifiers.insert(.shift)
                keyModifiers.insert(.shift)
            }
            return item(
                "Edit/" + key,
                title: title,
                isEnabled: isEnabled,
                shortcut: DBusMenuShortcut(character: character, modifiers: modifiers)
            ) {
                DBusMainMenu.mainGraph?.keyDown(.character(character), modifiers: keyModifiers)
            }
        }

        /// The scene's commands in a menu.
        mutating func commands(_ commands: [CommandItem], in menu: String) -> [DBusMenuItem] {
            commands.map { command in
                switch command.kind {
                case .separator:
                    return separator(menu)
                case .button:
                    return item(
                        menu + "/" + command.title,
                        title: command.title,
                        isEnabled: command.isEnabled,
                        shortcut: command.shortcut.flatMap(DBusMainMenu.shortcut),
                        action: command.action
                    )
                }
            }
        }
    }

    /// A command's shortcut as the menu bar shows it: Command is Control
    /// here, as Cacao's views match it.
    private static func shortcut(_ shortcut: KeyboardShortcut) -> DBusMenuShortcut? {
        var modifiers: DBusMenuShortcut.Modifiers = []
        if shortcut.modifiers.contains(.command) || shortcut.modifiers.contains(.control) { modifiers.insert(.control) }
        if shortcut.modifiers.contains(.option) { modifiers.insert(.alt) }
        if shortcut.modifiers.contains(.shift) { modifiers.insert(.shift) }
        let key: String
        switch shortcut.key {
        case .upArrow: key = "Up"
        case .downArrow: key = "Down"
        case .leftArrow: key = "Left"
        case .rightArrow: key = "Right"
        case .deleteForward: key = "Delete"
        case .home: key = "Home"
        case .end: key = "End"
        case .pageUp: key = "Page_Up"
        case .pageDown: key = "Page_Down"
        case .clear: key = "Clear"
        default:
            return DBusMenuShortcut(character: shortcut.key.character, modifiers: modifiers)
        }
        return DBusMenuShortcut(key, modifiers: modifiers)
    }
}
#endif
