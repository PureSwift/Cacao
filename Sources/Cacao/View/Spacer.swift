//
//  Spacer.swift
//  Cacao
//
//  Created by Alsey Coleman Miller on 11/13/26.
//

import Foundation
#if canImport(CoreGraphics)
import CoreGraphics
#endif

/// A flexible space that expands along the major axis of its containing
/// stack layout, or on both axes if not contained in a stack.
public struct Spacer: View, PrimitiveView {

    /// The minimum length this spacer can be shrunk to, along the axis or
    /// axes of expansion.
    public var minLength: CGFloat?

    public init(minLength: CGFloat? = nil) {
        self.minLength = minLength
    }

    public typealias Body = Never

    func resolve(in context: ResolveContext) -> Resolution {
        Resolution(behavior: SpacerBehavior(minLength: minLength, axis: context.environment.stackOrientation))
    }
}

internal struct SpacerBehavior: NodeBehavior {

    let minLength: CGFloat?

    /// The axis of the enclosing stack, or `nil` to expand on both axes.
    let axis: Axis?

    func sizeThatFits(_ proposal: ProposedViewSize, node: ViewNode) -> CGSize {
        let length = minLength ?? defaultSpacing
        func expand(_ value: CGFloat?) -> CGFloat {
            max(value ?? -.infinity, length)
        }
        return switch axis {
        case .horizontal: CGSize(width: expand(proposal.width), height: 0)
        case .vertical: CGSize(width: 0, height: expand(proposal.height))
        case nil: CGSize(width: expand(proposal.width), height: expand(proposal.height))
        }
    }

    func spacing(node: ViewNode) -> ViewSpacing {
        switch axis {
        case let axis?: .zero(along: axis)
        case nil: .zero
        }
    }
}

/// A visual element that can be used to separate other content.
///
/// In a stack it's a line across the stack's axis; elsewhere a horizontal line.
public struct Divider: View, PrimitiveView {

    /// The line's color, if not the separator color: a list row's tint.
    internal var tint: Color?

    public init() { }

    internal init(tint: Color?) {
        self.tint = tint
    }

    public typealias Body = Never

    func resolve(in context: ResolveContext) -> Resolution {
        Resolution(behavior: DividerBehavior(
            axis: context.environment.stackOrientation == .horizontal ? .vertical : .horizontal,
            color: (tint ?? Color.separator).resolve(in: context.environment)
        ))
    }
}

internal struct DividerBehavior: NodeBehavior {

    /// The direction the line runs in.
    let axis: Axis

    let color: Color.Resolved

    static let thickness: CGFloat = 1

    func sizeThatFits(_ proposal: ProposedViewSize, node: ViewNode) -> CGSize {
        switch axis {
        case .horizontal: CGSize(width: proposal.width ?? 0, height: Self.thickness)
        case .vertical: CGSize(width: Self.thickness, height: proposal.height ?? 0)
        }
    }

    func displayContent(node: ViewNode) -> DisplayList.Content? {
        .color(color)
    }
}
