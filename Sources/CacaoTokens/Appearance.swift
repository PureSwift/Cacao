//
//  Appearance.swift
//  CacaoTokens
//
//  Created by Alsey Coleman Miller on 11/23/26.
//

import CacaoRender

/// The appearance a desktop asks for: the values the freedesktop settings
/// portal serves in its `org.freedesktop.appearance` namespace.
///
/// `CacaoDBus` reads this from the portal as `PortalAppearance`, which is
/// this type, so what it reads resolves tokens as it is:
///
/// ```swift
/// let tokens = StyleTokens(appearance: appearance)
/// ```
///
/// A value is `nil` when the portal didn't serve it.
public struct Appearance: Hashable, Sendable {

    /// `color-scheme`: whether apps show light or dark windows.
    public var colorScheme: ColorScheme?

    /// `accent-color`: the color controls are tinted with.
    public var accentColor: AccentColor?

    /// `contrast`: whether the user asked for higher contrast.
    public var contrast: Contrast?

    public init(colorScheme: ColorScheme? = nil, accentColor: AccentColor? = nil, contrast: Contrast? = nil) {
        self.colorScheme = colorScheme
        self.accentColor = accentColor
        self.contrast = contrast
    }
}

public extension Appearance {

    /// The portal's `color-scheme` values.
    enum ColorScheme: UInt32, Hashable, Sendable {
        case noPreference = 0
        case dark = 1
        case light = 2
    }

    /// The portal's `contrast` values.
    enum Contrast: UInt32, Hashable, Sendable {
        case normal = 0
        case high = 1
    }

    /// The portal's `accent-color`: sRGB components from 0 to 1.
    struct AccentColor: Hashable, Sendable {

        public var red: Double

        public var green: Double

        public var blue: Double

        public init(red: Double, green: Double, blue: Double) {
            self.red = red
            self.green = green
            self.blue = blue
        }
    }
}

// MARK: - Resolving

public extension Appearance {

    /// Whether windows are dark. No preference is the desktop's default,
    /// which is light, as the portal's documentation describes it.
    var isDark: Bool {
        colorScheme == .dark
    }

    /// Whether the user asked for higher contrast.
    var isHighContrast: Bool {
        contrast == .high
    }
}

public extension Appearance.AccentColor {

    /// The accent with a resolved color's components, its opacity dropped.
    init(_ color: ResolvedColor) {
        self.init(red: Double(color.red), green: Double(color.green), blue: Double(color.blue))
    }
}

public extension ResolvedColor {

    /// The opaque color the portal's accent names.
    init(_ accent: Appearance.AccentColor) {
        self.init(red: Float(accent.red), green: Float(accent.green), blue: Float(accent.blue))
    }
}
