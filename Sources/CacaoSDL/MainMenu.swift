//
//  MainMenu.swift
//  CacaoSDL
//
//  Created by Alsey Coleman Miller on 11/13/26.
//

#if os(macOS)
import CacaoRender
import AppKit
import Cacao

/// The app's commands in the macOS menu bar.
///
/// Menus the app adds fill in from the key window's commands each time they
/// open, so their titles and enabled states are current; their keyboard
/// shortcuts reach the window, which runs the command. Items added to the
/// app menu (like Settings…) are made once, and run the command of the same
/// title in the key window.
@MainActor
enum MainMenu {

    private static var keyGraph: () -> ViewGraph? = { nil }

    private static let bridge = Bridge()

    static func install(keyGraph: @escaping () -> ViewGraph?) {
        self.keyGraph = keyGraph
        guard let app = NSApp, let graph = keyGraph() else { return }
        if app.mainMenu == nil {
            app.mainMenu = NSMenu()
        }
        guard let mainMenu = app.mainMenu else { return }
        for menu in graph.commandMenus() {
            if menu.name.isEmpty {
                // The app menu: after its first item, About.
                guard let appMenu = mainMenu.items.first?.submenu else { continue }
                var index = min(1, appMenu.numberOfItems)
                appMenu.insertItem(.separator(), at: index)
                index += 1
                for item in menu.items {
                    appMenu.insertItem(bridge.makeItem(item, menu: menu.name), at: index)
                    index += 1
                }
                continue
            }
            if mainMenu.item(withTitle: menu.name) != nil { continue }
            let top = NSMenuItem(title: menu.name, action: nil, keyEquivalent: "")
            let submenu = NSMenu(title: menu.name)
            submenu.delegate = bridge
            top.submenu = submenu
            // Before the Window and Help menus, as macOS orders them.
            let index = mainMenu.items.firstIndex { ["Window", "Help"].contains($0.title) } ?? mainMenu.numberOfItems
            mainMenu.insertItem(top, at: index)
        }
    }

    /// The command of a menu with a title, in the key window.
    static func command(menu: String, title: String) -> CommandItem? {
        keyGraph()?.commandMenus().first { $0.name == menu }?.items.first { $0.title == title }
    }

    static func items(of menu: String) -> [CommandItem] {
        keyGraph()?.commandMenus().first { $0.name == menu }?.items ?? []
    }

    @MainActor
    final class Bridge: NSObject, NSMenuDelegate {

        final class Box: NSObject {
            let run: @MainActor () -> Void
            init(_ run: @escaping @MainActor () -> Void) { self.run = run }
        }

        @MainActor
        func makeItem(_ item: CommandItem, menu: String, live: Bool = false) -> NSMenuItem {
            guard item.kind == .button else { return .separator() }
            let menuItem = NSMenuItem(title: item.title, action: #selector(run(_:)), keyEquivalent: "")
            menuItem.target = self
            menuItem.isEnabled = item.isEnabled
            if let shortcut = item.shortcut {
                menuItem.keyEquivalent = String(shortcut.key.character)
                var flags: NSEvent.ModifierFlags = []
                if shortcut.modifiers.contains(.command) { flags.insert(.command) }
                if shortcut.modifiers.contains(.shift) { flags.insert(.shift) }
                if shortcut.modifiers.contains(.option) { flags.insert(.option) }
                if shortcut.modifiers.contains(.control) { flags.insert(.control) }
                menuItem.keyEquivalentModifierMask = flags
            }
            let title = item.title
            menuItem.representedObject = live ? Box(item.action) : Box {
                MainMenu.command(menu: menu, title: title)?.action()
            }
            return menuItem
        }

        @objc func run(_ sender: NSMenuItem) {
            (sender.representedObject as? Box)?.run()
        }

        func menuNeedsUpdate(_ menu: NSMenu) {
            menu.removeAllItems()
            menu.autoenablesItems = false
            for item in MainMenu.items(of: menu.title) {
                menu.addItem(makeItem(item, menu: menu.title, live: true))
            }
        }

        /// Shortcuts of the app's own menus reach the window instead, which
        /// runs the command.
        func menuHasKeyEquivalent(_ menu: NSMenu, for event: NSEvent, target: AutoreleasingUnsafeMutablePointer<AnyObject?>, action: UnsafeMutablePointer<Selector?>) -> Bool {
            false
        }
    }
}
#endif
