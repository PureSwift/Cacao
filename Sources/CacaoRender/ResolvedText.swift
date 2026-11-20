//
//  ResolvedText.swift
//  CacaoRender
//
//  Created by Alsey Coleman Miller on 11/13/26.
//

import Foundation
#if canImport(CoreGraphics)
import CoreGraphics
#endif

/// Text with concrete fonts and colors, ready to measure and draw.
public struct ResolvedText: Hashable, Sendable {

    public struct Run: Hashable, Sendable {

        public var string: String

        public var font: ResolvedFont

        public var color: ResolvedColor

        /// A line under the run.
        public var underline: Line? = nil

        /// A line through the run.
        public var strikethrough: Line? = nil

        /// Extra space after each character.
        public var tracking: CGFloat = 0

        /// How far the run is raised above the baseline.
        public var baselineOffset: CGFloat = 0

        public init(
            string: String,
            font: ResolvedFont,
            color: ResolvedColor,
            underline: Line? = nil,
            strikethrough: Line? = nil,
            tracking: CGFloat = 0,
            baselineOffset: CGFloat = 0
        ) {
            self.string = string
            self.font = font
            self.color = color
            self.underline = underline
            self.strikethrough = strikethrough
            self.tracking = tracking
            self.baselineOffset = baselineOffset
        }
    }

    /// A line drawn under or through a run.
    public struct Line: Hashable, Sendable {

        public var color: ResolvedColor

        public var pattern: TextLinePattern

        public init(color: ResolvedColor, pattern: TextLinePattern = .solid) {
            self.color = color
            self.pattern = pattern
        }

        /// The lengths of dashes and gaps for a line of a thickness.
        public func dashes(thickness: CGFloat) -> [CGFloat] {
            let unit = max(thickness, 1)
            switch pattern {
            case .solid: return []
            case .dot: return [unit, unit * 2]
            case .dash: return [unit * 4, unit * 2]
            case .dashDot: return [unit * 4, unit * 2, unit, unit * 2]
            case .dashDotDot: return [unit * 4, unit * 2, unit, unit * 2, unit, unit * 2]
            }
        }
    }

    public var runs: [Run]

    public var alignment: TextAlignment

    public var lineLimit: Int?

    /// Extra space between lines.
    public var lineSpacing: CGFloat = 0

    /// Where text that doesn't fit is cut for an ellipsis.
    public var truncationMode: TruncationMode = .tail

    /// How far fonts may shrink to fit before text is truncated.
    public var minimumScaleFactor: CGFloat = 1

    public init(
        runs: [Run],
        alignment: TextAlignment = .leading,
        lineLimit: Int? = nil,
        lineSpacing: CGFloat = 0,
        truncationMode: TruncationMode = .tail,
        minimumScaleFactor: CGFloat = 1
    ) {
        self.runs = runs
        self.alignment = alignment
        self.lineLimit = lineLimit
        self.lineSpacing = lineSpacing
        self.truncationMode = truncationMode
        self.minimumScaleFactor = minimumScaleFactor
    }

    /// The text with every font and spacing scaled.
    public func scaled(by factor: CGFloat) -> ResolvedText {
        var text = self
        text.minimumScaleFactor = 1
        for index in text.runs.indices {
            text.runs[index].font.size *= factor
            text.runs[index].tracking *= factor
            text.runs[index].baselineOffset *= factor
        }
        text.lineSpacing *= factor
        return text
    }

    /// The text of all runs.
    public var string: String {
        runs.map(\.string).joined()
    }
}

/// The type of truncation to apply to a line of text when it's too long to
/// fit in the available space.
public enum TruncationMode: Hashable, Sendable {
    case head
    case tail
    case middle
}

/// An alignment position for text along the horizontal axis.
public enum TextAlignment: Hashable, CaseIterable, Sendable {

    case leading

    case center

    case trailing
}

/// The pattern of a line under or through text.
public enum TextLinePattern: Hashable, Sendable {
    case solid
    case dot
    case dash
    case dashDot
    case dashDotDot
}

/// A design to use for fonts.
public enum FontDesign: Hashable, Sendable {
    case `default`
    case serif
    case rounded
    case monospaced
}

/// A font's concrete face and size, which a text engine draws with.
public struct ResolvedFont: Hashable, Sendable {

    /// The font family name, or `nil` for the system font.
    public var name: String?

    public var size: CGFloat

    /// The OpenType weight class, from 100 to 900.
    public var weight: Int

    public var design: FontDesign

    public var isItalic: Bool

    public var isMonospacedDigit: Bool

    public init(
        name: String? = nil,
        size: CGFloat,
        weight: Int = 400,
        design: FontDesign = .default,
        isItalic: Bool = false,
        isMonospacedDigit: Bool = false
    ) {
        self.name = name
        self.size = size
        self.weight = weight
        self.design = design
        self.isItalic = isItalic
        self.isMonospacedDigit = isMonospacedDigit
    }
}
