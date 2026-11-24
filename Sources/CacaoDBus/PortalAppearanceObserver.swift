//
//  PortalAppearanceObserver.swift
//  CacaoDBus
//
//  Created by Alsey Coleman Miller on 11/23/26.
//

public import CacaoTokens
internal import DBus

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
        // Subscribed before reading, so a change between the two isn't
        // missed. The keys are in two namespaces, so every setting's
        // changes are heard, and those of others ignored.
        let rule = DBusMatchRule.signal(
            interface: PortalSettings.interface,
            member: PortalSettings.settingChanged,
            path: PortalSettings.path
        )
        let signals = try? await connection.signals(matching: rule)

        let appearance = await PortalSettings(connection: connection, timeout: timeout).readAppearance()

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

    static let destination = DBusBusName(rawValue: "org.freedesktop.portal.Desktop")!

    static let path = DBusObjectPath(rawValue: "/org/freedesktop/portal/desktop")!

    static let interface = DBusInterface(rawValue: "org.freedesktop.portal.Settings")!

    static let settingChanged = DBusMember(rawValue: "SettingChanged")!

    static let readOne = DBusMember(rawValue: "ReadOne")!

    static let read = DBusMember(rawValue: "Read")!

    let connection: DBusConnection

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
        let arguments: [DBusMessageArgument] = [.string(key.namespace), .string(key.rawValue)]
        do {
            return try await call(Self.readOne, arguments: arguments)
        } catch let error as DBusError where error.name.rawValue == "org.freedesktop.DBus.Error.UnknownMethod" {
            return try? await call(Self.read, arguments: arguments)
        } catch {
            return nil
        }
    }

    private func call(_ method: DBusMember, arguments: [DBusMessageArgument]) async throws -> DBusMessageArgument? {
        try await connection.callMethod(
            destination: Self.destination,
            path: Self.path,
            interface: Self.interface,
            method: method,
            arguments: arguments,
            timeout: timeout
        ).first
    }
}
