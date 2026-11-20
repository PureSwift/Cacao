//
//  LayoutModifiers.swift
//  Cacao
//
//  Created by Alsey Coleman Miller on 11/13/26.
//

import CacaoRender
import Foundation
#if canImport(CoreGraphics)
import CoreGraphics
#endif

// MARK: - Unary layout

/// A behavior for a modifier that lays out one child: its content.
@MainActor
internal protocol UnaryLayoutBehavior: NodeBehavior {

    func sizeThatFits(_ proposal: ProposedViewSize, child: LayoutProxy) -> CGSize

    /// The child's proposal and top-leading position within the node's own
    /// coordinate space when the node has `size` for `proposal`.
    func placement(of child: LayoutProxy, size: CGSize, proposal: ProposedViewSize) -> (proposal: ProposedViewSize, origin: CGPoint)

    func spacing(child: LayoutProxy) -> ViewSpacing

    func explicitAlignment(_ key: AlignmentKey, size: CGSize, proposal: ProposedViewSize, child: LayoutProxy) -> CGFloat?
}

extension UnaryLayoutBehavior {

    func sizeThatFits(_ proposal: ProposedViewSize, node: ViewNode) -> CGSize {
        guard let child = LayoutProxy.combining(node.layoutChildren) else {
            return .zero
        }
        return sizeThatFits(proposal, child: child)
    }

    func placeChildren(in bounds: CGRect, proposal: ProposedViewSize, node: ViewNode) {
        guard let child = LayoutProxy.combining(node.layoutChildren) else {
            return
        }
        let placement = placement(of: child, size: bounds.size, proposal: proposal)
        child.place(
            at: CGPoint(x: bounds.minX + placement.origin.x, y: bounds.minY + placement.origin.y),
            proposal: placement.proposal
        )
    }

    func spacing(node: ViewNode) -> ViewSpacing {
        guard let child = LayoutProxy.combining(node.layoutChildren) else {
            return ViewSpacing()
        }
        return spacing(child: child)
    }

    func explicitAlignment(_ key: AlignmentKey, size: CGSize, proposal: ProposedViewSize, node: ViewNode) -> CGFloat? {
        guard let child = LayoutProxy.combining(node.layoutChildren) else {
            return nil
        }
        return explicitAlignment(key, size: size, proposal: proposal, child: child)
    }

    func spacing(child: LayoutProxy) -> ViewSpacing {
        child.spacing
    }

    /// The child's explicit guide, moved into this node's coordinate space.
    func explicitAlignment(_ key: AlignmentKey, size: CGSize, proposal: ProposedViewSize, child: LayoutProxy) -> CGFloat? {
        let placement = placement(of: child, size: size, proposal: proposal)
        let childSize = child.size(in: placement.proposal)
        return child.explicitAlignment(key, size: childSize, proposal: placement.proposal)
            .map { $0 + placement.origin[key.axis] }
    }
}

/// Positions a child of `childSize` within `size` by aligning the child's
/// guides with the default guides of the container.
@MainActor
private func align(_ child: LayoutProxy, proposal: ProposedViewSize, in size: CGSize, alignment: Alignment) -> CGPoint {
    let container = ViewDimensions(size: size)
    let dimensions = child.dimensions(in: proposal)
    return CGPoint(
        x: container[alignment.horizontal] - dimensions[alignment.horizontal],
        y: container[alignment.vertical] - dimensions[alignment.vertical]
    )
}

// MARK: - Padding

internal struct PaddingBehavior: UnaryLayoutBehavior {

    let insets: EdgeInsets

    func sizeThatFits(_ proposal: ProposedViewSize, child: LayoutProxy) -> CGSize {
        let size = child.size(in: proposal.inset(by: insets))
        return CGSize(width: size.width + insets.horizontal, height: size.height + insets.vertical)
    }

    func placement(of child: LayoutProxy, size: CGSize, proposal: ProposedViewSize) -> (proposal: ProposedViewSize, origin: CGPoint) {
        (proposal.inset(by: insets), CGPoint(x: insets.leading, y: insets.top))
    }

    func spacing(child: LayoutProxy) -> ViewSpacing {
        var edges: Edge.Set = []
        if insets.top != 0 { edges.insert(.top) }
        if insets.leading != 0 { edges.insert(.leading) }
        if insets.bottom != 0 { edges.insert(.bottom) }
        if insets.trailing != 0 { edges.insert(.trailing) }
        return child.spacing.resetting(edges)
    }
}

