//
//  DBusMenuBusTests.swift
//  CacaoDBusTests
//
//  A menu exported on one connection to a private bus and read from
//  another, as an app and the menu bar do.
//

import CacaoDBusMenu
import DBus
import Foundation
import Testing

@Suite(.enabled(if: PrivateBus.isAvailable, "Needs dbus-daemon"), .serialized)
struct DBusMenuBusTests {

    /// What the app's side heard.
    private actor Log {

        var events: [DBusMenuEvent] = []

        var aboutToShow: [Int32] = []

        func append(_ event: DBusMenuEvent) {
            events.append(event)
        }

        func append(aboutToShow id: Int32) {
            aboutToShow.append(id)
        }
    }

    private static let menu = DBusMenuItem.root([
        DBusMenuItem(id: 1, label: "_File", children: [
            DBusMenuItem(id: 2, title: "New", shortcut: DBusMenuShortcut("n", modifiers: .control)),
            .separator(id: 3),
            DBusMenuItem(id: 4, title: "Quit", shortcut: DBusMenuShortcut("q", modifiers: .super)),
        ]),
        DBusMenuItem(id: 5, title: "View", children: [
            DBusMenuItem(id: 6, label: "Sidebar", toggleType: .checkmark, toggleState: .on),
        ]),
    ])

    /// A bus, an app serving `menu` and a menu bar reading it.
    private struct Setup: @unchecked Sendable {
        let bus: PrivateBus
        let app: DBusConnection
        let bar: DBusConnection
        let exporter: DBusMenuExporter
        let reader: DBusMenuReader
        let log: Log

        func stop() async {
            await reader.stop()
            await exporter.unexport()
            await app.close()
            await bar.close()
            bus.stop()
        }
    }

    private func setUp(
        menu: DBusMenuItem = DBusMenuBusTests.menu,
        onAboutToShow: (@Sendable (DBusMenuExporter, Int32) async -> Void)? = nil
    ) async throws -> Setup {
        let bus = try await PrivateBus.start()
        let app = try await DBusConnection.connect(to: bus.address)
        let bar = try await DBusConnection.connect(to: bus.address)
        let log = Log()
        let box = ExporterBox()
        let exporter = DBusMenuExporter(connection: app, menu: menu) { event in
            await log.append(event)
        } onAboutToShow: { id in
            await log.append(aboutToShow: id)
            if let onAboutToShow, let exporter = await box.exporter {
                await onAboutToShow(exporter, id)
            }
        }
        await box.set(exporter)
        await exporter.export()
        let service = try #require(await app.uniqueName)
        let reader = DBusMenuReader(connection: bar, service: service)
        try await reader.start()
        return Setup(bus: bus, app: app, bar: bar, exporter: exporter, reader: reader, log: log)
    }

    /// Lets the about-to-show handler update the exporter that calls it.
    private actor ExporterBox {
        var exporter: DBusMenuExporter?
        func set(_ exporter: DBusMenuExporter) { self.exporter = exporter }
    }

    /// Waits for a condition the other connection brings about.
    private func eventually(_ condition: @Sendable () async -> Bool) async -> Bool {
        for _ in 0 ..< 50 {
            if await condition() { return true }
            try? await Task.sleep(for: .milliseconds(100))
        }
        return await condition()
    }

    /// Waits for the reader to have a menu.
    private func reads(_ menu: DBusMenuItem, _ setup: Setup) async -> Bool {
        await eventually { await setup.reader.menu == menu }
    }

    // MARK: Reading

    @Test func readsTheMenu() async throws {
        let setup = try await setUp()
        #expect(await setup.reader.menu == Self.menu)
        #expect(await setup.reader.revision == 1)
        #expect(await setup.reader.version == 3)
        #expect(await setup.reader.status == .normal)
        #expect(await setup.reader.textDirection == .leftToRight)
        await setup.stop()
    }

