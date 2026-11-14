//
//  Geometry.swift
//  Cacao
//
//  Created by Alsey Coleman Miller on 11/13/26.
//

import Foundation
#if canImport(CoreGraphics)
import CoreGraphics
#endif

// MARK: - Axis

/// The horizontal or vertical dimension in a 2D coordinate system.
public enum Axis: Int8, CaseIterable, Hashable, Sendable {

    case horizontal

    case vertical

    /// An efficient set of axes.
    @frozen
    public struct Set: OptionSet, Hashable, Sendable {

        public let rawValue: Int8

        public init(rawValue: Int8) {
            self.rawValue = rawValue
        }

        public static let horizontal = Set(rawValue: 1 << 0)

        public static let vertical = Set(rawValue: 1 << 1)
    }

    internal var other: Axis {
        self == .horizontal ? .vertical : .horizontal
    }
}

extension Axis: CustomStringConvertible {

    public var description: String {
        switch self {
        case .horizontal: "horizontal"
        case .vertical: "vertical"
        }
    }
}

// MARK: - Edge

/// An enumeration to indicate one edge of a rectangle.
public enum Edge: Int8, CaseIterable, Hashable, Sendable {

    case top

    case leading

    case bottom

    case trailing

    /// An efficient set of edges.
    @frozen
    public struct Set: OptionSet, Hashable, Sendable {

        public let rawValue: Int8

        public init(rawValue: Int8) {
            self.rawValue = rawValue
        }

        public init(_ e: Edge) {
            self.init(rawValue: 1 << e.rawValue)
        }

        public static let top = Set(.top)

        public static let leading = Set(.leading)

        public static let bottom = Set(.bottom)

        public static let trailing = Set(.trailing)

        public static let all: Set = [.top, .leading, .bottom, .trailing]

        public static let horizontal: Set = [.leading, .trailing]

        public static let vertical: Set = [.top, .bottom]
    }
}

// MARK: - EdgeInsets

/// The inset distances for the sides of a rectangle.
public struct EdgeInsets: Equatable, Hashable, Sendable {

    public var top: CGFloat

    public var leading: CGFloat

    public var bottom: CGFloat

    public var trailing: CGFloat

    public init(top: CGFloat, leading: CGFloat, bottom: CGFloat, trailing: CGFloat) {
        self.top = top
        self.leading = leading
        self.bottom = bottom
        self.trailing = trailing
    }

    public init() {
        self.init(top: 0, leading: 0, bottom: 0, trailing: 0)
    }

    internal init(_ length: CGFloat, edges: Edge.Set) {
        self.init(
            top: edges.contains(.top) ? length : 0,
            leading: edges.contains(.leading) ? length : 0,
            bottom: edges.contains(.bottom) ? length : 0,
            trailing: edges.contains(.trailing) ? length : 0
        )
    }

    internal func `in`(_ edges: Edge.Set) -> EdgeInsets {
        EdgeInsets(
            top: edges.contains(.top) ? top : 0,
            leading: edges.contains(.leading) ? leading : 0,
            bottom: edges.contains(.bottom) ? bottom : 0,
            trailing: edges.contains(.trailing) ? trailing : 0
        )
    }

    internal var horizontal: CGFloat { leading + trailing }

    internal var vertical: CGFloat { top + bottom }
}

// MARK: - UnitPoint

/// A normalized 2D point in a view's coordinate space.
public struct UnitPoint: Hashable, Sendable {

    public var x: CGFloat

    public var y: CGFloat

    public init() {
        self.init(x: 0, y: 0)
    }

    public init(x: CGFloat, y: CGFloat) {
        self.x = x
        self.y = y
    }

    public static let zero = UnitPoint(x: 0, y: 0)

    public static let center = UnitPoint(x: 0.5, y: 0.5)

    public static let leading = UnitPoint(x: 0, y: 0.5)

    public static let trailing = UnitPoint(x: 1, y: 0.5)

    public static let top = UnitPoint(x: 0.5, y: 0)

    public static let bottom = UnitPoint(x: 0.5, y: 1)

    public static let topLeading = UnitPoint(x: 0, y: 0)

    public static let topTrailing = UnitPoint(x: 1, y: 0)

    public static let bottomLeading = UnitPoint(x: 0, y: 1)

    public static let bottomTrailing = UnitPoint(x: 1, y: 1)
}

// MARK: - LayoutDirection

/// A direction in which SwiftUI can lay out content.
public enum LayoutDirection: Hashable, CaseIterable, Sendable {

    case leftToRight

    case rightToLeft
}

// MARK: - Internal helpers

extension CGSize {

    internal subscript(axis: Axis) -> CGFloat {
        get { axis == .horizontal ? width : height }
        set {
            if axis == .horizontal { width = newValue } else { height = newValue }
        }
    }

    internal init(_ major: CGFloat, in axis: Axis, by minor: CGFloat) {
        self = axis == .horizontal
            ? CGSize(width: major, height: minor)
            : CGSize(width: minor, height: major)
    }
}

extension CGPoint {

    internal subscript(axis: Axis) -> CGFloat {
        get { axis == .horizontal ? x : y }
        set {
            if axis == .horizontal { x = newValue } else { y = newValue }
        }
    }

    internal init(_ major: CGFloat, in axis: Axis, by minor: CGFloat) {
        self = axis == .horizontal
            ? CGPoint(x: major, y: minor)
            : CGPoint(x: minor, y: major)
    }
}

extension CGFloat {

    internal func clamped(min lower: CGFloat?, max upper: CGFloat?) -> CGFloat {
        Swift.min(Swift.max(self, lower ?? -.infinity), upper ?? .infinity)
    }
}

#if !canImport(CoreGraphics)
/// A structure that contains a two-dimensional vector, where Foundation
/// doesn't provide one.
public struct CGVector: Hashable, Sendable {

    public var dx: CGFloat

    public var dy: CGFloat

    public init() {
        self.dx = 0
        self.dy = 0
    }

    public init(dx: CGFloat, dy: CGFloat) {
        self.dx = dx
        self.dy = dy
    }

    public init(dx: Double, dy: Double) {
        self.init(dx: CGFloat(dx), dy: CGFloat(dy))
    }

    public static var zero: CGVector { CGVector() }
}
#endif
