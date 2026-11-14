//
//  SilicaTextEngine.swift
//  CacaoCompositor
//
//  Created by Alsey Coleman Miller on 11/13/26.
//

import Foundation
#if canImport(CoreGraphics)
import CoreGraphics
#endif
import Cacao
import Silica
#if canImport(SilicaCoreGraphics)
import SilicaCoreGraphics
#elseif canImport(SilicaCairo)
import SilicaCairo
#endif

/// Measures, wraps and draws text with the platform's fonts through Silica:
/// CoreText on macOS, FreeType and fontconfig on Linux.
///
/// Measuring and drawing share one line breaker, so text drawn in the frame
/// it was measured for wraps the same way.
@MainActor
package final class SilicaTextEngine: TextEngine {

    private var fonts: [Font.Resolved: Silica.CGFont] = [:]

    private var shapedCache: [ResolvedText: Shaped] = [:]

    package init() {
        #if canImport(SilicaCoreGraphics)
        CoreGraphicsBackend.register()
        #elseif canImport(SilicaCairo)
        CairoBackend.register()
        #endif
    }

    // MARK: Fonts

    /// The platform font for a resolved font.
    func font(for resolved: Font.Resolved) -> Silica.CGFont? {
        if let font = fonts[resolved] {
            return font
        }
        let bold = resolved.weight >= 600
        let italic = resolved.isItalic
        let traits = bold && italic ? "-BoldItalic" : bold ? "-Bold" : italic ? "-Italic" : ""
        var candidates: [String] = []
        if let name = resolved.name {
            candidates.append(name + traits)
            candidates.append(name)
        }
        candidates.append(Self.systemFamily(resolved.design) + traits)
        candidates.append(Self.systemFamily(.default))
        for name in candidates {
            if let font = Silica.CGFont(name: name) {
                fonts[resolved] = font
                return font
            }
        }
        return nil
    }

    private static func systemFamily(_ design: Font.Design) -> String {
        #if canImport(SilicaCoreGraphics)
        switch design {
        case .default, .rounded: "HelveticaNeue"
        case .serif: "TimesNewRoman"
        case .monospaced: "Menlo"
        }
        #else
        // fontconfig's generic families; Silica's names can't contain "-".
        switch design {
        case .default, .rounded: "Sans"
        case .serif: "Serif"
        case .monospaced: "Monospace"
        }
        #endif
    }

    // MARK: Shaping

    /// Text as glyphs: one per Unicode scalar, with advances and run indices.
    struct Shaped {
        var scalars: [Unicode.Scalar] = []
        var glyphs: [CGGlyph] = []
        var advances: [CGFloat] = []
        var runs: [Int] = []
        var fonts: [Silica.CGFont?] = []
        /// The distance from a line's top to its baseline.
        var ascent: CGFloat = 0
        /// A line's height.
        var lineHeight: CGFloat = 0
        /// The distance from one line's top to the next's.
        var pitch: CGFloat = 0
        /// Each run's font size.
        var sizes: [CGFloat] = []
    }

    /// A line: a range of glyphs and its width, or for a truncated line,
    /// the glyphs it shows around an ellipsis.
    struct Line {
        var range: Range<Int>
        var width: CGFloat
        var pieces: [Piece]? = nil
    }

    /// What a truncated line draws: a glyph, or an ellipsis in a run's font.
    enum Piece: Equatable {
        case glyph(Int)
        case ellipsis(run: Int)
    }

    func shape(_ text: ResolvedText) -> Shaped {
        if let shaped = shapedCache[text] {
            return shaped
        }
        var shaped = Shaped()
        var descent: CGFloat = 0
        for (runIndex, run) in text.runs.enumerated() {
            let font = font(for: run.font)
            shaped.fonts.append(font)
            shaped.sizes.append(run.font.size)
            let size = run.font.size
            if let font {
                shaped.ascent = max(shaped.ascent, font.ascent * size)
                descent = max(descent, -font.descent * size)
            } else {
                shaped.ascent = max(shaped.ascent, size * 0.8)
                descent = max(descent, size * 0.2)
            }
            for scalar in run.string.unicodeScalars {
                let glyph = font?.glyph(for: scalar) ?? 0
                shaped.scalars.append(scalar)
                shaped.glyphs.append(glyph)
                shaped.runs.append(runIndex)
                let advance = font?.advances(for: [glyph], fontSize: size).first?.width ?? size * 0.5
                shaped.advances.append(scalar == "\n" ? 0 : advance + run.tracking)
            }
        }
        shaped.lineHeight = (shaped.ascent + descent).rounded(.up)
        shaped.pitch = shaped.lineHeight + text.lineSpacing
        if shapedCache.count > 512 {
            shapedCache.removeAll()
        }
        shapedCache[text] = shaped
        return shaped
    }

    /// Greedy line breaking at spaces and newlines, breaking words wider
    /// than a line. Trailing spaces don't count towards a line's width.
    func lines(_ shaped: Shaped, maxWidth: CGFloat) -> [Line] {
        var lines: [Line] = []
        var start = 0
        var index = 0
        var width: CGFloat = 0
        var lastBreak: (index: Int, width: CGFloat)?
        let count = shaped.scalars.count
        while index < count {
            let scalar = shaped.scalars[index]
            if scalar == "\n" {
                lines.append(Line(range: start..<index, width: width))
                index += 1
                start = index
                width = 0
                lastBreak = nil
                continue
            }
            if scalar == " " {
                lastBreak = (index, width)
                width += shaped.advances[index]
                index += 1
                continue
            }
            let advance = shaped.advances[index]
            if width + advance > maxWidth + 0.01, index > start {
                if let lastBreak, lastBreak.index > start {
                    lines.append(Line(range: start..<lastBreak.index, width: lastBreak.width))
                    start = lastBreak.index + 1
                } else {
                    lines.append(Line(range: start..<index, width: width))
                    start = index
                }
                lastBreak = nil
                index = start
                width = 0
                continue
            }
            width += advance
            index += 1
        }
        // Drop the width of trailing spaces.
        var end = count
        while end > start, shaped.scalars[end - 1] == " " {
            width -= shaped.advances[end - 1]
            end -= 1
        }
        lines.append(Line(range: start..<count, width: max(width, 0)))
        return lines
    }

    /// The most lines that fit the proposal and the line limit.
    private func maxLines(_ text: ResolvedText, _ shaped: Shaped, in proposal: ProposedViewSize) -> Int {
        var maxLines = text.lineLimit ?? .max
        if let height = proposal.height, height.isFinite, shaped.pitch > 0 {
            maxLines = min(maxLines, max(1, Int(((height + text.lineSpacing) / shaped.pitch).rounded(.down))))
        }
        return maxLines
    }

    /// The text with fonts shrunk, as little as needed and no further than
    /// its minimum scale factor, to fit the proposal without truncating.
    func fitted(_ text: ResolvedText, in proposal: ProposedViewSize) -> ResolvedText {
        guard text.minimumScaleFactor < 1 else { return text }
        func fits(_ candidate: ResolvedText) -> Bool {
            let shaped = shape(candidate)
            return lines(shaped, maxWidth: proposal.width ?? .infinity).count <= maxLines(candidate, shaped, in: proposal)
        }
        let full = text.scaled(by: 1)
        if fits(full) { return full }
        var low = text.minimumScaleFactor, high: CGFloat = 1
        let smallest = text.scaled(by: low)
        guard fits(smallest) else { return smallest }
        for _ in 0..<8 {
            let middle = (low + high) / 2
            if fits(text.scaled(by: middle)) { low = middle } else { high = middle }
        }
        return text.scaled(by: low)
    }

    private func visibleLines(_ text: ResolvedText, _ shaped: Shaped, in proposal: ProposedViewSize) -> [Line] {
        var lines = lines(shaped, maxWidth: proposal.width ?? .infinity)
        let maxLines = maxLines(text, shaped, in: proposal)
        if lines.count > maxLines {
            lines = Array(lines.prefix(maxLines))
            let last = lines[lines.count - 1]
            lines[lines.count - 1] = truncated(
                shaped,
                from: last.range.lowerBound,
                width: proposal.width.flatMap { $0.isFinite ? $0 : nil } ?? last.width,
                mode: maxLines == 1 ? text.truncationMode : .tail
            )
        }
        return lines
    }

    /// The glyphs from `start` to the end of the text, cut around an
    /// ellipsis to fit a width: keeping the start (tail truncation), the end
    /// (head) or both (middle).
    private func truncated(_ shaped: Shaped, from start: Int, width: CGFloat, mode: TruncationMode) -> Line {
        let indices = Array(start..<shaped.scalars.count).filter { shaped.scalars[$0] != "\n" }
        let ellipsisRun = shaped.runs[indices.last ?? start]
        let ellipsis = ellipsisAdvance(shaped, run: ellipsisRun)
        let budget = max(width - ellipsis, 0)
        func prefix(_ budget: CGFloat) -> [Int] {
            var taken: [Int] = [], used: CGFloat = 0
            for index in indices {
                if shaped.scalars[index] == "\n" { break }
                guard used + shaped.advances[index] <= budget + 0.01 else { break }
                used += shaped.advances[index]
                taken.append(index)
            }
            while let last = taken.last, shaped.scalars[last] == " " { taken.removeLast() }
            return taken
        }
        func suffix(_ budget: CGFloat) -> [Int] {
            var taken: [Int] = [], used: CGFloat = 0
            for index in indices.reversed() {
                guard used + shaped.advances[index] <= budget + 0.01 else { break }
                used += shaped.advances[index]
                taken.insert(index, at: 0)
            }
            while let first = taken.first, shaped.scalars[first] == " " { taken.removeFirst() }
            return taken
        }
        let head: [Int], tail: [Int]
        switch mode {
        case .tail:
            (head, tail) = (prefix(budget), [])
        case .head:
            (head, tail) = ([], suffix(budget))
        case .middle:
            let front = prefix(budget / 2)
            let used = front.reduce(0) { $0 + shaped.advances[$1] }
            (head, tail) = (front, suffix(budget - used).filter { !front.contains($0) })
        }
        let pieces = head.map(Piece.glyph) + [.ellipsis(run: ellipsisRun)] + tail.map(Piece.glyph)
        let used = (head + tail).reduce(0) { $0 + shaped.advances[$1] }
        return Line(range: start..<(indices.last.map { $0 + 1 } ?? start), width: used + ellipsis, pieces: pieces)
    }

    /// The width of an ellipsis in a run's font.
    private func ellipsisAdvance(_ shaped: Shaped, run: Int) -> CGFloat {
        let size = run < shaped.sizes.count ? shaped.sizes[run] : 0
        guard let font = shaped.fonts[run] else { return size * 0.8 }
        let glyph = font.glyph(for: "\u{2026}")
        return font.advances(for: [glyph], fontSize: size).first?.width ?? size * 0.8
    }

    // MARK: TextEngine

    package func layout(_ text: ResolvedText, in proposal: ProposedViewSize) -> TextLayout {
        let text = fitted(text, in: proposal)
        let shaped = shape(text)
        guard !shaped.scalars.isEmpty else {
            return TextLayout(size: .zero, firstBaseline: 0, lastBaseline: 0, lines: [])
        }
        let lines = visibleLines(text, shaped, in: proposal)
        let width = lines.map(\.width).max() ?? 0
        return TextLayout(
            size: CGSize(width: width.rounded(.up), height: CGFloat(lines.count) * shaped.pitch - text.lineSpacing),
            firstBaseline: shaped.ascent,
            lastBaseline: CGFloat(lines.count - 1) * shaped.pitch + shaped.ascent,
            lines: lines.map { line in
                guard let pieces = line.pieces else {
                    return String(String.UnicodeScalarView(shaped.scalars[line.range]))
                }
                return pieces.map { piece -> String in
                    switch piece {
                    case let .glyph(index): String(shaped.scalars[index])
                    case .ellipsis: "\u{2026}"
                    }
                }.joined()
            }
        )
    }

    // MARK: Drawing

    /// Draws text in a frame of `size` points, with the context's origin at
    /// the frame's top-leading corner.
    func draw(_ text: ResolvedText, size: CGSize, in context: Silica.CGContext) {
        let text = fitted(text, in: ProposedViewSize(size))
        let shaped = shape(text)
        let lines = visibleLines(text, shaped, in: ProposedViewSize(size))
        for (lineIndex, line) in lines.enumerated() {
            let x: CGFloat = switch text.alignment {
            case .leading: 0
            case .center: (size.width - line.width) / 2
            case .trailing: size.width - line.width
            }
            let baseline = CGFloat(lineIndex) * shaped.pitch + shaped.ascent
            var position = x
            let pieces = line.pieces ?? line.range.map(Piece.glyph)
            func runOf(_ piece: Piece) -> Int {
                switch piece {
                case let .glyph(index): shaped.runs[index]
                case let .ellipsis(run): run
                }
            }
            var pieceIndex = 0
            // Draw each run's glyphs on the line with its font and color.
            while pieceIndex < pieces.count {
                let runIndex = runOf(pieces[pieceIndex])
                let run = text.runs[runIndex]
                let runBaseline = baseline - run.baselineOffset
                let start = position
                var glyphs: [(glyph: CGGlyph, position: CGPoint)] = []
                while pieceIndex < pieces.count, runOf(pieces[pieceIndex]) == runIndex {
                    switch pieces[pieceIndex] {
                    case let .glyph(index):
                        if shaped.scalars[index] != " " {
                            glyphs.append((shaped.glyphs[index], CGPoint(x: position, y: runBaseline)))
                        }
                        position += shaped.advances[index]
                    case .ellipsis:
                        if let font = shaped.fonts[runIndex] {
                            glyphs.append((font.glyph(for: "\u{2026}"), CGPoint(x: position, y: runBaseline)))
                        }
                        position += ellipsisAdvance(shaped, run: runIndex)
                    }
                    pieceIndex += 1
                }
                // Lines under and through the run, without its last
                // character's tracking.
                let end = position - run.tracking
                let thickness = max(1, (run.font.size / 14).rounded())
                if let underline = run.underline {
                    drawLine(underline, from: start, to: end, y: runBaseline + max(thickness, run.font.size * 0.1), thickness: thickness, in: context)
                }
                if let strikethrough = run.strikethrough {
                    drawLine(strikethrough, from: start, to: end, y: runBaseline - run.font.size * 0.3, thickness: thickness, in: context)
                }
                guard let font = shaped.fonts[runIndex], !glyphs.isEmpty else { continue }
                context.setFont(font)
                context.fontSize = run.font.size
                context.setFillColor(
                    red: CGFloat(run.color.red),
                    green: CGFloat(run.color.green),
                    blue: CGFloat(run.color.blue),
                    alpha: CGFloat(run.color.opacity)
                )
                context.draw(glyphs: glyphs)
            }
        }
    }

    /// Strokes an underline or strikethrough.
    private func drawLine(_ line: ResolvedText.Line, from start: CGFloat, to end: CGFloat, y: CGFloat, thickness: CGFloat, in context: Silica.CGContext) {
        guard end > start else { return }
        context.saveGState()
        context.beginPath()
        context.move(to: CGPoint(x: start, y: y))
        context.addLine(to: CGPoint(x: end, y: y))
        context.setStrokeColor(
            red: CGFloat(line.color.red),
            green: CGFloat(line.color.green),
            blue: CGFloat(line.color.blue),
            alpha: CGFloat(line.color.opacity)
        )
        context.lineWidth = thickness
        context.lineCap = .butt
        context.lineDash = (0, line.dashes(thickness: thickness))
        context.strokePath()
        context.restoreGState()
    }
}