/// The padding a view gets from `padding()` without a length.
internal let defaultPadding: CGFloat = 16

// MARK: - Frame

internal struct FrameBehavior: UnaryLayoutBehavior {

    let width: CGFloat?

    let height: CGFloat?

    let alignment: Alignment

    func sizeThatFits(_ proposal: ProposedViewSize, child: LayoutProxy) -> CGSize {
        if let width, let height {
            return CGSize(width: width, height: height)
        }
        let size = child.size(in: ProposedViewSize(width: width ?? proposal.width, height: height ?? proposal.height))
        return CGSize(width: width ?? size.width, height: height ?? size.height)
    }

    func placement(of child: LayoutProxy, size: CGSize, proposal: ProposedViewSize) -> (proposal: ProposedViewSize, origin: CGPoint) {
        let childProposal = ProposedViewSize(width: width ?? proposal.width, height: height ?? proposal.height)
        return (childProposal, align(child, proposal: childProposal, in: size, alignment: alignment))
    }

    func spacing(child: LayoutProxy) -> ViewSpacing {
        var edges: Edge.Set = []
        if width != nil { edges.formUnion(.horizontal) }
        if height != nil { edges.formUnion(.vertical) }
        return child.spacing.resetting(edges)
    }
}

internal struct FlexFrameBehavior: UnaryLayoutBehavior {

    let minWidth: CGFloat?
    let idealWidth: CGFloat?
    let maxWidth: CGFloat?
    let minHeight: CGFloat?
    let idealHeight: CGFloat?
    let maxHeight: CGFloat?
    let alignment: Alignment

    init(
        minWidth: CGFloat?,
        idealWidth: CGFloat?,
        maxWidth: CGFloat?,
        minHeight: CGFloat?,
        idealHeight: CGFloat?,
        maxHeight: CGFloat?,
        alignment: Alignment
    ) {
        // Normalize as SwiftUI does: min ≤ ideal ≤ max, and none negative.
        let minW = minWidth.map { max($0, 0) }
        let idealW = idealWidth.map { max(minW ?? 0, $0) }
        let maxW = maxWidth.map { max(idealW ?? 0, $0) }
        let minH = minHeight.map { max($0, 0) }
        let idealH = idealHeight.map { max(minH ?? 0, $0) }
        let maxH = maxHeight.map { max(idealH ?? 0, $0) }
        self.minWidth = minW
        self.idealWidth = idealW
        self.maxWidth = maxW
        self.minHeight = minH
        self.idealHeight = idealH
        self.maxHeight = maxH
        self.alignment = alignment
    }

    private func childProposal(_ proposal: ProposedViewSize) -> ProposedViewSize {
        ProposedViewSize(
            width: (proposal.width ?? idealWidth).map { $0.clamped(min: minWidth, max: maxWidth) },
            height: (proposal.height ?? idealHeight).map { $0.clamped(min: minHeight, max: maxHeight) }
        )
    }

    /// A dimension that doesn't depend on the child: the clamped proposal
    /// when both bounds are set, or the ideal length when nothing is proposed.
    private static func fixedLength(proposal: CGFloat?, min: CGFloat?, ideal: CGFloat?, max: CGFloat?) -> CGFloat? {
        if let proposal {
            if let min, let max, min <= max {
                return Swift.min(Swift.max(proposal, min), max)
            }
            return nil
        }
        return ideal
    }

    private static func length(child: CGFloat, childProposal: CGFloat?, min: CGFloat?, max: CGFloat?) -> CGFloat {
        switch (min, max) {
        case let (min?, max?) where min <= max:
            Swift.min(Swift.max(min, child), max)
        case let (min?, nil):
            Swift.max(Swift.min(childProposal ?? .infinity, child), min)
        case let (nil, max?):
            Swift.min(Swift.max(childProposal ?? -.infinity, child), max)
        default:
            child
        }
    }

    func sizeThatFits(_ proposal: ProposedViewSize, child: LayoutProxy) -> CGSize {
        let width = Self.fixedLength(proposal: proposal.width, min: minWidth, ideal: idealWidth, max: maxWidth)
        let height = Self.fixedLength(proposal: proposal.height, min: minHeight, ideal: idealHeight, max: maxHeight)
        if let width, let height {
            return CGSize(width: width, height: height)
        }
        let childProposal = childProposal(proposal)
        let size = child.size(in: childProposal)
        return CGSize(
            width: width ?? Self.length(child: size.width, childProposal: childProposal.width, min: minWidth, max: maxWidth),
            height: height ?? Self.length(child: size.height, childProposal: childProposal.height, min: minHeight, max: maxHeight)
        )
    }

