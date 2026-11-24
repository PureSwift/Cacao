//
//  DBusMenuModelTests.swift
//  CacaoDBusTests
//
//  The menu model and how it's written on the bus, without a bus.
//

@testable import CacaoDBusMenu
import DBus
import Testing

struct DBusMenuModelTests {

    // MARK: Labels

    @Test func labelsReadMnemonics() {
        let label = DBusMenuLabel(rawValue: "_File")
        #expect(label.title == "File")
        #expect(label.mnemonic == "F")
        #expect(label.mnemonicOffset == 0)

        let saveAs = DBusMenuLabel(rawValue: "Save __As _Copy")
        #expect(saveAs.title == "Save _As Copy")
        #expect(saveAs.mnemonic == "C")
        #expect(saveAs.mnemonicOffset == 9)

        #expect(DBusMenuLabel(rawValue: "Quit").mnemonic == nil)
        #expect(DBusMenuLabel(rawValue: "Trailing_").title == "Trailing")
    }

    @Test func labelsEscapeTitles() {
        #expect(DBusMenuLabel(title: "Save_As").rawValue == "Save__As")
        #expect(DBusMenuLabel(title: "Edit", mnemonicOffset: 0).rawValue == "_Edit")
        #expect(DBusMenuLabel(title: "Open_Recent", mnemonicOffset: 5).rawValue == "Open___Recent")
        #expect(DBusMenuLabel(rawValue: DBusMenuLabel(title: "Open_Recent", mnemonicOffset: 5).rawValue).title == "Open_Recent")
        #expect(DBusMenuItem(id: 1, title: "a_b").title == "a_b")
    }

    // MARK: Shortcuts

    @Test func shortcutsAreWrittenAsKeyNames() {
        let quit = DBusMenuShortcut(character: "q", modifiers: .control)
        #expect(quit.keys == ["Control", "q"])
        let settings = DBusMenuShortcut(character: ",", modifiers: [.super, .shift, .alt, .control])
        #expect(settings.keys == ["Control", "Alt", "Shift", "Super", "comma"])
        #expect(DBusMenuShortcut(character: "\r").keys == ["Return"])
        #expect(DBusMenuShortcut(character: "D").key == "d")
    }

    @Test func shortcutsReadOtherExportersNames() {
        #expect(DBusMenuShortcut(keys: ["Ctrl", "Shift", "S"]) == DBusMenuShortcut("S", modifiers: [.control, .shift]))
        #expect(DBusMenuShortcut(keys: ["Meta", "q"]) == DBusMenuShortcut("q", modifiers: .super))
        #expect(DBusMenuShortcut(keys: ["Hyper", "q"]) == nil)
        #expect(DBusMenuShortcut(keys: []) == nil)
    }

    @Test func shortcutsShowMacGlyphs() {
        #expect(DBusMenuShortcut("d", modifiers: [.super, .shift]).glyphs == "⇧⌘D")
        #expect(DBusMenuShortcut("comma", modifiers: .super).glyphs == "⌘,")
        #expect(DBusMenuShortcut("Return", modifiers: [.control, .alt]).glyphs == "⌃⌥↩")
        #expect(DBusMenuShortcut("F5").glyphs == "F5")
        #expect(DBusMenuShortcut("Page_Up").character == nil)
    }

    // MARK: Properties

    @Test func defaultsAreLeftOut() {
        #expect(DBusMenuItem(id: 1).properties.isEmpty)
        let item = DBusMenuItem(
            id: 2,
            type: .separator,
            label: "_Bold",
            isEnabled: false,
            isVisible: false,
            iconName: "format-text-bold",
            shortcut: DBusMenuShortcut("b", modifiers: .control),
            toggleType: .checkmark,
            toggleState: .on,
            disposition: .warning,
            accessibleDescription: "Bold",
            isSubmenu: true
        )
        #expect(Set(item.properties.keys) == Set(DBusMenuItem.Property.allCases).subtracting([.iconData]))
        #expect(item.properties[.shortcut]?.type == DBusSignature.ValueType.array(.array(.string)))
        #expect(item.properties[.toggleState] == .int32(1))
    }

