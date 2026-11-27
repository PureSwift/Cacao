//
//  PortalAppearanceObserver.swift
//  CacaoDBus
//
//  Created by Alsey Coleman Miller on 11/23/26.
//

public import CacaoTokens
internal import DBus
internal import FreedesktopPortal

/// Reads the appearance from the freedesktop settings portal,
/// `org.freedesktop.portal.Settings` on `org.freedesktop.portal.Desktop`,
/// and hears when it changes.
///
/// ```swift
/// if let (observer, appearance) = await PortalAppearanceObserver.start(onChange: { appearance in
///     // A setting changed.
/// }) {
///     // The settings now.
/// }
/// ```
public final class PortalAppearanceObserver: Sendable {

    private let connection: DBusConnection

    private let following: Task<Void, Never>

    private init(connection: DBusConnection, following: Task<Void, Never>) {
        self.connection = connection
        self.following = following
    }

    /// Connects to the session bus, or the bus at `address` (such as
    /// `unix:path=/run/user/1000/bus`), reads the appearance, and then
    /// calls `onChange` with the appearance after each change, from a task
    /// of its own.
    ///
    /// Returns `nil` when there's no bus to connect to. A bus with no
    /// portal on it answers with nothing set, and changes are still heard
    /// should a portal start later.
    ///
    /// - Parameter timeout: How long to wait for each reply.
    public static func start(
        address: String? = nil,
        timeout: Duration = .seconds(2),
        onChange: @escaping @Sendable (PortalAppearance) -> Void
    ) async -> (observer: PortalAppearanceObserver, appearance: PortalAppearance)? {
        let connection: DBusConnection
        do {
            if let address {
                connection = try await DBusConnection.connect(to: address)
            } else {
                connection = try await DBusConnection.connect(to: .session)
            }
        } catch {
            return nil
        }
        guard let client = try? FreedesktopPortal.Settings(connection: connection) else {
            await connection.close()
            return nil
        }
        // Subscribed before reading, so a change between the two isn't
        // missed. The keys are in two namespaces, so every setting's
        // changes are heard, and those of others ignored.
        let rule = DBusMatchRule.signal(
            interface: client.proxy.interface,
            member: PortalSettings.settingChanged,
            path: client.proxy.path
        )
        let signals = try? await connection.signals(matching: rule)

        let appearance = await PortalSettings(client: client, timeout: timeout).readAppearance()

        let following = Task {
            guard let signals else { return }
            var current = appearance
            for await signal in signals {
                if current.apply(settingChanged: signal.arguments) {
                    onChange(current)
                }
            }
        }
        return (PortalAppearanceObserver(connection: connection, following: following), appearance)
    }

    /// Stops hearing changes and closes the connection.
    public func stop() async {
        following.cancel()
        await connection.close()
    }
}

// MARK: - Settings portal

/// Calls to the settings portal.
internal struct PortalSettings: Sendable {

    static let settingChanged = DBusMember(rawValue: "SettingChanged")!

    let client: FreedesktopPortal.Settings

    let timeout: Duration

    /// Reads every key the appearance has.
    func readAppearance() async -> PortalAppearance {
        async let colorScheme = read(.colorScheme)
        async let accentColor = read(.accentColor)
        async let contrast = read(.contrast)
        async let buttonLayout = read(.buttonLayout)
        var appearance = PortalAppearance()
        let values = await [
            (PortalAppearance.Key.colorScheme, colorScheme),
            (.accentColor, accentColor),
            (.contrast, contrast),
            (.buttonLayout, buttonLayout),
        ]
        for (key, value) in values {
            if let value {
                appearance.apply(value, for: key)
            }
        }
        return appearance
    }

    /// A setting's value, or `nil` when the portal has none or doesn't
    /// answer. Portals before version 2 have only `Read`, which wraps the
    /// value in a second variant.
    func read(_ key: PortalAppearance.Key) async -> DBusMessageArgument? {
        do {
            return try await read(key, legacy: false)
        } catch let error as DBusError where error.name.rawValue == "org.freedesktop.DBus.Error.UnknownMethod" {
            return try? await read(key, legacy: true)
        } catch {
            return nil
        }
    }

    private func read(_ key: PortalAppearance.Key, legacy: Bool) async throws -> DBusMessageArgument? {
        if timeout == DBusConnection.defaultTimeout {
            let value = try await (legacy
                ? client.read(namespace: key.namespace, key: key.rawValue)
                : client.readOne(namespace: key.namespace, key: key.rawValue))
            return .variant(value)
        }

        // Generated methods use DBusConnection.defaultTimeout. Keep the
        // observer's caller-supplied deadline on the same endpoint.
        let proxy = client.proxy
        let method = DBusMember(rawValue: legacy ? "Read" : "ReadOne")!
        return try await proxy.connection.callMethod(
            destination: proxy.destination,
            path: proxy.path,
            interface: proxy.interface,
            method: method,
            arguments: [.string(key.namespace), .string(key.rawValue)],
            timeout: timeout
        ).first
    }
}