    @Test func readsItsMenuByAppID() async throws {
        let setup = try await setUp()
        #expect(try await AppMenuDiscovery.claimName(forAppID: "org.example.Notes", on: setup.app))
        // A second instance waits.
        let second = try await DBusConnection.connect(to: setup.bus.address)
        #expect(try await AppMenuDiscovery.claimName(forAppID: "org.example.Notes", on: second) == false)

        let reader = try #require(await AppMenuDiscovery.reader(forAppID: "org.example.Notes", on: setup.bar))
        #expect(reader.service == (await setup.app.uniqueName))
        try await reader.start()
        #expect(await reader.menu == Self.menu)
        #expect(await AppMenuDiscovery.reader(forAppID: "org.example.Other", on: setup.bar) == nil)
        await reader.stop()
        await second.close()
        await setup.stop()
    }

    @Test func answersItsMethodsAsBusctlWould() async throws {
        let setup = try await setUp()
        let service = try #require(await setup.app.uniqueName)
        func call(_ method: String, _ arguments: [DBusMessageArgument]) async throws -> [DBusMessageArgument] {
            try await setup.bar.callMethod(
                destination: service,
                path: DBusMenuInterface.defaultPath,
                interface: DBusMenuInterface.name,
                method: DBusMember(rawValue: method)!,
                arguments: arguments
            )
        }
        let noNames = DBusMessageArgument.array(.init(type: .string))

        // The File menu, without its items.
        let layout = try await call("GetLayout", [.int32(1), .int32(0), noNames])
        #expect(layout.first == .uint32(1))
        let file = try DBusMenuItem(layout: layout[1])
        #expect(file.label == "_File" && file.children.isEmpty && file.isSubmenu)

        let properties = try await call("GetGroupProperties", [
            .array(.init(type: .int32, [.int32(2), .int32(6), .int32(99)])!),
            .array(.init(type: .string, [.string("label"), .string("toggle-state")])!),
        ])
        guard case let .array(items)? = properties.first else {
            Issue.record("GetGroupProperties answered \(properties)")
            return
        }
        #expect(items.count == 2)

        #expect(try await call("GetProperty", [.int32(4), .string("label")]) == [.variant(.init(.string("Quit")))])
        // Defaults are answered too.
        #expect(try await call("GetProperty", [.int32(4), .string("enabled")]) == [.variant(.init(.boolean(true)))])
        await #expect(throws: DBusError.self) {
            _ = try await call("GetProperty", [.int32(99), .string("label")])
        }
        await #expect(throws: DBusError.self) {
            _ = try await call("Event", [.int32(99), .string("clicked"), .variant(.init(.int32(0))), .uint32(0)])
        }

        let group = try await call("EventGroup", [.array(.init(type: .struct(.init(rawValue: "(isvu)")!), [
            .struct(.init([.int32(2), .string("clicked"), .variant(.init(.string(""))), .uint32(7)])!),
            .struct(.init([.int32(99), .string("clicked"), .variant(.init(.int32(0))), .uint32(7)])!),
        ])!)])
        #expect(group == [.array(.init(type: .int32, [.int32(99)])!)])
        #expect(await eventually { await setup.log.events.map(\.id) == [2] })
        #expect(await setup.log.events.first?.timestamp == 7)

        let shown = try await call("AboutToShowGroup", [.array(.init(type: .int32, [.int32(1), .int32(99)])!)])
        #expect(shown == [.array(.init(type: .int32)), .array(.init(type: .int32, [.int32(99)])!)])

        let version = try await setup.bar.getProperty(destination: service, path: DBusMenuInterface.defaultPath, interface: DBusMenuInterface.name, name: "Version")
        #expect(version == .uint32(3))
        await setup.stop()
    }

    // MARK: Events

    @Test func clicksReachTheApp() async throws {
        let setup = try await setUp()
        try await setup.reader.click(4, timestamp: 42)
        try await setup.reader.opened(1)
        try await setup.reader.closed(1)
        #expect(await eventually { await setup.log.events.count == 3 })
        #expect(await setup.log.events == [
            DBusMenuEvent(id: 4, kind: .clicked, timestamp: 42),
            DBusMenuEvent(id: 1, kind: .opened),
            DBusMenuEvent(id: 1, kind: .closed),
        ])
        await #expect(throws: DBusError.self) {
            try await setup.reader.click(99)
        }
        await setup.stop()
    }

    @Test func aboutToShowLetsTheAppUpdate() async throws {
        let setup = try await setUp { exporter, id in
            // Like validateMenuItem: as View opens, Sidebar is turned off.
            guard id == 5 else { return }
            var menu = await exporter.menu
            menu.modifyItem(withID: 6) { $0.toggleState = .off }
            await exporter.update(menu)
        }
        #expect(try await setup.reader.aboutToShow(1) == false)
        #expect(try await setup.reader.aboutToShow(5))
        #expect(await setup.reader.menu.item(withID: 6)?.toggleState == .off)
        #expect(await setup.log.aboutToShow == [1, 5])
        await #expect(throws: DBusError.self) {
            try await setup.reader.aboutToShow(99)
        }
        await setup.stop()
    }

    // MARK: Updates

    @Test func propertyChangesAreFollowed() async throws {
        let setup = try await setUp()
        var menu = Self.menu
        menu.modifyItem(withID: 2) {
            $0.isEnabled = false
            $0.label = "New Window"
            $0.shortcut = nil
        }
        await setup.exporter.update(menu)
        #expect(await reads(menu, setup))
        // Properties alone don't change the layout's revision.
        #expect(await setup.exporter.revision == 1)
        await setup.stop()
    }

    @Test func layoutChangesAreFollowed() async throws {
        let setup = try await setUp()
        var menu = Self.menu
        // An item comes to one submenu.
        menu.modifyItem(withID: 5) {
            $0.children.append(DBusMenuItem(id: 7, label: "Toolbar", toggleType: .checkmark))
        }
        await setup.exporter.update(menu)
        #expect(await reads(menu, setup))
        #expect(await setup.exporter.revision == 2)

        // A menu goes, and another changes.
        menu.children.removeFirst()
        menu.modifyItem(withID: 7) { $0.toggleState = .on }
        menu.children.append(DBusMenuItem(id: 8, title: "Help", children: [DBusMenuItem(id: 9, title: "Search")]))
        await setup.exporter.update(menu)
        #expect(await reads(menu, setup))
        #expect(await setup.reader.revision == 3)
        await setup.stop()
    }

    @Test func statusChangesAreFollowed() async throws {
        let setup = try await setUp()
        await setup.exporter.setStatus(.notice)
        #expect(await eventually { await setup.reader.status == .notice })
        await setup.stop()
    }

    @Test func changesAreStreamed() async throws {
        let setup = try await setUp()
        var changes = setup.reader.changes.makeAsyncIterator()
        #expect(await changes.next() == Self.menu)
        var menu = Self.menu
        menu.modifyItem(withID: 4) { $0.isEnabled = false }
        await setup.exporter.update(menu)
        #expect(await changes.next() == menu)
        await setup.stop()
    }

    @Test func theMenuGoesWithTheApp() async throws {
        let setup = try await setUp()
        var changes = setup.reader.changes.makeAsyncIterator()
        _ = await changes.next()
        await setup.app.close()
        #expect(await changes.next() == .root([]))
        #expect(await changes.next() == nil)
        await setup.bar.close()
        setup.bus.stop()
    }

    // MARK: Menu bar

    @Test func appsHearWhetherAMenuBarIsThere() async throws {
        let bus = try await PrivateBus.start()
        defer { bus.stop() }
        let app = try await DBusConnection.connect(to: bus.address)
        let bar = try await DBusConnection.connect(to: bus.address)
        #expect(await AppMenuDiscovery.isMenuBarPresent(on: app) == false)
        var presence = try await AppMenuDiscovery.menuBarPresence(on: app).makeAsyncIterator()
        #expect(await presence.next() == false)
        _ = try await bar.requestName(AppMenuDiscovery.registrarName)
        #expect(await presence.next() == true)
        #expect(await AppMenuDiscovery.isMenuBarPresent(on: app))
        await bar.close()
        #expect(await presence.next() == false)
        await app.close()
    }
}

