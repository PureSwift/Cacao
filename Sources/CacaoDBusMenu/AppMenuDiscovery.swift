//
//  AppMenuDiscovery.swift
//  CacaoDBusMenu
//
//  Created by Alsey Coleman Miller on 11/24/26.
//

public import DBus

/// How a menu bar finds an app's menu from the app's Wayland `app_id`, and
/// how an app learns that a menu bar shows its menus.
///
/// The compositor ties each window to its menu with the KDE appmenu
/// protocol and tells the menu bar the focused window's. Compositors
/// without it, such as sway, only say which `app_id` is focused, so apps
/// also own a bus name made from their `app_id`:
///
///     org.pureswift.Cacao.AppMenu.<app_id, escaped>
///
/// with their menu at `/MenuBar`, the main menu of the app's key window.
/// Each element of the `app_id` (between its dots) keeps its ASCII letters
/// and digits; every other byte of its UTF-8, `_` and `-` included, is
/// written as `_` and two capital hex digits, as is a digit at the start of
/// an element. An empty element is `_`. So `org.pureswift.CacaoDemo` is
/// `org.pureswift.Cacao.AppMenu.org.pureswift.CacaoDemo`, and
/// `org.gnome.Text-Editor` is `org.pureswift.Cacao.AppMenu.org.gnome.Text_2DEditor`.
///
/// A second instance of an app waits in the name's queue and gets the name
/// when the first leaves the bus. A menu bar can list the apps that serve
/// menus with `ListNames`, or follow them with `NameOwnerChanged` and
/// `arg0namespace=org.pureswift.Cacao.AppMenu`.
///
/// A menu bar shows that it's there by owning `com.canonical.AppMenu.Registrar`,
/// as Unity's and KDE's do; Qt apps hide their own menu bars when it's
/// owned, and Cacao's tell apps with `isMenuBarPresent(on:)`.
public enum AppMenuDiscovery {

    /// The bus names apps own are in this namespace.
    public static let namespace = "org.pureswift.Cacao.AppMenu"

    /// The object path the app serves its menu at.
    public static let path = DBusMenuInterface.defaultPath

    /// The name a menu bar owns while it shows apps' menus.
    public static let registrarName = DBusBusName(rawValue: "com.canonical.AppMenu.Registrar")!

    // MARK: Names

    /// The bus name of an app's menu, or `nil` if the `app_id` is empty or
    /// makes a name too long for the bus.
    public static func busName(forAppID appID: String) -> DBusBusName? {
        guard !appID.isEmpty else { return nil }
        let elements = appID.split(separator: ".", omittingEmptySubsequences: false).map(escape)
        return DBusBusName(rawValue: ([namespace] + elements).joined(separator: "."))
    }

    /// The `app_id` a bus name was made from, or `nil` if it isn't one.
    public static func appID(forBusName name: DBusBusName) -> String? {
        let prefix = namespace + "."
        guard name.rawValue.hasPrefix(prefix) else { return nil }
        let elements = name.rawValue.dropFirst(prefix.count).split(separator: ".", omittingEmptySubsequences: false)
        var unescaped: [String] = []
        for element in elements {
            guard let element = unescape(element) else { return nil }
            unescaped.append(element)
        }
        return unescaped.joined(separator: ".")
    }

    /// An element of an `app_id`, written with only letters, digits and `_`.
    private static func escape(_ element: Substring) -> String {
        guard !element.isEmpty else { return "_" }
        var escaped = ""
        for (index, byte) in element.utf8.enumerated() {
            let isLetter = (byte >= 0x41 && byte <= 0x5A) || (byte >= 0x61 && byte <= 0x7A)
            let isDigit = byte >= 0x30 && byte <= 0x39
            if isLetter || (isDigit && index > 0) {
                escaped.append(Character(Unicode.Scalar(byte)))
            } else {
                escaped += "_" + hexDigits(byte)
            }
        }
        return escaped
    }

    private static func unescape(_ element: Substring) -> String? {
        if element == "_" { return "" }
        var bytes: [UInt8] = []
        var utf8 = element.utf8.makeIterator()
        while let byte = utf8.next() {
            guard byte == UInt8(ascii: "_") else {
                bytes.append(byte)
                continue
            }
            guard let high = utf8.next().flatMap(hexValue), let low = utf8.next().flatMap(hexValue) else {
                return nil
            }
            bytes.append(high << 4 | low)
        }
        let string = String(decoding: bytes, as: UTF8.self)
        // Bytes that aren't UTF-8 weren't made from an app_id.
        return Array(string.utf8) == bytes ? string : nil
    }

    private static func hexDigits(_ byte: UInt8) -> String {
        let digits = Array("0123456789ABCDEF")
        return String([digits[Int(byte >> 4)], digits[Int(byte & 0xF)]])
    }

    private static func hexValue(_ digit: UInt8) -> UInt8? {
        switch digit {
        case 0x30 ... 0x39: digit - 0x30
        case 0x41 ... 0x46: digit - 0x41 + 10
        case 0x61 ... 0x66: digit - 0x61 + 10
        default: nil
        }
    }

    // MARK: Apps

    /// Owns the bus name of the app's menu on the connection that serves
    /// it. Returns whether the app owns it now; otherwise it waits in the
    /// name's queue behind an instance that started earlier.
    @discardableResult
    public static func claimName(forAppID appID: String, on connection: DBusConnection) async throws -> Bool {
        guard let name = busName(forAppID: appID) else {
            throw DBusError(name: .invalidArguments, message: "There's no bus name for the app_id \(appID)")
        }
        return try await connection.requestName(name, flags: []) == .primaryOwner
    }

    /// Whether a global menu bar shows apps' menus now.
    public static func isMenuBarPresent(on connection: DBusConnection) async -> Bool {
        (try? await connection.nameHasOwner(registrarName)) ?? false
    }

    /// Whether a global menu bar shows apps' menus: now, and then each time
    /// that changes, until the connection closes or the stream is dropped.
    public static func menuBarPresence(on connection: DBusConnection) async throws -> AsyncStream<Bool> {
        let signals = try await connection.signals(matching: .nameOwnerChanged(name: registrarName))
        let isPresent = await isMenuBarPresent(on: connection)
        let (stream, continuation) = AsyncStream<Bool>.makeStream(bufferingPolicy: .bufferingNewest(1))
        continuation.yield(isPresent)
        let task = Task {
            var last = isPresent
            for await signal in signals {
                // (name, old owner, new owner)
                guard signal.arguments.count == 3, let newOwner = signal.arguments[2].string else { continue }
                let isPresent = !newOwner.isEmpty
                if isPresent != last {
                    last = isPresent
                    continuation.yield(isPresent)
                }
            }
            continuation.finish()
        }
        continuation.onTermination = { _ in task.cancel() }
        return stream
    }

    // MARK: Menu bars

    /// A reader for the menu of the app with an `app_id`, not yet started;
    /// `nil` if no app with it serves a menu.
    public static func reader(forAppID appID: String, on connection: DBusConnection, timeout: Duration = .seconds(2)) async -> DBusMenuReader? {
        guard let name = busName(forAppID: appID),
              let owner = try? await connection.getNameOwner(name) else {
            return nil
        }
        return DBusMenuReader(connection: connection, service: owner, path: path, timeout: timeout)
    }
}
