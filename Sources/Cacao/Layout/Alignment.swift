//
//  Alignment.swift
//  Cacao
//
//  Created by Alsey Coleman Miller on 11/13/26.
//

import Foundation
#if canImport(CoreGraphics)
import CoreGraphics
#endif

// MARK: - AlignmentID

/// A type that you use to create custom alignment guides.
public protocol AlignmentID {

    /// The value of the corresponding guide in the given context when not
    /// otherwise set in that context.
    static func defaultValue(in context: ViewDimensions) -> CGFloat

    /// Updates `parentValue` with the `n`th explicit child guide value, as
    /// projected into the parent's coordinate space.
    static func _combineExplicit(childValue: CGFloat, _ n: Int, into parentValue: inout CGFloat?)
}

extension AlignmentID {

    /// The default combines explicit values by taking their mean.
    public static func _combineExplicit(childValue: CGFloat, _ n: Int, into parentValue: inout CGFloat?) {
        let value = (n == 0) ? childValue : parentValue!
        let count = CGFloat(n)
        parentValue = (value * count + childValue) / (count + 1)
    }
}

// MARK: - AlignmentKey

/// The identity of an alignment guide and the axis it applies to.
internal struct AlignmentKey: Hashable, @unchecked Sendable {

    let id: any AlignmentID.Type

    let axis: Axis

    init(id: any AlignmentID.Type, axis: Axis) {
        self.id = id
        self.axis = axis
    }

    static func == (lhs: AlignmentKey, rhs: AlignmentKey) -> Bool {
        ObjectIdentifier(lhs.id) == ObjectIdentifier(rhs.id) && lhs.axis == rhs.axis
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(ObjectIdentifier(id))
        hasher.combine(axis)
    }

    func combineExplicit<S: Sequence>(_ values: S) -> CGFloat? where S.Element == CGFloat? {
        var result: CGFloat?
        var n = 0
        for value in values {
            guard let value else { continue }
            id._combineExplicit(childValue: value, n, into: &result)
            n += 1
        }
        return result
    }
}

// MARK: - HorizontalAlignment

/// An alignment position along the horizontal axis.
public struct HorizontalAlignment: Equatable, Sendable {

    internal let key: AlignmentKey

    /// Creates a custom horizontal alignment of the specified type.
    public init(_ id: any AlignmentID.Type) {
        self.key = AlignmentKey(id: id, axis: .horizontal)
    }

    /// Merges a sequence of explicit alignment values produced by this
    /// instance; for built-in alignments, their mean.
    public func combineExplicit<S: Sequence>(_ values: S) -> CGFloat? where S.Element == CGFloat? {
        key.combineExplicit(values)
    }

    private enum Leading: AlignmentID {
        static func defaultValue(in context: ViewDimensions) -> CGFloat { 0 }
    }

    private enum Center: AlignmentID {
        static func defaultValue(in context: ViewDimensions) -> CGFloat { context.width / 2 }
    }

    private enum Trailing: AlignmentID {
        static func defaultValue(in context: ViewDimensions) -> CGFloat { context.width }
    }

    /// A guide that marks the leading edge of the view.
    public static let leading = HorizontalAlignment(Leading.self)

    /// A guide that marks the horizontal center of the view.
    public static let center = HorizontalAlignment(Center.self)

    /// A guide that marks the trailing edge of the view.
    public static let trailing = HorizontalAlignment(Trailing.self)
}

// MARK: - VerticalAlignment

/// An alignment position along the vertical axis.
public struct VerticalAlignment: Equatable, Sendable {

    internal let key: AlignmentKey

    /// Creates a custom vertical alignment of the specified type.
    public init(_ id: any AlignmentID.Type) {
        self.key = AlignmentKey(id: id, axis: .vertical)
    }

    /// Merges a sequence of explicit alignment values produced by this
    /// instance; for built-in alignments, their mean, except
    /// `firstTextBaseline` (minimum) and `lastTextBaseline` (maximum).
    public func combineExplicit<S: Sequence>(_ values: S) -> CGFloat? where S.Element == CGFloat? {
        key.combineExplicit(values)
    }

    private enum Top: AlignmentID {
        static func defaultValue(in context: ViewDimensions) -> CGFloat { 0 }
    }

    private enum Center: AlignmentID {
        static func defaultValue(in context: ViewDimensions) -> CGFloat { context.height / 2 }
    }

    private enum Bottom: AlignmentID {
        static func defaultValue(in context: ViewDimensions) -> CGFloat { context.height }
    }

