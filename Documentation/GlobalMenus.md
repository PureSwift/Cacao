# Global menus

Apps on Linux show their menus in the desktop's menu bar instead of in their windows. Three pieces take part, and all use existing protocols:

- **`com.canonical.dbusmenu`** on the session bus carries the menu: the app serves it, and the menu bar reads it and tells the app what the user chose. KDE, Unity and Qt use the same interface.
- **The KDE appmenu Wayland protocol** (`org_kde_kwin_appmenu_manager`) ties each window to its menu's bus address, so the compositor can tell the menu bar whose menu to show as focus moves.
- **A bus name made from the app's `app_id`**, for compositors without the appmenu protocol, such as sway: the menu bar knows the focused window's `app_id` and finds the menu from it.

## `CacaoDBusMenu`

A library with no SwiftUI or SDL, only PureSwift/DBus, so Cacao apps, Perry's AppKit and the shell's menu bar share it.

| Type | What it is |
| --- | --- |
| `DBusMenuItem` | An item and its submenu: identifier, label (with an `_` before the mnemonic), enabled, visible, separator, checkmark or radio toggle and its state, shortcut, icon name or PNG, disposition. The menu is an item too, the root, with identifier 0. |
| `DBusMenuLabel` | Reads and writes labels' mnemonics: `DBusMenuLabel(title: "Save_As").rawValue` is `Save__As`. |
| `DBusMenuShortcut` | The `shortcut` property, an `aas` such as `[["Control", "q"]]`: modifiers `Control`, `Alt`, `Shift`, `Super`, and an X keysym name. `glyphs` shows it the Mac way, with Super as ⌘. |
| `DBusMenuExporter` | Serves a menu. `update(_:)` tells the bar what changed; events and `AboutToShow` call back into the app. |
| `DBusMenuReader` | Reads a menu, follows its changes, calls `AboutToShow` and sends events. |
| `AppMenuDiscovery` | The `app_id` naming scheme, and whether a menu bar is present. |

### Serving a menu

```swift
let exporter = DBusMenuExporter(connection: connection, menu: .root([
    DBusMenuItem(id: 1, title: "File", children: [
        DBusMenuItem(id: 2, title: "Quit", shortcut: DBusMenuShortcut("q", modifiers: .super)),
    ]),
])) { event in
    // `event.kind == .clicked`: run the item's action.
} onAboutToShow: { id in
    // A submenu is about to open: bring its items up to date with
    // `await exporter.update(menu)` before returning. Perry runs
    // `validateMenuItem:` here.
}
await exporter.export()                        // at /MenuBar
try await AppMenuDiscovery.claimName(forAppID: appID, on: connection)
// Then tie each window to (connection.uniqueName, "/MenuBar") with the
// appmenu protocol: cacao_wayland_appmenu_create in CacaoWayland.
```

Identifiers must stay with their items across updates, so a click finds the item it was meant for. The exporter serves version 3 of the interface, with the `Version`, `TextDirection`, `Status` and `IconThemePath` properties, and sends `LayoutUpdated` when items come, go or move and `ItemsPropertiesUpdated` when only their properties change. `AboutToShow` answers whether the menu changed while the handler ran.

### Reading a menu

```swift
let reader = DBusMenuReader(connection: connection, service: service, path: path)
try await reader.start()                       // reads the layout, follows signals
let menu = await reader.menu                   // the root; its children are the bar's menus
for await menu in reader.changes { … }         // after each change; ends when the app leaves
try await reader.aboutToShow(item.id)          // before a submenu opens; reads it again if needed
try await reader.opened(item.id)               // optional
try await reader.click(item.id)                // the user chose it
```

`reader.activationRequests` yields items the app asks the bar to highlight. A reader for an app found by `app_id` comes from `AppMenuDiscovery.reader(forAppID:on:)`, which is `nil` when no app with that `app_id` serves a menu.

## Finding a menu by `app_id`

An app owns `org.pureswift.Cacao.AppMenu.` followed by its `app_id`, escaped, and serves its menu at `/MenuBar`. Each element of the `app_id` keeps its ASCII letters and digits; any other byte of its UTF-8 (`_` and `-` included), and a digit at the start of an element, becomes `_` and two capital hex digits, and an empty element is `_`.

| `app_id` | Bus name |
| --- | --- |
| `org.pureswift.CacaoDemo` | `org.pureswift.Cacao.AppMenu.org.pureswift.CacaoDemo` |
| `org.gnome.Text-Editor` | `org.pureswift.Cacao.AppMenu.org.gnome.Text_2DEditor` |
| `com.2048.Game` | `org.pureswift.Cacao.AppMenu.com._32048.Game` |

A second instance of an app queues for the name and gets it when the first leaves. The menu at that name is the menu of the app's key window. A menu bar can list such apps with `ListNames`, or follow them with `NameOwnerChanged` and `arg0namespace=org.pureswift.Cacao.AppMenu`.

## Knowing that a menu bar shows the menus

An app hides its in-window menu bar when either is true:

- The compositor offers `org_kde_kwin_appmenu_manager` (`HostRuntime.compositorShowsMenus` in Cacao, `cacao_wayland_appmenu_manager_create` returning non-NULL elsewhere).
- `com.canonical.AppMenu.Registrar` has an owner on the session bus (`AppMenuDiscovery.isMenuBarPresent(on:)`, or `menuBarPresence(on:)` to follow it). The menu bar owns this name while it runs, as Unity's and KDE's do; Qt apps check the same name.

`SDLHost.menusShownByDesktop` combines both for Cacao apps.

## Cacao apps

On Linux, `SDLHost` serves the key window's commands as the app's menu: an app menu named after the app (the scene's app menu commands, such as Settings…, and Quit), File (the scene's File commands and Close Window), Edit (Undo, Redo, Cut, Copy, Paste and Select All, which press the same keys in the key window, then the scene's Edit commands), the app's `CommandMenu`s, Window (Minimize, Zoom, the scene's Window commands and the open windows) and Help when the scene adds to it. The menu is made again when the key window changes, every half second, and before a menu opens; a click runs the command in the key window. Shortcuts show Control where a command uses Command, as Cacao's views match them on Linux.

Apps whose windows are all in layers of the screen, such as the shell's panels, serve no menu, and `SDLHost.exportsMenus = false` turns it off for others.