    func placement(of child: LayoutProxy, size: CGSize, proposal: ProposedViewSize) -> (proposal: ProposedViewSize, origin: CGPoint) {
        // Without an ideal, an unspecified proposal strictly within the
        // bounds stays unspecified, so the child keeps its ideal size.
        func dimension(_ axis: Axis, min: CGFloat?, ideal: CGFloat?, max: CGFloat?) -> CGFloat? {
            let value = size[axis]
            if ideal == nil, proposal[axis] == nil, (min ?? -.infinity) < value, value < (max ?? .infinity) {
                return nil
            }
            return value
        }
        let childProposal = ProposedViewSize(
            width: dimension(.horizontal, min: minWidth, ideal: idealWidth, max: maxWidth),
            height: dimension(.vertical, min: minHeight, ideal: idealHeight, max: maxHeight)
        )
        return (childProposal, align(child, proposal: childProposal, in: size, alignment: alignment))
    }

    func spacing(child: LayoutProxy) -> ViewSpacing {
        var edges: Edge.Set = []
        if minWidth != nil || idealWidth != nil || maxWidth != nil { edges.formUnion(.horizontal) }
        if minHeight != nil || idealHeight != nil || maxHeight != nil { edges.formUnion(.vertical) }
        return child.spacing.resetting(edges)
    }
}

// MARK: - Fixed size

internal struct FixedSizeBehavior: UnaryLayoutBehavior {

    let horizontal: Bool

    let vertical: Bool

    private func childProposal(_ proposal: ProposedViewSize) -> ProposedViewSize {
        ProposedViewSize(
            width: horizontal ? nil : proposal.width,
            height: vertical ? nil : proposal.height
        )
    }

    func sizeThatFits(_ proposal: ProposedViewSize, child: LayoutProxy) -> CGSize {
        child.size(in: childProposal(proposal))
    }

    func placement(of child: LayoutProxy, size: CGSize, proposal: ProposedViewSize) -> (proposal: ProposedViewSize, origin: CGPoint) {
        let childProposal = childProposal(proposal)
        return (childProposal, align(child, proposal: childProposal, in: size, alignment: .center))
    }
}

// MARK: - Offset

internal struct OffsetBehavior: UnaryLayoutBehavior {

    let offset: CGSize

    func sizeThatFits(_ proposal: ProposedViewSize, child: LayoutProxy) -> CGSize {
        child.size(in: proposal)
    }

    func placement(of child: LayoutProxy, size: CGSize, proposal: ProposedViewSize) -> (proposal: ProposedViewSize, origin: CGPoint) {
        (proposal, CGPoint(x: offset.width, y: offset.height))
    }

    /// Offsetting moves the drawing, not the view's place in its parent's layout.
    func explicitAlignment(_ key: AlignmentKey, size: CGSize, proposal: ProposedViewSize, child: LayoutProxy) -> CGFloat? {
        child.explicitAlignment(key, size: size, proposal: proposal)
    }
}

// MARK: - Alignment guide

internal struct AlignmentGuideBehavior: UnaryLayoutBehavior {

    let key: AlignmentKey

    let computeValue: (ViewDimensions) -> CGFloat

    func sizeThatFits(_ proposal: ProposedViewSize, child: LayoutProxy) -> CGSize {
        child.size(in: proposal)
    }

    func placement(of child: LayoutProxy, size: CGSize, proposal: ProposedViewSize) -> (proposal: ProposedViewSize, origin: CGPoint) {
        (proposal, CGPoint(x: 0, y: 0))
    }

    func explicitAlignment(_ key: AlignmentKey, size: CGSize, proposal: ProposedViewSize, child: LayoutProxy) -> CGFloat? {
        if key == self.key {
            return computeValue(child.dimensions(in: proposal))
        }
        return child.explicitAlignment(key, size: size, proposal: proposal)
    }
}

// MARK: - Background and overlay

/// Lays out a secondary view, proposed the primary view's size and aligned
/// with it, behind or in front of the primary view.
internal struct SecondaryLayerBehavior: NodeBehavior {

    let alignment: Alignment

    /// Whether the secondary view draws behind the primary view.
    let isBackground: Bool

    func sizeThatFits(_ proposal: ProposedViewSize, node: ViewNode) -> CGSize {
        LayoutProxy.combining(node.layoutChildren(ofChildAt: 0))?.size(in: proposal) ?? .zero
    }

