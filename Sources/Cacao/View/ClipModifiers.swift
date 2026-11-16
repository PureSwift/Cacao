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

    /// Whether the path fills by the even-odd rule.
    package var isEOFilled = false

    /// The clip as a mask: the path filled in white.
    package var mask: DisplayList.Content {
        .shape(ShapeContent(
            path: path,
            color: Color.Resolved(red: 1, green: 1, blue: 1),
            drawing: .fill(FillStyle(eoFill: isEOFilled))
        ))
    }
}

internal struct ClipBehavior: UnaryLayoutBehavior {

    /// The clip shape for a frame size.
    let shape: (CGRect) -> Path

    let isRectangle: Bool

    var isEOFilled = false

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
        .clip(ClipEffect(path: path(node: node), isRectangle: isRectangle, isEOFilled: isEOFilled))
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

    var isEOFilled = false

    var behavior: any NodeBehavior { ClipBehavior(shape: shape, isRectangle: isRectangle, isEOFilled: isEOFilled) }

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
        modifier(_ClipEffect(shape: { shape.path(in: $0) }, isRectangle: shape is Rectangle, isEOFilled: style.isEOFilled))
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

// MARK: - Masks

/// Lays out a mask over its content, like an overlay, and draws the content
/// only as much as the mask is opaque. The mask isn't hit tested.
internal struct MaskBehavior: NodeBehavior {

    let layer: SecondaryLayerBehavior

    func sizeThatFits(_ proposal: ProposedViewSize, node: ViewNode) -> CGSize {
        layer.sizeThatFits(proposal, node: node)
    }

    func placeChildren(in bounds: CGRect, proposal: ProposedViewSize, node: ViewNode) {
        layer.placeChildren(in: bounds, proposal: proposal, node: node)
    }

    func spacing(node: ViewNode) -> ViewSpacing {
        layer.spacing(node: node)
    }

    func explicitAlignment(_ key: AlignmentKey, size: CGSize, proposal: ProposedViewSize, node: ViewNode) -> CGFloat? {
        layer.explicitAlignment(key, size: size, proposal: proposal, node: node)
    }

    /// Only the content shows as a child; the mask's drawing goes into the
    /// effect.
    func displayOrder(of children: [ViewNode]) -> [ViewNode] {
        Array(children.prefix(1))
    }

    func displayEffect(node: ViewNode) -> DisplayList.Effect? {
        let mask = node.children.count > 1 ? node.children[1].displayItems() : []
        return .mask(DisplayList(items: mask))
    }
}

internal struct _MaskModifier<Mask: View>: ViewModifier, PrimitiveViewModifier {

    let mask: Mask

    let alignment: Alignment

    func resolve(content: any View, in context: ResolveContext) -> Resolution {
        Resolution(
            behavior: MaskBehavior(layer: SecondaryLayerBehavior(alignment: alignment, isBackground: false)),
            children: [ChildView(key: 0, view: content), ChildView(key: 1, view: mask)]
        )
    }

    typealias Body = Never
}

extension View {

    /// Masks this view using the alpha channel of the given view.
    public func mask<Mask: View>(alignment: Alignment = .center, @ViewBuilder _ mask: () -> Mask) -> some View {
        modifier(_MaskModifier(mask: mask(), alignment: alignment))
    }

    /// Masks this view using the alpha channel of the given view.
    @available(*, deprecated, message: "Use mask(alignment:_:) instead.")
    public func mask<Mask: View>(_ mask: Mask) -> some View {
        modifier(_MaskModifier(mask: mask, alignment: .center))
    }
}