    @Test func layoutsRoundTrip() throws {
        let menu = DBusMenuItem.root([
            DBusMenuItem(id: 1, title: "File", children: [
                DBusMenuItem(id: 2, title: "Open…", shortcut: DBusMenuShortcut("o", modifiers: .control)),
                .separator(id: 3),
                DBusMenuItem(id: 4, title: "Recent", isEnabled: false, children: [
                    DBusMenuItem(id: 5, label: "_Notes", iconData: [0x89, 0x50], toggleType: .radio, toggleState: .indeterminate),
                ]),
            ]),
            DBusMenuItem(id: 6, label: "Help", isVisible: false, disposition: .alert, isSubmenu: true),
        ])
        let layout = menu.layoutArgument()
        #expect(layout.type == .struct(DBusSignature.StructureType(rawValue: "(ia{sv}av)")!))
        #expect(try DBusMenuItem(layout: layout) == menu)

        // To a depth, with some of the properties.
        let shallow = try DBusMenuItem(layout: menu.item(withID: 1)!.layoutArgument(depth: 1, propertyNames: ["label"]))
        #expect(shallow.children.map(\.id) == [2, 3, 4])
        #expect(shallow.children[2].children.isEmpty)
        #expect(shallow.children[2].isEnabled)
        #expect(shallow.children[1].type == .standard)
        #expect(shallow.children[0].title == "Open…")
    }

    @Test func propertiesGoBackToTheirDefaults() {
        var item = DBusMenuItem(id: 1, label: "x", isEnabled: false, toggleType: .checkmark, toggleState: .on)
        item.setProperty("enabled", to: nil)
        item.setProperty("label", to: .variant(.init(.string("y"))))
        item.setProperty("toggle-state", to: nil)
        item.setProperty("unknown", to: .string("ignored"))
        #expect(item.isEnabled)
        #expect(item.label == "y")
        #expect(item.toggleState == .indeterminate)
        item.setProperty("enabled", to: .string("not a boolean"))
        #expect(item.isEnabled)
    }

    // MARK: Finding items

    @Test func itemsAreFoundAndChangedByID() {
        var menu = DBusMenuItem.root([
            DBusMenuItem(id: 1, title: "File", children: [DBusMenuItem(id: 2, title: "Close")]),
        ])
        #expect(menu.item(withID: 2)?.title == "Close")
        #expect(menu.item(withID: 9) == nil)
        #expect(menu.modifyItem(withID: 2) { $0.isEnabled = false })
        #expect(menu.item(withID: 2)?.isEnabled == false)
        #expect(!menu.modifyItem(withID: 9) { _ in })
        var ids: [Int32] = []
        menu.forEach { ids.append($0.id) }
        #expect(ids == [0, 1, 2])
    }

    // MARK: Discovery

    @Test func appIDsMakeBusNames() throws {
        #expect(AppMenuDiscovery.busName(forAppID: "org.pureswift.CacaoDemo")?.rawValue == "org.pureswift.Cacao.AppMenu.org.pureswift.CacaoDemo")
        #expect(AppMenuDiscovery.busName(forAppID: "org.gnome.Text-Editor")?.rawValue == "org.pureswift.Cacao.AppMenu.org.gnome.Text_2DEditor")
        #expect(AppMenuDiscovery.busName(forAppID: "my_app")?.rawValue == "org.pureswift.Cacao.AppMenu.my_5Fapp")
        #expect(AppMenuDiscovery.busName(forAppID: "com.2048.Game")?.rawValue == "org.pureswift.Cacao.AppMenu.com._32048.Game")
        #expect(AppMenuDiscovery.busName(forAppID: "a..b")?.rawValue == "org.pureswift.Cacao.AppMenu.a._.b")
        #expect(AppMenuDiscovery.busName(forAppID: "") == nil)
        #expect(AppMenuDiscovery.busName(forAppID: String(repeating: "a", count: 300)) == nil)
    }

    @Test(arguments: ["org.pureswift.CacaoDemo", "org.gnome.Text-Editor", "my_app", "com.2048.Game", "a..b", "café.Menü", "firefox"])
    func busNamesGiveBackAppIDs(appID: String) throws {
        let name = try #require(AppMenuDiscovery.busName(forAppID: appID))
        #expect(AppMenuDiscovery.appID(forBusName: name) == appID)
    }

    @Test func otherNamesAreNotApps() {
        #expect(AppMenuDiscovery.appID(forBusName: DBusBusName(rawValue: "org.kde.StatusNotifierWatcher")!) == nil)
        #expect(AppMenuDiscovery.appID(forBusName: DBusBusName(rawValue: "org.pureswift.Cacao.AppMenu.bad_Z1")!) == nil)
    }
}