    func placeChildren(in bounds: CGRect, proposal: ProposedViewSize, node: ViewNode) {
        if let primary = LayoutProxy.combining(node.layoutChildren(ofChildAt: 0)) {
            primary.place(at: bounds.origin, proposal: proposal)
        }
        if let secondary = LayoutProxy.combining(node.layoutChildren(ofChildAt: 1)) {
            let childProposal = ProposedViewSize(bounds.size)
            let origin = align(secondary, proposal: childProposal, in: bounds.size, alignment: alignment)
            secondary.place(
                at: CGPoint(x: bounds.minX + origin.x, y: bounds.minY + origin.y),
                proposal: childProposal
            )
        }
    }

    func spacing(node: ViewNode) -> ViewSpacing {
        LayoutProxy.combining(node.layoutChildren(ofChildAt: 0))?.spacing ?? ViewSpacing()
    }

    func explicitAlignment(_ key: AlignmentKey, size: CGSize, proposal: ProposedViewSize, node: ViewNode) -> CGFloat? {
        LayoutProxy.combining(node.layoutChildren(ofChildAt: 0))?.explicitAlignment(key, size: size, proposal: proposal)
    }

    func displayOrder(of children: [ViewNode]) -> [ViewNode] {
        isBackground ? children.reversed() : children
    }
}

// MARK: - Modifiers

/// A built-in modifier whose node lays out its content with a behavior.
@MainActor
internal protocol LayoutModifier: PrimitiveViewModifier {

    var behavior: any NodeBehavior { get }
}

extension LayoutModifier {

    func resolve(content: any View, in context: ResolveContext) -> Resolution {
        Resolution(behavior: behavior, children: [ChildView(key: 0, view: content)])
    }
}

internal struct _PaddingLayout: ViewModifier, LayoutModifier {

    let insets: EdgeInsets

    var behavior: any NodeBehavior { PaddingBehavior(insets: insets) }

    typealias Body = Never
}

internal struct _FrameLayout: ViewModifier, LayoutModifier {

    let width: CGFloat?

    let height: CGFloat?

    let alignment: Alignment

    var behavior: any NodeBehavior { FrameBehavior(width: width, height: height, alignment: alignment) }

    typealias Body = Never
}

internal struct _FlexFrameLayout: ViewModifier, LayoutModifier {

    let behavior: any NodeBehavior

    typealias Body = Never
}

internal struct _FixedSizeLayout: ViewModifier, LayoutModifier {

    let horizontal: Bool

    let vertical: Bool

    var behavior: any NodeBehavior { FixedSizeBehavior(horizontal: horizontal, vertical: vertical) }

    typealias Body = Never
}

internal struct _OffsetEffect: ViewModifier, LayoutModifier {

    let offset: CGSize

    var behavior: any NodeBehavior { OffsetBehavior(offset: offset) }

    typealias Body = Never
}

internal struct _AlignmentWritingModifier: ViewModifier, LayoutModifier {

    let key: AlignmentKey

    let computeValue: (ViewDimensions) -> CGFloat

    var behavior: any NodeBehavior { AlignmentGuideBehavior(key: key, computeValue: computeValue) }

    typealias Body = Never
}

internal struct _TraitWritingModifier: ViewModifier, PrimitiveViewModifier {

    let traits: LayoutTraits

    func resolve(content: any View, in context: ResolveContext) -> Resolution {
        var attributes = NodeAttributes()
        attributes.traits = traits
        return Resolution(children: [ChildView(key: 0, view: content)], attributes: attributes)
    }

    typealias Body = Never
}

internal struct _SecondaryLayerModifier<Secondary: View>: ViewModifier, PrimitiveViewModifier {

    let secondary: Secondary

    let alignment: Alignment

    let isBackground: Bool

    func resolve(content: any View, in context: ResolveContext) -> Resolution {
        Resolution(
            behavior: SecondaryLayerBehavior(alignment: alignment, isBackground: isBackground),
            children: [ChildView(key: 0, view: content), ChildView(key: 1, view: secondary)]
        )
    }

    typealias Body = Never
}

extension View {

    /// Adds an equal padding amount to specific edges of this view.
    public func padding(_ edges: Edge.Set = .all, _ length: CGFloat? = nil) -> some View {
        modifier(_PaddingLayout(insets: EdgeInsets(length ?? defaultPadding, edges: edges)))
    }

    /// Adds different padding amounts to each edge of this view.
    public func padding(_ insets: EdgeInsets) -> some View {
        modifier(_PaddingLayout(insets: insets))
    }

