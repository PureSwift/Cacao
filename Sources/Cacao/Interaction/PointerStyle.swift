//
//  PointerStyle.swift
//  Cacao
//
//  Created by Alsey Coleman Miller on 11/15/26.
//

#if canImport(CoreGraphics)
import CoreGraphics
#endif

/// A style describing the appearance of the pointer over a view.
///
/// Hosts show the system's pointer of the closest kind.
public struct PointerStyle: Hashable, Sendable {

    /// The kinds of system pointers a host shows.
    package enum Kind: Hashable, Sendable {
        case `default`
        case text
        case link
        case grab
        case grabbing
        case crosshair
        case columnResize
        case rowResize
        case diagonalResize
        case antidiagonalResize
        case move
        case zoomIn
        case zoomOut
    }

    package let kind: Kind

    /// The default pointer.
    public static let `default` = PointerStyle(kind: .default)

    /// A pointer for selecting horizontal text.
    public static let horizontalText = PointerStyle(kind: .text)

    /// A pointer for selecting vertical text.
    public static let verticalText = PointerStyle(kind: .text)

    /// A pointer that indicates a link.
    public static let link = PointerStyle(kind: .link)

    /// A pointer that indicates something can be grabbed.
    public static let grabIdle = PointerStyle(kind: .grab)

    /// A pointer that indicates something is grabbed.
    public static let grabActive = PointerStyle(kind: .grabbing)

    /// A pointer for selecting a rectangle.
    public static let rectSelection = PointerStyle(kind: .crosshair)

    /// A pointer for resizing a column.
    public static let columnResize = PointerStyle(kind: .columnResize)

    /// A pointer for resizing a row.
    public static let rowResize = PointerStyle(kind: .rowResize)

    /// A pointer for zooming in.
    public static let zoomIn = PointerStyle(kind: .zoomIn)

    /// A pointer for zooming out.
    public static let zoomOut = PointerStyle(kind: .zoomOut)

    /// A pointer for resizing a column in some directions.
    public static func columnResize(directions: HorizontalDirection.Set) -> PointerStyle {
        .columnResize
    }

    /// A pointer for resizing a row in some directions.
    public static func rowResize(directions: VerticalDirection.Set) -> PointerStyle {
        .rowResize
    }

    /// A pointer for resizing a frame from a position on its edge.
    public static func frameResize(position: FrameResizePosition, directions: FrameResizeDirection.Set = .all) -> PointerStyle {
        switch position {
        case .leading, .trailing: .columnResize
        case .top, .bottom: .rowResize
        case .topLeading, .bottomTrailing: PointerStyle(kind: .diagonalResize)
        case .topTrailing, .bottomLeading: PointerStyle(kind: .antidiagonalResize)
        }
    }
}

/// A horizontal direction.
public enum HorizontalDirection: Hashable, Sendable, CaseIterable {
    case leading
    case trailing

    /// A set of horizontal directions.
    public struct Set: OptionSet, Hashable, Sendable {
        public let rawValue: Int8
        public init(rawValue: Int8) { self.rawValue = rawValue }
        public static let leading = Set(rawValue: 1 << 0)
        public static let trailing = Set(rawValue: 1 << 1)
        public static let all: Set = [.leading, .trailing]
    }
}

/// A vertical direction.
public enum VerticalDirection: Hashable, Sendable, CaseIterable {
    case up
    case down

    /// A set of vertical directions.
    public struct Set: OptionSet, Hashable, Sendable {
        public let rawValue: Int8
        public init(rawValue: Int8) { self.rawValue = rawValue }
        public static let up = Set(rawValue: 1 << 0)
        public static let down = Set(rawValue: 1 << 1)
        public static let all: Set = [.up, .down]
    }
}

/// A position on the edge of a frame that resizes it.
public enum FrameResizePosition: Hashable, Sendable, CaseIterable {
    case top, leading, bottom, trailing
    case topLeading, topTrailing, bottomLeading, bottomTrailing
}

/// The directions a frame resizes in.
public enum FrameResizeDirection: Hashable, Sendable, CaseIterable {
    case inward
    case outward

    /// A set of resize directions.
    public struct Set: OptionSet, Hashable, Sendable {
        public let rawValue: Int8
        public init(rawValue: Int8) { self.rawValue = rawValue }
        public static let inward = Set(rawValue: 1 << 0)
        public static let outward = Set(rawValue: 1 << 1)
        public static let all: Set = [.inward, .outward]
    }
}

extension View {

    /// Sets the pointer style to display when the pointer is over the view.
    public func pointerStyle(_ style: PointerStyle?) -> some View {
        modifier(_AttributesModifier { $0.pointerStyle = style })
    }
}

extension ViewGraph {

    /// The pointer style of the innermost view under `path`'s end that
    /// sets one.
    static func pointerStyle(along path: [ViewNode]) -> PointerStyle? {
        path.reversed().lazy.compactMap(\.attributes.pointerStyle).first
    }
}
