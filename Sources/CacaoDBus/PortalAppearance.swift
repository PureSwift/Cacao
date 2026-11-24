//
//  PortalAppearance.swift
//  CacaoDBus
//
//  Created by Alsey Coleman Miller on 11/23/26.
//

public import CacaoTokens
package import DBus

/// The appearance the desktop serves through the freedesktop settings
/// portal, in the `org.freedesktop.appearance` namespace: `CacaoTokens`'
/// `Appearance`, so what's read here resolves style tokens as it is.
///
/// A value is `nil` when the portal didn't serve it.
public typealias PortalAppearance = Appearance

// MARK: - Keys

package extension PortalAppearance {

    /// The namespace the appearance keys are in.
    static let namespace = "org.freedesktop.appearance"

    /// The keys this reads.
    enum Key: String, CaseIterable, Sendable {
        case colorScheme = "color-scheme"
        case accentColor = "accent-color"
        case contrast = "contrast"
    }

    /// Sets the value a key names from what the portal sent: a reply to
    /// `ReadOne` or `Read`, or a `SettingChanged` signal's value. Returns
    /// whether the appearance changed.
    @discardableResult
    mutating func apply(_ value: DBusMessageArgument, for key: Key) -> Bool {
        let old = self
        switch key {
        case .colorScheme:
            colorScheme = Self.colorScheme(from: value)
        case .accentColor:
            accentColor = Self.accentColor(from: value)
        case .contrast:
            contrast = Self.contrast(from: value)
        }
        return self != old
    }

    /// Applies a `SettingChanged(s namespace, s key, v value)` signal's
    /// arguments. Returns whether the appearance changed; settings in other
    /// namespaces, and keys this doesn't read, change nothing.
    @discardableResult
    mutating func apply(settingChanged arguments: [DBusMessageArgument]) -> Bool {
        guard arguments.count == 3,
              case let .string(namespace) = arguments[0],
              namespace == Self.namespace,
              case let .string(name) = arguments[1],
              let key = Key(rawValue: name)
        else {
            return false
        }
        return apply(arguments[2], for: key)
    }
}

// MARK: - Decoding

package extension PortalAppearance {

    /// A `color-scheme` value, a `u`. The portal says to read values it
    /// doesn't define as no preference.
    static func colorScheme(from value: DBusMessageArgument) -> ColorScheme? {
        guard case let .uint32(raw) = unwrapped(value) else {
            return nil
        }
        return ColorScheme(rawValue: raw) ?? .noPreference
    }

    /// A `contrast` value, a `u`. Values the portal doesn't define are
    /// normal contrast.
    static func contrast(from value: DBusMessageArgument) -> Contrast? {
        guard case let .uint32(raw) = unwrapped(value) else {
            return nil
        }
        return Contrast(rawValue: raw) ?? .normal
    }

    /// An `accent-color` value, a `(ddd)`. The portal says components out
    /// of the range 0 to 1 mean the accent isn't set.
    static func accentColor(from value: DBusMessageArgument) -> AccentColor? {
        guard case let .struct(structure) = unwrapped(value) else {
            return nil
        }
        let components = structure.compactMap { element -> Double? in
            guard case let .double(component) = element, (0 ... 1).contains(component) else {
                return nil
            }
            return component
        }
        guard components.count == 3, structure.count == 3 else {
            return nil
        }
        return AccentColor(red: components[0], green: components[1], blue: components[2])
    }

    /// The value inside any variants. `ReadOne` replies with the value in a
    /// variant; the older `Read` wraps that variant in another.
    static func unwrapped(_ value: DBusMessageArgument) -> DBusMessageArgument {
        var value = value
        while case let .variant(variant) = value {
            value = variant.element
        }
        return value
    }
}
