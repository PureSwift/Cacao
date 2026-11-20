//
//  Color.swift
//  Cacao
//
//  Created by Alsey Coleman Miller on 11/13/26.
//

import CacaoRender
import Foundation
#if canImport(CoreGraphics)
import CoreGraphics
#endif
#if canImport(AppKit)
import AppKit
#endif

/// A representation of a color that adapts to a given context.
public struct Color: Hashable, Sendable, CustomStringConvertible {

    internal indirect enum Storage: Hashable, Sendable {
        case resolved(Resolved)
        case system(SystemColor)
        case opacity(Color, Double)
        case mix(Color, Color, Double)
        /// Different colors in light and dark appearances.
        case adaptive(light: Resolved, dark: Resolved)
    }

    internal let storage: Storage

    internal init(storage: Storage) {
        self.storage = storage
    }

    /// Creates a constant color from a resolved color.
    public init(_ resolved: Resolved) {
        self.init(storage: .resolved(resolved))
    }

    /// A profile that specifies how to interpret a color value for display.
    public enum RGBColorSpace: Hashable, Sendable {

        /// The extended red, green, blue (sRGB) color space.
        case sRGB

        /// The extended sRGB color space with a linear transfer function.
        case sRGBLinear

        /// The Display P3 color space, drawn as sRGB.
        case displayP3

        /// A component in this space, as sRGB.
        func encoded(_ value: Double) -> Double {
            guard self == .sRGBLinear else { return value }
            let magnitude = abs(value)
            let encoded = magnitude <= 0.0031308 ? magnitude * 12.92 : 1.055 * pow(magnitude, 1 / 2.4) - 0.055
            return value < 0 ? -encoded : encoded
        }
    }

    /// Creates a constant color from red, green, and blue component values.
    public init(_ colorSpace: RGBColorSpace = .sRGB, red: Double, green: Double, blue: Double, opacity: Double = 1) {
        self.init(Resolved(
            red: Float(colorSpace.encoded(red)),
            green: Float(colorSpace.encoded(green)),
            blue: Float(colorSpace.encoded(blue)),
            opacity: Float(opacity)
        ))
    }

    /// Creates a constant grayscale color.
    public init(_ colorSpace: RGBColorSpace = .sRGB, white: Double, opacity: Double = 1) {
        self.init(colorSpace, red: white, green: white, blue: white, opacity: opacity)
    }

    /// Creates a constant color from hue, saturation, and brightness values.
    public init(hue: Double, saturation: Double, brightness: Double, opacity: Double = 1) {
        let h = (hue - floor(hue)) * 6
        let c = brightness * saturation
        let x = c * (1 - abs(h.truncatingRemainder(dividingBy: 2) - 1))
        let m = brightness - c
        let (r, g, b): (Double, Double, Double) = switch Int(h) {
        case 0: (c, x, 0)
        case 1: (x, c, 0)
        case 2: (0, c, x)
        case 3: (0, x, c)
        case 4: (x, 0, c)
        default: (c, 0, x)
        }
        self.init(red: r + m, green: g + m, blue: b + m, opacity: opacity)
    }

    /// Multiplies the opacity of the color by the given amount.
    public func opacity(_ opacity: Double) -> Color {
        Color(storage: .opacity(self, opacity))
    }

    /// Evaluates this color to a resolved color given the current context.
    public func resolve(in environment: EnvironmentValues) -> Resolved {
        switch storage {
        case let .resolved(resolved):
            return resolved
        case .system(.accent):
            if let tint = environment.tint, tint.storage != .system(.accent) {
                return tint.resolve(in: environment)
            }
            return SystemColor.blue.resolve(in: environment.colorScheme)
        case let .system(color):
            return color.resolve(in: environment.colorScheme)
        case let .adaptive(light, dark):
            return environment.colorScheme == .dark ? dark : light
        case let .opacity(color, opacity):
            var resolved = color.resolve(in: environment)
            resolved.opacity *= Float(opacity)
            return resolved
        case let .mix(base, other, fraction):
            let base = base.resolve(in: environment)
            let other = other.resolve(in: environment)
            let amount = Float(fraction)
            return Resolved(
                red: base.red + (other.red - base.red) * amount,
                green: base.green + (other.green - base.green) * amount,
                blue: base.blue + (other.blue - base.blue) * amount,
                opacity: base.opacity
            )
        }
    }

    /// Returns a version of the color mixed with another color, by an
    /// amount between 0 and 1.
    public func mix(with other: Color, by fraction: Double) -> Color {
        Color(storage: .mix(self, other, max(0, min(1, fraction))))
    }

    public var description: String {
        switch storage {
        case let .resolved(resolved): "\(resolved)"
        case let .system(color): color.rawValue
        case let .opacity(color, opacity): "\(Int(opacity * 100))% \(color)"
        case let .mix(base, other, fraction): "\(base) mixed with \(other) by \(fraction)"
        case let .adaptive(light, dark): "\(light) in light, \(dark) in dark"
        }
    }
}

// MARK: - Resolved

extension Color {

    /// A concrete color value, with components in the sRGB color space.
    public typealias Resolved = ResolvedColor
}

// MARK: - System colors

internal enum SystemColor: String, Hashable, Sendable {
    case red, orange, yellow, green, mint, teal, cyan, blue, indigo, purple, pink, brown, gray
    case primary, secondary, separator
    /// The tint from the environment, or blue.
    case accent