    private enum FirstTextBaseline: AlignmentID {
        static func defaultValue(in context: ViewDimensions) -> CGFloat { context.height }
        static func _combineExplicit(childValue: CGFloat, _ n: Int, into parentValue: inout CGFloat?) {
            parentValue = Swift.min(parentValue ?? .infinity, childValue)
        }
    }

    private enum LastTextBaseline: AlignmentID {
        static func defaultValue(in context: ViewDimensions) -> CGFloat { context.height }
        static func _combineExplicit(childValue: CGFloat, _ n: Int, into parentValue: inout CGFloat?) {
            parentValue = Swift.max(parentValue ?? -.infinity, childValue)
        }
    }

    /// A guide that marks the top-most edge of the view.
    public static let top = VerticalAlignment(Top.self)

    /// A guide that marks the vertical center of the view.
    public static let center = VerticalAlignment(Center.self)

    /// A guide that marks the bottom-most edge of the view.
    public static let bottom = VerticalAlignment(Bottom.self)

    /// A guide that marks the top-most text baseline in a view.
    public static let firstTextBaseline = VerticalAlignment(FirstTextBaseline.self)

    /// A guide that marks the bottom-most text baseline in a view.
    public static let lastTextBaseline = VerticalAlignment(LastTextBaseline.self)
}

// MARK: - Alignment

/// An alignment in both axes.
public struct Alignment: Equatable, Sendable {

    public var horizontal: HorizontalAlignment

    public var vertical: VerticalAlignment

    public init(horizontal: HorizontalAlignment, vertical: VerticalAlignment) {
        self.horizontal = horizontal
        self.vertical = vertical
    }

    public static let center = Alignment(horizontal: .center, vertical: .center)

    public static let leading = Alignment(horizontal: .leading, vertical: .center)

    public static let trailing = Alignment(horizontal: .trailing, vertical: .center)

    public static let top = Alignment(horizontal: .center, vertical: .top)

    public static let bottom = Alignment(horizontal: .center, vertical: .bottom)

    public static let topLeading = Alignment(horizontal: .leading, vertical: .top)

    public static let topTrailing = Alignment(horizontal: .trailing, vertical: .top)

    public static let bottomLeading = Alignment(horizontal: .leading, vertical: .bottom)

    public static let bottomTrailing = Alignment(horizontal: .trailing, vertical: .bottom)

    public static let centerFirstTextBaseline = Alignment(horizontal: .center, vertical: .firstTextBaseline)

    public static let centerLastTextBaseline = Alignment(horizontal: .center, vertical: .lastTextBaseline)

    public static let leadingFirstTextBaseline = Alignment(horizontal: .leading, vertical: .firstTextBaseline)

    public static let leadingLastTextBaseline = Alignment(horizontal: .leading, vertical: .lastTextBaseline)

    public static let trailingFirstTextBaseline = Alignment(horizontal: .trailing, vertical: .firstTextBaseline)

    public static let trailingLastTextBaseline = Alignment(horizontal: .trailing, vertical: .lastTextBaseline)
}

// MARK: - TextAlignment

/// An alignment position for text along the horizontal axis.
public enum TextAlignment: Hashable, CaseIterable, Sendable {

    case leading

    case center

    case trailing
}

// MARK: - ViewDimensions

/// A view's size and alignment guides in its own coordinate space.
public struct ViewDimensions: Equatable {

    /// The view's width.
    public var width: CGFloat { size.width }

    /// The view's height.
    public var height: CGFloat { size.height }

    internal let size: CGSize

    internal let explicitGuides: (AlignmentKey) -> CGFloat?

    internal init(size: CGSize, explicitGuides: @escaping (AlignmentKey) -> CGFloat? = { _ in nil }) {
        self.size = size
        self.explicitGuides = explicitGuides
    }

    /// Gets the value of the given horizontal guide.
    public subscript(guide: HorizontalAlignment) -> CGFloat {
        self[guide.key]
    }

    /// Gets the value of the given vertical guide.
    public subscript(guide: VerticalAlignment) -> CGFloat {
        self[guide.key]
    }

    /// Gets the explicit value of the given horizontal alignment guide.
    public subscript(explicit guide: HorizontalAlignment) -> CGFloat? {
        explicitGuides(guide.key)
    }

    /// Gets the explicit value of the given vertical alignment guide.
    public subscript(explicit guide: VerticalAlignment) -> CGFloat? {
        explicitGuides(guide.key)
    }

    internal subscript(key: AlignmentKey) -> CGFloat {
        explicitGuides(key) ?? key.id.defaultValue(in: self)
    }

    internal subscript(explicit key: AlignmentKey) -> CGFloat? {
        explicitGuides(key)
    }

    public static func == (lhs: ViewDimensions, rhs: ViewDimensions) -> Bool {
        lhs.size == rhs.size
    }
}
