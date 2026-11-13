//
//  ProposedViewSize.swift
//  Cacao
//
//  Created by Alsey Coleman Miller on 11/13/26.
//

import Foundation
#if canImport(CoreGraphics)
import CoreGraphics
#endif

/// A proposal for the size of a view.
///
/// A `nil` dimension asks for the view's ideal size along it, `0` for its
/// minimum, and `.infinity` for its maximum.
public struct ProposedViewSize: Hashable, Sendable {

    /// The proposed horizontal size, in points.
    public var width: CGFloat?

    /// The proposed vertical size, in points.
    public var height: CGFloat?

    public init(width: CGFloat?, height: CGFloat?) {
        self.width = width
        self.height = height
    }

    public init(_ size: CGSize) {
        self.init(width: size.width, height: size.height)
    }

    /// A size proposal that contains zero in both dimensions.
    public static let zero = ProposedViewSize(width: 0, height: 0)

    /// The proposed size with both dimensions left unspecified.
    public static let unspecified = ProposedViewSize(width: nil, height: nil)

    /// A size proposal that contains infinity in both dimensions.
    public static let infinity = ProposedViewSize(width: .infinity, height: .infinity)

    /// Creates a new proposed size that replaces unspecified dimensions in
    /// this proposal with the corresponding dimension of the specified size.
    public func replacingUnspecifiedDimensions(
        by size: CGSize = CGSize(width: 10, height: 10)
    ) -> CGSize {
        CGSize(width: width ?? size.width, height: height ?? size.height)
    }

    internal subscript(axis: Axis) -> CGFloat? {
        get { axis == .horizontal ? width : height }
        set {
            if axis == .horizontal { width = newValue } else { height = newValue }
        }
    }

    internal init(_ major: CGFloat?, in axis: Axis, by minor: CGFloat?) {
        self = axis == .horizontal
            ? ProposedViewSize(width: major, height: minor)
            : ProposedViewSize(width: minor, height: major)
    }

    internal func inset(by insets: EdgeInsets) -> ProposedViewSize {
        ProposedViewSize(
            width: width.map { Swift.max($0 - insets.horizontal, 0) },
            height: height.map { Swift.max($0 - insets.vertical, 0) }
        )
    }
}

extension ProposedViewSize: CustomStringConvertible {

    public var description: String {
        func format(_ value: CGFloat?) -> String {
            value.map { "\($0)" } ?? "nil"
        }
        return "(\(format(width)), \(format(height)))"
    }
}
