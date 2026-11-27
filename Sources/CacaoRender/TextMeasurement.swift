import Foundation
#if canImport(CoreGraphics)
import CoreGraphics
#endif

/// Measures insertion positions using the engine that draws a host's text.
@MainActor
public protocol TextMeasurementService {
    /// Uses the same proposal (in points) as the text's drawing rectangle.
    func measure(_ text: ResolvedText, in proposal: ProposedViewSize) -> TextMeasurement
}

/// Text geometry in points, relative to the drawing rectangle's top-left.
///
/// Offsets count Unicode scalars in `ResolvedText.string`, from zero through
/// `string.unicodeScalars.count`; they are neither UTF-8/UTF-16 nor grapheme
/// offsets. Convert legacy byte offsets by decoding the prefix in its source
/// encoding and counting its Unicode scalars. Do not normalize the string
/// between conversion, measurement and drawing. This mirrors Cacao's current
/// scalar-based renderer; it does not provide bidirectional or cluster shaping.
public struct TextMeasurement: Equatable, Sendable {
    public let lines: [Line]

    public init(lines: [Line]) {
        self.lines = lines
    }

    public struct Boundary: Equatable, Sendable {
        public let offset: Int
        public let x: CGFloat

        public init(offset: Int, x: CGFloat) {
            self.offset = offset
            self.x = x
        }
    }

    public struct Line: Equatable, Sendable {
        /// Includes the visible glyph width; trailing spaces may extend beyond it.
        public let frame: CGRect
        /// Baseline y coordinate relative to the text rectangle.
        public let baseline: CGFloat
        /// Visible insertion positions, ordered by drawing order. Hidden text
        /// has no positions. An ellipsis bridges its adjacent source offsets.
        public let boundaries: [Boundary]

        public init(frame: CGRect, baseline: CGFloat, boundaries: [Boundary]) {
            self.frame = frame
            self.baseline = baseline
            self.boundaries = boundaries
        }

        /// Returns nil for an offset not represented on this line.
        public func xPosition(for offset: Int) -> CGFloat? {
            boundaries.first { $0.offset == offset }?.x
        }
    }

    /// At a soft wrap an offset can occur on both lines; the later line wins.
    /// Offsets hidden by truncation, or outside the source, return nil.
    public func caretRect(for offset: Int) -> CGRect? {
        for line in lines.reversed() {
            if let x = line.xPosition(for: offset) {
                return CGRect(x: x, y: line.frame.minY, width: 0, height: line.frame.height)
            }
        }
        return nil
    }

    /// Finds the nearest line vertically, then nearest insertion x on it.
    /// Outside points clamp to visible positions. Ties choose the earlier
    /// line/boundary. Newline and discarded wrap spaces map to line ends.
    public func offset(nearest point: CGPoint) -> Int? {
        func distance(_ line: Line) -> CGFloat {
            max(line.frame.minY - point.y, point.y - line.frame.maxY, 0)
        }
        guard let line = lines.enumerated().min(by: {
            let a = distance($0.element), b = distance($1.element)
            return a == b ? $0.offset < $1.offset : a < b
        })?.element else { return nil }
        return line.boundaries.enumerated().min(by: {
            let a = abs($0.element.x - point.x), b = abs($1.element.x - point.x)
            return a == b ? $0.offset < $1.offset : a < b
        })?.element.offset
    }
}