    func resolve(in colorScheme: ColorScheme) -> Color.Resolved {
        let isDark = colorScheme == .dark
        switch self {
        case .red: return isDark ? .init(255, 69, 58) : .init(255, 59, 48)
        case .orange: return isDark ? .init(255, 159, 10) : .init(255, 149, 0)
        case .yellow: return isDark ? .init(255, 214, 10) : .init(255, 204, 0)
        case .green: return isDark ? .init(48, 209, 88) : .init(52, 199, 89)
        case .mint: return isDark ? .init(99, 230, 226) : .init(0, 199, 190)
        case .teal: return isDark ? .init(64, 200, 224) : .init(48, 176, 199)
        case .cyan: return isDark ? .init(100, 210, 255) : .init(50, 173, 230)
        case .blue: return isDark ? .init(10, 132, 255) : .init(0, 122, 255)
        case .indigo: return isDark ? .init(94, 92, 230) : .init(88, 86, 214)
        case .purple: return isDark ? .init(191, 90, 242) : .init(175, 82, 222)
        case .pink: return isDark ? .init(255, 55, 95) : .init(255, 45, 85)
        case .brown: return isDark ? .init(172, 142, 104) : .init(162, 132, 94)
        case .gray: return .init(142, 142, 147)
        case .primary: return isDark ? .init(255, 255, 255) : .init(0, 0, 0)
        case .secondary: return isDark ? .init(235, 235, 245, 0.6) : .init(60, 60, 67, 0.6)
        case .separator: return isDark ? .init(84, 84, 88, 0.6) : .init(60, 60, 67, 0.29)
        case .accent: return SystemColor.blue.resolve(in: colorScheme)
        }
    }
}

extension Color {

    public static let red = Color(storage: .system(.red))
    public static let orange = Color(storage: .system(.orange))
    public static let yellow = Color(storage: .system(.yellow))
    public static let green = Color(storage: .system(.green))
    public static let mint = Color(storage: .system(.mint))
    public static let teal = Color(storage: .system(.teal))
    public static let cyan = Color(storage: .system(.cyan))
    public static let blue = Color(storage: .system(.blue))
    public static let indigo = Color(storage: .system(.indigo))
    public static let purple = Color(storage: .system(.purple))
    public static let pink = Color(storage: .system(.pink))
    public static let brown = Color(storage: .system(.brown))
    public static let gray = Color(storage: .system(.gray))
    public static let white = Color(Resolved(red: 1, green: 1, blue: 1))
    public static let black = Color(Resolved(red: 0, green: 0, blue: 0))
    public static let clear = Color(Resolved(red: 0, green: 0, blue: 0, opacity: 0))

    /// The color to use for primary content.
    public static let primary = Color(storage: .system(.primary))

    /// The color to use for secondary content.
    public static let secondary = Color(storage: .system(.secondary))

    /// A color that reflects the accent color of the system or app.
    public static var accentColor: Color { Color(storage: .system(.accent)) }

    internal static let separator = Color(storage: .system(.separator))
}

// MARK: - ColorScheme

/// The possible color schemes, corresponding to the light and dark appearances.
public enum ColorScheme: Hashable, CaseIterable, Sendable {

    case light

    case dark
}

// MARK: - View

extension Color: View, PrimitiveView {

    public typealias Body = Never

    func resolve(in context: ResolveContext) -> Resolution {
        Resolution(behavior: FillBehavior(color: resolve(in: context.environment)))
    }
}

/// A view that fills the space it's offered with a color.
///
/// Like SwiftUI's shapes, it takes the proposed size, and 10 points along
/// any dimension left unspecified.
internal struct FillBehavior: AnimatableBehavior {

    var color: Color.Resolved

    var animatableValues: [Double] {
        color.components
    }

    func applying(_ values: [Double]) -> any NodeBehavior {
        FillBehavior(color: Color.Resolved(components: values))
    }

    func sizeThatFits(_ proposal: ProposedViewSize, node: ViewNode) -> CGSize {
        proposal.replacingUnspecifiedDimensions()
    }

    func displayContent(node: ViewNode) -> DisplayList.Content? {
        .color(color)
    }

    /// Clear colors don't take hits.
    func hitTest(_ point: CGPoint, node: ViewNode) -> Bool {
        color.opacity > 0 && node.frame.contains(point)
    }
}

#if canImport(AppKit)
extension Color {

    /// Creates a color from an AppKit color, following its light and dark
    /// appearances.
    public init(_ color: NSColor) {
        func resolved(_ appearance: NSAppearance.Name) -> Resolved {
            var result = Resolved(red: 0, green: 0, blue: 0, opacity: 1)
            NSAppearance(named: appearance)?.performAsCurrentDrawingAppearance {
                guard let rgb = color.usingColorSpace(.sRGB) else { return }
                result = Resolved(
                    red: Float(rgb.redComponent),
                    green: Float(rgb.greenComponent),
                    blue: Float(rgb.blueComponent),
                    opacity: Float(rgb.alphaComponent)
                )
            }
            return result
        }
        self.init(storage: .adaptive(light: resolved(.aqua), dark: resolved(.darkAqua)))
    }

    /// Creates a color from an AppKit color.
    public init(nsColor color: NSColor) {
        self.init(color)
    }
}
#endif

