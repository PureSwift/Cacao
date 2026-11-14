//
//  TextEngine.swift
//  Cacao
//
//  Created by Alsey Coleman Miller on 11/13/26.
//

import Foundation
#if canImport(CoreGraphics)
import CoreGraphics
#endif

/// Measures and lays out text.
///
/// The host provides one backed by real fonts; `FixedTextEngine` gives
/// deterministic metrics for tests.
@MainActor
package protocol TextEngine {

    /// Lays out text for a proposed size: wrapping to the proposed width
    /// (or not at all when it's unspecified), and showing as many lines as
    /// fit the proposed height and the line limit, at least one.
    func layout(_ text: ResolvedText, in proposal: ProposedViewSize) -> TextLayout
}

/// The size and lines of laid out text.
package struct TextLayout: Equatable, Sendable {

    package var size: CGSize

    /// The distance from the top to the first line's baseline.
    package var firstBaseline: CGFloat

    /// The distance from the top to the last line's baseline.
    package var lastBaseline: CGFloat

    /// The text of each line.
    package var lines: [String]

    package init(size: CGSize, firstBaseline: CGFloat, lastBaseline: CGFloat, lines: [String]) {
        self.size = size
        self.firstBaseline = firstBaseline
        self.lastBaseline = lastBaseline
        self.lines = lines
    }
}

/// A text engine with fixed metrics: every character is the same width,
/// a fraction of its font size, and lines are a fixed multiple of it.
package struct FixedTextEngine: TextEngine {

    /// A character's width as a fraction of its font size.
    package var characterWidth: CGFloat

    /// A line's height as a multiple of the largest font size.
    package var lineHeight: CGFloat

    /// The baseline's distance from the top of a line, as a fraction of the
    /// largest font size.
    package var ascent: CGFloat

    package init(characterWidth: CGFloat = 0.5, lineHeight: CGFloat = 1.2, ascent: CGFloat = 0.95) {
        self.characterWidth = characterWidth
        self.lineHeight = lineHeight
        self.ascent = ascent
    }

    package func layout(_ text: ResolvedText, in proposal: ProposedViewSize) -> TextLayout {
        let fontSize = text.runs.map(\.font.size).max() ?? 0
        let string = text.string
        guard !string.isEmpty, fontSize > 0 else {
            return TextLayout(size: .zero, firstBaseline: 0, lastBaseline: 0, lines: [])
        }
        let advance = fontSize * characterWidth + (text.runs.map(\.tracking).max() ?? 0)
        let lineHeight = fontSize * self.lineHeight
        let pitch = lineHeight + text.lineSpacing
        let maxWidth = proposal.width ?? .infinity
        func width(_ line: Substring) -> CGFloat {
            CGFloat(line.count) * advance
        }

        // Greedy word wrapping, breaking words that don't fit on a line.
        var lines: [Substring] = []
        for paragraph in string.split(separator: "\n", omittingEmptySubsequences: false) {
            var line: Substring = ""
            for word in paragraph.split(separator: " ", omittingEmptySubsequences: false) {
                let candidate = line.isEmpty ? word : paragraph[line.startIndex..<word.endIndex]
                if width(candidate) <= maxWidth || line.isEmpty && width(word) <= maxWidth {
                    line = candidate
                    continue
                }
                if !line.isEmpty {
                    lines.append(line)
                }
                // Break a word wider than a line into pieces that fit.
                var rest = word
                let perLine = maxWidth.isFinite ? max(1, Int(maxWidth / advance)) : .max
                while width(rest) > maxWidth, rest.count > perLine {
                    let end = rest.index(rest.startIndex, offsetBy: perLine)
                    lines.append(rest[rest.startIndex..<end])
                    rest = rest[end...]
                }
                line = rest
            }
            lines.append(line)
        }

        var maxLines = text.lineLimit ?? .max
        if let height = proposal.height, height.isFinite {
            maxLines = min(maxLines, max(1, Int(((height + text.lineSpacing) / pitch).rounded(.down))))
        }
        if lines.count > maxLines {
            lines = Array(lines.prefix(maxLines))
            // The last line ends in an ellipsis, in the space it had.
            let last = lines[lines.count - 1]
            let fits = maxWidth.isFinite ? max(Int(maxWidth / advance) - 1, 0) : max(last.count - 1, 0)
            lines[lines.count - 1] = Substring(String(last.prefix(fits)) + "\u{2026}")
        }
        let measured = lines.map { min(width($0), maxWidth) }.max() ?? 0
        let lineWidth = max(measured, min(advance, maxWidth == .infinity ? advance : maxWidth))
        return TextLayout(
            size: CGSize(width: lineWidth, height: CGFloat(lines.count) * pitch - text.lineSpacing),
            firstBaseline: fontSize * ascent,
            lastBaseline: CGFloat(lines.count - 1) * pitch + fontSize * ascent,
            lines: lines.map(String.init)
        )
    }
}