    /// Adds a specific padding amount to each edge of this view.
    public func padding(_ length: CGFloat) -> some View {
        padding(.all, length)
    }

    /// Positions this view within an invisible frame with the specified size.
    public func frame(width: CGFloat? = nil, height: CGFloat? = nil, alignment: Alignment = .center) -> some View {
        modifier(_FrameLayout(width: width, height: height, alignment: alignment))
    }

    /// Positions this view within an invisible frame having the specified
    /// size constraints.
    public func frame(
        minWidth: CGFloat? = nil,
        idealWidth: CGFloat? = nil,
        maxWidth: CGFloat? = nil,
        minHeight: CGFloat? = nil,
        idealHeight: CGFloat? = nil,
        maxHeight: CGFloat? = nil,
        alignment: Alignment = .center
    ) -> some View {
        modifier(_FlexFrameLayout(behavior: FlexFrameBehavior(
            minWidth: minWidth,
            idealWidth: idealWidth,
            maxWidth: maxWidth,
            minHeight: minHeight,
            idealHeight: idealHeight,
            maxHeight: maxHeight,
            alignment: alignment
        )))
    }

    /// Fixes this view at its ideal size in the specified dimensions.
    public func fixedSize(horizontal: Bool, vertical: Bool) -> some View {
        modifier(_FixedSizeLayout(horizontal: horizontal, vertical: vertical))
    }

    /// Fixes this view at its ideal size.
    public func fixedSize() -> some View {
        fixedSize(horizontal: true, vertical: true)
    }

    /// Offset this view by the horizontal and vertical amount specified in
    /// the offset parameter.
    public func offset(_ offset: CGSize) -> some View {
        modifier(_OffsetEffect(offset: offset))
    }

    /// Offset this view by the specified horizontal and vertical distances.
    public func offset(x: CGFloat = 0, y: CGFloat = 0) -> some View {
        offset(CGSize(width: x, height: y))
    }

    /// Sets the priority by which a parent layout should apportion space to
    /// this child.
    public func layoutPriority(_ value: Double) -> some View {
        var traits = LayoutTraits()
        traits[LayoutPriorityKey.self] = value
        return modifier(_TraitWritingModifier(traits: traits))
    }

    /// Associates a value with a custom layout property.
    public func layoutValue<K: LayoutValueKey>(key: K.Type, value: K.Value) -> some View {
        var traits = LayoutTraits()
        traits[key] = value
        return modifier(_TraitWritingModifier(traits: traits))
    }

    /// Sets the view's horizontal alignment.
    public func alignmentGuide(
        _ g: HorizontalAlignment,
        computeValue: @escaping (ViewDimensions) -> CGFloat
    ) -> some View {
        modifier(_AlignmentWritingModifier(key: g.key, computeValue: computeValue))
    }

    /// Sets the view's vertical alignment.
    public func alignmentGuide(
        _ g: VerticalAlignment,
        computeValue: @escaping (ViewDimensions) -> CGFloat
    ) -> some View {
        modifier(_AlignmentWritingModifier(key: g.key, computeValue: computeValue))
    }

    /// Layers the views that you specify behind this view.
    public func background<V: View>(
        alignment: Alignment = .center,
        @ViewBuilder content: () -> V
    ) -> some View {
        modifier(_SecondaryLayerModifier(secondary: content(), alignment: alignment, isBackground: true))
    }

    /// Layers the specified view behind this view.
    public func background<Background: View>(_ background: Background, alignment: Alignment = .center) -> some View {
        modifier(_SecondaryLayerModifier(secondary: background, alignment: alignment, isBackground: true))
    }

    /// Sets the view's background to a style.
    public func background<S: ShapeStyle>(_ style: S) -> some View {
        background { _ShapeStyleView(style: style) }
    }

    /// Layers the views that you specify in front of this view.
    public func overlay<V: View>(
        alignment: Alignment = .center,
        @ViewBuilder content: () -> V
    ) -> some View {
        modifier(_SecondaryLayerModifier(secondary: content(), alignment: alignment, isBackground: false))
    }

    /// Layers a secondary view in front of this view.
    public func overlay<Overlay: View>(_ overlay: Overlay, alignment: Alignment = .center) -> some View {
        modifier(_SecondaryLayerModifier(secondary: overlay, alignment: alignment, isBackground: false))
    }

    /// Layers the specified style in front of this view.
    public func overlay<S: ShapeStyle>(_ style: S) -> some View {
        overlay { _ShapeStyleView(style: style) }
    }
}
