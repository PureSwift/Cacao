//
//  Font.swift
//  Cacao
//
//  Created by Alsey Coleman Miller on 11/13/26.
//

import Foundation
#if canImport(CoreGraphics)
import CoreGraphics
#endif

/// An environment-dependent font.
public struct Font: Hashable, Sendable {

    internal enum Provider: Hashable, Sendable {
        case textStyle(TextStyle, design: Design?, weight: Weight?)
        case system(size: CGFloat, weight: Weight?, design: Design?)
        case custom(name: String, size: CGFloat)
    }

    internal var provider: Provider

    internal var weight: Weight?

    internal var isItalic = false

    internal var isMonospacedDigit = false

    internal init(provider: Provider) {
        self.provider = provider
    }

    // MARK: Text styles

    /// A font with the large title text style.
    public static let largeTitle = Font(provider: .textStyle(.largeTitle, design: nil, weight: nil))

    /// A font with the title text style.
    public static let title = Font(provider: .textStyle(.title, design: nil, weight: nil))

    /// Create a font for second level hierarchical headings.
    public static let title2 = Font(provider: .textStyle(.title2, design: nil, weight: nil))

    /// Create a font for third level hierarchical headings.
    public static let title3 = Font(provider: .textStyle(.title3, design: nil, weight: nil))

    /// A font with the headline text style.
    public static let headline = Font(provider: .textStyle(.headline, design: nil, weight: nil))

    /// A font with the subheadline text style.
    public static let subheadline = Font(provider: .textStyle(.subheadline, design: nil, weight: nil))

    /// A font with the body text style.
    public static let body = Font(provider: .textStyle(.body, design: nil, weight: nil))

    /// A font with the callout text style.
    public static let callout = Font(provider: .textStyle(.callout, design: nil, weight: nil))

    /// A font with the footnote text style.
    public static let footnote = Font(provider: .textStyle(.footnote, design: nil, weight: nil))

    /// A font with the caption text style.
    public static let caption = Font(provider: .textStyle(.caption, design: nil, weight: nil))

    /// Create a font with the alternate caption text style.
    public static let caption2 = Font(provider: .textStyle(.caption2, design: nil, weight: nil))

    // MARK: Factories

    /// Specifies a system font to use, along with the style, weight, and any
    /// design parameters you want applied to the text.
    public static func system(size: CGFloat, weight: Weight? = nil, design: Design? = nil) -> Font {
        Font(provider: .system(size: size, weight: weight, design: design))
    }

    /// Gets a system font that uses the specified style, design, and weight.
    public static func system(_ style: TextStyle, design: Design? = nil, weight: Weight? = nil) -> Font {
        Font(provider: .textStyle(style, design: design, weight: weight))
    }

    /// Create a custom font with the given `name` and `size`.
    public static func custom(_ name: String, size: CGFloat) -> Font {
        Font(provider: .custom(name: name, size: size))
    }

    /// Create a custom font with the given `name` and a fixed `size`.
    public static func custom(_ name: String, fixedSize: CGFloat) -> Font {
        Font(provider: .custom(name: name, size: fixedSize))
    }

    // MARK: Modifiers

    /// Sets the weight of the font.
    public func weight(_ weight: Weight) -> Font {
        var font = self
        font.weight = weight
        return font
    }

    /// Adds bold styling to the font.
    public func bold() -> Font {
        weight(.bold)
    }

    /// Adds italics to the font.
    public func italic() -> Font {
        var font = self
        font.isItalic = true
        return font
    }

    /// Returns a modified font that uses fixed-width digits.
    public func monospacedDigit() -> Font {
        var font = self
        font.isMonospacedDigit = true
        return font
    }

    /// Returns a fixed-width font from the same family as the base font.
    public func monospaced() -> Font {
        var font = self
        switch font.provider {
        case let .textStyle(style, _, weight):
            font.provider = .textStyle(style, design: .monospaced, weight: weight)
        case let .system(size, weight, _):
            font.provider = .system(size: size, weight: weight, design: .monospaced)
        case .custom:
            break
        }
        return font
    }
}

// MARK: - Nested types

extension Font {

    /// A dynamic text style to use for fonts.
    public enum TextStyle: Hashable, CaseIterable, Sendable {
        case largeTitle
        case title
        case title2
        case title3
        case headline
        case subheadline
        case body
        case callout
        case footnote
        case caption
        case caption2

        /// The point size and weight of the style at the default text size.
        internal var metrics: (size: CGFloat, weight: Weight) {
            switch self {
            case .largeTitle: (34, .regular)
            case .title: (28, .regular)
            case .title2: (22, .regular)
            case .title3: (20, .regular)
            case .headline: (17, .semibold)
            case .subheadline: (15, .regular)
            case .body: (17, .regular)
            case .callout: (16, .regular)
            case .footnote: (13, .regular)
            case .caption: (12, .regular)
            case .caption2: (11, .regular)
            }
        }
    }

    /// A weight to use for fonts.
    public struct Weight: Hashable, Sendable {

        /// The OpenType weight class, from 100 (thin) to 900 (black).
        internal let value: Int

        public static let ultraLight = Weight(value: 100)
        public static let thin = Weight(value: 200)
        public static let light = Weight(value: 300)
        public static let regular = Weight(value: 400)
        public static let medium = Weight(value: 500)
        public static let semibold = Weight(value: 600)
        public static let bold = Weight(value: 700)
        public static let heavy = Weight(value: 800)
        public static let black = Weight(value: 900)
    }

    /// A design to use for fonts.
    public enum Design: Hashable, Sendable {
        case `default`
        case serif
        case rounded
        case monospaced
    }
}

// MARK: - Resolved

extension Font {

    /// A font's concrete face and size, which a text engine draws with.
    package struct Resolved: Hashable, Sendable {

        /// The font family name, or `nil` for the system font.
        package var name: String?

        package var size: CGFloat

        /// The OpenType weight class, from 100 to 900.
        package var weight: Int

        package var design: Design

        package var isItalic: Bool

        package var isMonospacedDigit: Bool
    }

    /// The concrete font at the default text size.
    package func resolve() -> Resolved {
        let name: String?
        let size: CGFloat
        var weight: Weight
        let design: Design
        switch provider {
        case let .textStyle(style, styleDesign, styleWeight):
            name = nil
            size = style.metrics.size
            weight = styleWeight ?? style.metrics.weight
            design = styleDesign ?? .default
        case let .system(systemSize, systemWeight, systemDesign):
            name = nil
            size = systemSize
            weight = systemWeight ?? .regular
            design = systemDesign ?? .default
        case let .custom(customName, customSize):
            name = customName
            size = customSize
            weight = .regular
            design = .default
        }
        if let override = self.weight {
            weight = override
        }
        return Resolved(
            name: name,
            size: size,
            weight: weight.value,
            design: design,
            isItalic: isItalic,
            isMonospacedDigit: isMonospacedDigit
        )
    }
}
