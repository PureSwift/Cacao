//
//  ClipModifiers.swift
//  Cacao
//
//  Created by Alsey Coleman Miller on 11/13/26.
//

import Foundation
#if canImport(CoreGraphics)
import CoreGraphics
#endif

/// Clipping of a subtree's drawing to a shape.
package struct ClipEffect: Equatable, Sendable {

    /// The clip, in the frame's coordinate space.
    package var path: Path

    /// Whether the clip is the whole frame, which a renderer can apply
    /// without an offscreen layer.
    package var isRectangle: Bool
}

internal struct ClipBehavior: UnaryLayoutBehavior {

    /// The clip shape for a frame size.
    let shape: (CGRect) -> Path

    let isRectangle: Bool

    func sizeThatFits(_ proposal: ProposedViewSize, child: LayoutProxy) -> CGSize {
        child.size(in: proposal)
    }

    func placement(of child: LayoutProxy, size: CGSize, proposal: ProposedViewSize) -> (proposal: ProposedViewSize, origin: CGPoint) {
        (proposal, CGPoint(x: 0, y: 0))
    }

    func path(node: ViewNode) -> Path {
        shape(CGRect(origin: CGPoint(x: 0, y: 0), size: node.frame.size))
    }

    func displayEffect(node: ViewNode) -> DisplayList.Effect? {
        .clip(ClipEffect(path: path(node: node), isRectangle: isRectangle))
    }
}

/// Draws its subtree as one group: flattened before any opacity applies.
internal struct CompositingGroupBehavior: UnaryLayoutBehavior {

    func sizeThatFits(_ proposal: ProposedViewSize, child: LayoutProxy) -> CGSize {
        child.size(in: proposal)
    }

    func placement(of child: LayoutProxy, size: CGSize, proposal: ProposedViewSize) -> (proposal: ProposedViewSize, origin: CGPoint) {
        (proposal, CGPoint(x: 0, y: 0))
    }

    func displayEffect(node: ViewNode) -> DisplayList.Effect? {
        .compositingGroup
    }
}

internal struct _ClipEffect: ViewModifier, LayoutModifier {

    let shape: @MainActor (CGRect) -> Path

    let isRectangle: Bool

    var behavior: any NodeBehavior { ClipBehavior(shape: shape, isRectangle: isRectangle) }

    typealias Body = Never
}

internal struct _CompositingGroupEffect: ViewModifier, LayoutModifier {

    var behavior: any NodeBehavior { CompositingGroupBehavior() }

    typealias Body = Never
}

extension View {

    /// Clips this view to its bounding rectangular frame.
    public func clipped(antialiased: Bool = false) -> some View {
        modifier(_ClipEffect(shape: { Path($0) }, isRectangle: true))
    }

    /// Sets a clipping shape for this view.
    public func clipShape<S: Shape>(_ shape: S, style: FillStyle = FillStyle()) -> some View {
        modifier(_ClipEffect(shape: { shape.path(in: $0) }, isRectangle: shape is Rectangle))
    }

    /// Clips this view to its bounding frame, with the specified corner radius.
    public func cornerRadius(_ radius: CGFloat, antialiased: Bool = true) -> some View {
        clipShape(RoundedRectangle(cornerRadius: radius, style: .circular))
    }

    /// Wraps this view in a compositing group.
    public func compositingGroup() -> some View {
        modifier(_CompositingGroupEffect())
    }

    /// Composites this view's contents into an offscreen image before final
    /// display.
    public func drawingGroup(opaque: Bool = false) -> some View {
        compositingGroup()
    }
}
