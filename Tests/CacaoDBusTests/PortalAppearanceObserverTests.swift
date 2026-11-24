//
//  PortalAppearanceObserverTests.swift
//  CacaoDBusTests
//
//  The observer on a real bus, against a fake settings portal that serves
//  `org.freedesktop.portal.Settings` the way xdg-desktop-portal does.
//

import CacaoDBus
import CacaoTokens
import DBus
import Foundation
import Testing

@Suite(.enabled(if: PrivateBus.isAvailable, "Needs dbus-daemon"), .serialized)
struct PortalAppearanceObserverTests {

    private static let path = DBusObjectPath(rawValue: "/org/freedesktop/portal/desktop")!

    private static let interface = DBusInterface(rawValue: "org.freedesktop.portal.Settings")!

    /// A settings portal holding values in the appearance namespace.
    private final class FakePortal: Sendable {

        let connection: DBusConnection

        /// Serves `values` on the bus at `address`: with `ReadOne`, as
        /// portals since version 2 do, or with only `Read`, as older ones do.
        init(address: String, values: [String: DBusMessageArgument], hasReadOne: Bool = true) async throws {
            connection = try await DBusConnection.connect(to: address)
            var methods: [DBusInterfaceImplementation.Method] = [
                .init(
                    name: DBusMember(rawValue: "Read")!,
                    inputSignature: DBusSignature(rawValue: "ss")!,
                    outputSignature: DBusSignature(rawValue: "v")!
                ) { call in
                    // A variant in a variant.
                    [.variant(.init(.variant(.init(try Self.value(of: call, in: values)))))]
                }
            ]
            if hasReadOne {
                methods.append(.init(
                    name: DBusMember(rawValue: "ReadOne")!,
                    inputSignature: DBusSignature(rawValue: "ss")!,
                    outputSignature: DBusSignature(rawValue: "v")!
                ) { call in
                    [.variant(.init(try Self.value(of: call, in: values)))]
                })
            }
            await connection.export(
                DBusExportedObject([DBusInterfaceImplementation(name: PortalAppearanceObserverTests.interface, methods: methods)]),
                at: PortalAppearanceObserverTests.path
            )
            try await connection.requestName(DBusBusName(rawValue: "org.freedesktop.portal.Desktop")!)
        }

        /// The value a `Read` or `ReadOne` call asks for.
        private static func value(of call: DBusMethodCall, in values: [String: DBusMessageArgument]) throws -> DBusMessageArgument {
            // Keys in the appearance namespace are named alone, others after
        // their namespace and a space.
        guard call.arguments.count == 2,
                  case let .string(namespace) = call.arguments[0],
                  case let .string(key) = call.arguments[1],
                  let value = values[namespace == "org.freedesktop.appearance" ? key : namespace + " " + key]
            else {
                throw DBusError(name: .init(rawValue: "org.freedesktop.portal.Error.NotFound")!, message: "Not found")
            }
            return value
        }

        /// Emits `SettingChanged`, as the portal does when a setting changes.
        func change(_ key: String, to value: DBusMessageArgument, in namespace: String = "org.freedesktop.appearance") async throws {
            try await connection.emit(
                DBusMessage.Signal(
                    path: PortalAppearanceObserverTests.path,
                    interface: PortalAppearanceObserverTests.interface,
                    name: DBusMember(rawValue: "SettingChanged")!
                ),
                arguments: [.string(namespace), .string(key), .variant(.init(value))]
            )
        }
    }

    private static let accent = DBusMessageArgument.struct(.init([.double(0.2), .double(0.4), .double(0.6)])!)

    /// Starts an observer on the bus, with its changes as a stream.
    private func observe(_ bus: PrivateBus) async throws -> (PortalAppearanceObserver, PortalAppearance, AsyncStream<PortalAppearance>) {
        let (changes, continuation) = AsyncStream<PortalAppearance>.makeStream()
        let started = await PortalAppearanceObserver.start(address: bus.address) { appearance in
            continuation.yield(appearance)
        }
        let (observer, appearance) = try #require(started)
        return (observer, appearance, changes)
    }

    @Test func readsTheAppearance() async throws {
        let bus = try await PrivateBus.start()
        defer { bus.stop() }
        let portal = try await FakePortal(address: bus.address, values: [
            "color-scheme": .uint32(1),
            "accent-color": Self.accent,
            "contrast": .uint32(1),
        ])
        let (observer, appearance, _) = try await observe(bus)
        #expect(appearance == PortalAppearance(
            colorScheme: .dark,
            accentColor: .init(red: 0.2, green: 0.4, blue: 0.6),
            contrast: .high
        ))
        await observer.stop()
        await portal.connection.close()
    }

    @Test func readsAnOlderPortalWithRead() async throws {
        let bus = try await PrivateBus.start()
        defer { bus.stop() }
        let portal = try await FakePortal(address: bus.address, values: [
            "color-scheme": .uint32(2),
            "accent-color": Self.accent,
        ], hasReadOne: false)
        let (observer, appearance, _) = try await observe(bus)
        #expect(appearance == PortalAppearance(colorScheme: .light, accentColor: .init(red: 0.2, green: 0.4, blue: 0.6)))
        await observer.stop()
        await portal.connection.close()
    }

    @Test func withNoPortalNothingIsSet() async throws {
        let bus = try await PrivateBus.start()
        defer { bus.stop() }
        let (observer, appearance, _) = try await observe(bus)
        #expect(appearance == PortalAppearance())
        await observer.stop()
    }

    @Test func withNoBusThereIsNoObserver() async {
        let started = await PortalAppearanceObserver.start(address: "unix:path=/nonexistent/cacao-bus") { _ in }
        #expect(started == nil)
    }

    @Test func readsTheButtonLayout() async throws {
        let bus = try await PrivateBus.start()
        defer { bus.stop() }
        let portal = try await FakePortal(address: bus.address, values: [
            "color-scheme": .uint32(1),
            "org.gnome.desktop.wm.preferences button-layout": .string("close,minimize:maximize"),
        ])
        let (observer, appearance, changes) = try await observe(bus)
        #expect(appearance == PortalAppearance(
            colorScheme: .dark,
            buttonLayout: WindowButtonLayout(leading: [.close, .minimize], trailing: [.maximize])
        ))

        try await portal.change("button-layout", to: .string("appmenu:close"), in: "org.gnome.desktop.wm.preferences")
        var iterator = changes.makeAsyncIterator()
        #expect(await iterator.next()?.buttonLayout == WindowButtonLayout(leading: [], trailing: [.close]))
        await observer.stop()
        await portal.connection.close()
    }

    @Test func hearsChanges() async throws {
        let bus = try await PrivateBus.start()
        defer { bus.stop() }
        let portal = try await FakePortal(address: bus.address, values: ["color-scheme": .uint32(2)])
        let (observer, appearance, changes) = try await observe(bus)
        #expect(appearance == PortalAppearance(colorScheme: .light))

        // Other namespaces, and values that change nothing, aren't told of.
        try await portal.change("color-scheme", to: .string("prefer-dark"), in: "org.gnome.desktop.interface")
        try await portal.change("color-scheme", to: .uint32(2))
        try await portal.change("color-scheme", to: .uint32(1))
        try await portal.change("accent-color", to: Self.accent)

        var iterator = changes.makeAsyncIterator()
        #expect(await iterator.next() == PortalAppearance(colorScheme: .dark))
        #expect(await iterator.next() == PortalAppearance(colorScheme: .dark, accentColor: .init(red: 0.2, green: 0.4, blue: 0.6)))
        await observer.stop()
        await portal.connection.close()
    }
}
