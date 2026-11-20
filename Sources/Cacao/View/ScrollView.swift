//
//  ScrollView.swift
//  Cacao
//
//  Created by Alsey Coleman Miller on 11/13/26.
//

import CacaoRender
import Foundation
#if canImport(CoreGraphics)
import CoreGraphics
#endif

/// A scrollable view.
///
/// The content is laid out once, unscrolled; scrolling only changes the
/// offset the renderer draws it at, so it never re-evaluates or lays out
/// the content.
public struct ScrollView<Content: View>: View, PrimitiveView {

    /// The scroll view's content.
    public var content: Content

    /// The scrollable axes of the scroll view.
    public var axes: Axis.Set

    /// A value that indicates whether the scroll view displays the scrollable
    /// component of the content offset.
    public var showsIndicators: Bool

    public init(_ axes: Axis.Set = .vertical, showsIndicators: Bool = true, @ViewBuilder content: () -> Content) {
        self.axes = axes
        self.showsIndicators = showsIndicators
        self.content = content()
    }

    public typealias Body = Never

    func resolve(in context: ResolveContext) -> Resolution {
        var environment = context.environment
        environment.stackOrientation = nil
        // The position binding and default anchors apply to this scroll
        // view, not ones in its content.
        environment.scrollPosition = nil
        environment.defaultScrollAnchors = [:]
        let behavior = ScrollBehavior(
            axes: axes,
            showsIndicators: showsIndicators && context.environment.scrollIndicatorVisibility.isVisible,
            fadesIndicators: context.environment.scrollIndicatorVisibility.kind == .automatic,
            isClipDisabled: context.environment.isScrollClipDisabled,
            targetBehavior: context.environment.scrollTargetBehavior,
            isScrollEnabled: context.environment.isScrollEnabled,
            anchors: context.environment.defaultScrollAnchors
        )
        let state = behavior.state(of: context.node)
        state.position = context.environment.scrollPosition
        // A position set from outside scrolls to its view, once laid out.
        if let position = state.position, let id = position.id.wrappedValue, id != state.reportedID {
            state.reportedID = id
            weak let node = context.node
            context.graph.afterLayoutActions.append {
                guard let node, node.isAttached else { return }
                node.graph.scroll(to: id, in: node, anchor: position.anchor ?? UnitPoint(x: 0, y: 0))
            }
        }
        return Resolution(
            behavior: behavior,
            children: [ChildView(key: 0, view: content, environment: environment)]
        )
    }
}

// MARK: - ScrollState

/// The scroll position of a scroll view, and the sizes that bound it.
///
/// It lives in the scroll view's node, outside of view state, so that
/// changing the offset only redraws.
@MainActor
package final class ScrollState {

    package let axes: Axis.Set

    /// The top-leading point of the content that shows at the viewport's
    /// top-leading corner.
    package var offset: CGPoint = CGPoint(x: 0, y: 0) {
        didSet {
            if offset != oldValue {
                onChange?()
            }
        }
    }

    /// The size of the content, from the last layout.
    package internal(set) var contentSize: CGSize = .zero

    /// The size of the visible area, from the last layout.
    package internal(set) var viewportSize: CGSize = .zero

    /// Called when the offset changes.
    var onChange: (() -> Void)?

    /// Whether the indicators fade out after scrolling.
    var fadesIndicators = false

    /// When the offset last changed, for indicators that fade.
    var lastMoved: Double?

    /// How long indicators stay after scrolling stops, before they fade.
    static let indicatorHold = 0.6

    /// How long indicators take to fade out.
    static let indicatorFade = 0.3

    /// How opaque fading indicators are at a time: fully while scrolling
    /// and a moment after, then fading out; hidden before any scrolling.
    func indicatorOpacity(at time: Double) -> Double {
        guard let lastMoved else { return 0 }
        let idle = time - lastMoved - Self.indicatorHold
        return min(max(1 - idle / Self.indicatorFade, 0), 1)
    }

    /// Whether the user can scroll it.
    var isEnabled = true

    /// How the scroll view settles after a scroll.
    var targetBehavior: (any ScrollTargetBehavior)?

    /// The frames of the scroll target layout's views, in the content.
    var targetLayout: (() -> [CGRect])?

    /// The binding to the identity of the view at an anchor.
    var position: ScrollPositionBinding?

    /// The identity last reported to, or scrolled to from, the binding.
    var reportedID: AnyHashable?

    /// Finds the scroll target view at a point of the viewport.
    var target: ((CGPoint) -> AnyHashable?)?

    /// Whether the scroll view has taken its initial anchored position.
    var isPositioned = false

    /// Tells the position binding which view is at its anchor.
    func reportPosition() {
        guard let position, let target else { return }
        let anchor = position.anchor ?? UnitPoint(x: 0, y: 0)
        let point = CGPoint(x: viewportSize.width * anchor.x, y: viewportSize.height * anchor.y)
        guard let id = target(point), id != reportedID else { return }
        reportedID = id
        position.id.wrappedValue = id
    }

    init(axes: Axis.Set) {
        self.axes = axes
    }

    /// The largest offset along each axis.
    package var maxOffset: CGPoint {
        CGPoint(
            x: axes.contains(.horizontal) ? max(contentSize.width - viewportSize.width, 0) : 0,
            y: axes.contains(.vertical) ? max(contentSize.height - viewportSize.height, 0) : 0
        )
    }

    /// An offset limited to the scrollable range.
    package func clamped(_ offset: CGPoint) -> CGPoint {
        let max = maxOffset
        return CGPoint(x: min(Swift.max(offset.x, 0), max.x), y: min(Swift.max(offset.y, 0), max.y))
    }

    /// Whether moving by `delta` would change the clamped offset.
    package func canScroll(by delta: CGSize) -> Bool {
        guard isEnabled else { return false }
        let target = clamped(CGPoint(x: offset.x + delta.width, y: offset.y + delta.height))
        return target != clamped(offset)
    }
}

// MARK: - Behavior

internal struct ScrollBehavior: NodeBehavior {

    let axes: Axis.Set

    let showsIndicators: Bool

    /// Whether the indicators only show while scrolling and a moment
    /// after, as by default, or stay.
    var fadesIndicators = true

    /// Whether content draws outside the scroll view's bounds.
    var isClipDisabled = false

    var targetBehavior: (any ScrollTargetBehavior)? = nil

    var isScrollEnabled = true

    /// The default anchors, by role.
    var anchors: [ScrollAnchorRole: UnitPoint] = [:]

    func state(of node: ViewNode) -> ScrollState {
        if let state = node.dynamicStorage["scroll"] as? ScrollState, state.axes == axes {
            return state
        }
        let state = ScrollState(axes: axes)
        state.onChange = { [weak graph = node.graph, weak state] in
            // Its indicators show from now until a moment after.
            if let graph, let state, state.fadesIndicators {
                state.lastMoved = graph.time
                graph.scrollIndicatorsFadeEnd = graph.time + ScrollState.indicatorHold + ScrollState.indicatorFade
            }
            graph?.setNeedsDisplay()
            graph?.scrollDidChange()
            graph?.scrollVisibilityDidChange()
            state?.reportPosition()
        }
        node.dynamicStorage["scroll"] = state
        return state
    }

    /// Content isn't limited along the scrolling axes.
    private func contentProposal(_ proposal: ProposedViewSize) -> ProposedViewSize {
        ProposedViewSize(
            width: axes.contains(.horizontal) ? nil : proposal.width,
            height: axes.contains(.vertical) ? nil : proposal.height
        )
    }

    func sizeThatFits(_ proposal: ProposedViewSize, node: ViewNode) -> CGSize {
        // A viewport of the proposed size, for content measured relative to it.
        if let width = proposal.width, let height = proposal.height, width.isFinite, height.isFinite {
            ContainerSize.of(node).size = CGSize(width: width, height: height)
        }
        let content = LayoutProxy.combining(node.layoutChildren)?.size(in: contentProposal(proposal)) ?? .zero
        func dimension(_ proposed: CGFloat?, _ content: CGFloat) -> CGFloat {
            guard let proposed, proposed.isFinite else { return content }
            return proposed
        }
        return CGSize(width: dimension(proposal.width, content.width), height: dimension(proposal.height, content.height))
    }

    func placeChildren(in bounds: CGRect, proposal: ProposedViewSize, node: ViewNode) {
        // Content sizes itself relative to the viewport.
        ContainerSize.of(node).size = bounds.size
        let state = state(of: node)
        state.targetBehavior = targetBehavior
        state.isEnabled = isScrollEnabled
        state.fadesIndicators = showsIndicators && fadesIndicators
        if targetBehavior != nil {
            state.targetLayout = { [weak node] in
                guard let node else { return [] }
                return node.scrollTargetFrames(origin: node.frame.origin) ?? []
            }
        }
        guard let content = LayoutProxy.combining(node.layoutChildren) else {
            state.contentSize = .zero
            state.viewportSize = bounds.size
            return
        }
        state.target = { [weak node] point in
            guard let node else { return nil }
            let offset = state.offset
            return node.scrollTarget(at: CGPoint(x: point.x + offset.x, y: point.y + offset.y), origin: node.frame.origin)
        }
        let childProposal = contentProposal(ProposedViewSize(bounds.size))
        let size = content.size(in: childProposal)
        // Content smaller than the viewport is centered on the axes that
        // don't scroll, and starts at the top-leading edge on those that do,
        // unless an alignment anchor says where.
        let alignment = anchors[.alignment]
        func start(_ scrolls: Bool, _ min: CGFloat, _ space: CGFloat, _ unit: CGFloat?) -> CGFloat {
            if scrolls { return min + Swift.max(space, 0) * (unit ?? 0) }
            return min + space / 2
        }
        let origin = CGPoint(
            x: start(axes.contains(.horizontal), bounds.minX, bounds.width - size.width, alignment?.x),
            y: start(axes.contains(.vertical), bounds.minY, bounds.height - size.height, alignment?.y)
        )
        content.place(at: origin, proposal: childProposal)
        // Whether it showed its anchor before the sizes changed.
        let sizeAnchor = anchors[.sizeChanges]
        let wasAtAnchor = sizeAnchor.map { state.offset == state.offset(anchoredAt: $0) } ?? false
        let sizesChanged = state.contentSize != size || state.viewportSize != bounds.size
        state.contentSize = size
        state.viewportSize = bounds.size
        if !state.isPositioned, size != .zero {
            state.isPositioned = true
            if let anchor = anchors[.initialOffset] {
                state.offset = state.offset(anchoredAt: anchor)
            }
        } else if sizesChanged, wasAtAnchor, let anchor = sizeAnchor {
            state.offset = state.offset(anchoredAt: anchor)
        }
        let clamped = state.clamped(state.offset)
        if clamped != state.offset {
            state.offset = clamped
        }
    }

    func displayEffect(node: ViewNode) -> DisplayList.Effect? {
        let state = state(of: node)
        var effect = ScrollEffect(
            viewport: node.frame,
            offset: state.offset,
            showsIndicators: showsIndicators,
            indicatorOpacity: fadesIndicators ? state.indicatorOpacity(at: node.graph.time) : 1,
            contentSize: state.contentSize
        )
        effect.isClipDisabled = isClipDisabled
        return .scroll(effect)
    }
}

// MARK: - Graph

extension ViewGraph {

    /// The scroll state of the innermost scroll view at `point` that can move
    /// by `delta`, or `nil` if none can.
    package func scrollState(at point: CGPoint, delta: CGSize) -> ScrollState? {
        for (node, behavior) in root.scrollViews(at: point).reversed() {
            let state = behavior.state(of: node)
            if state.canScroll(by: delta) {
                return state
            }
        }
        return nil
    }

    /// Scrolls the innermost scroll view at `point` that can move by `delta`.
    ///
    /// Returns whether a scroll view moved.
    @discardableResult
    package func scroll(by delta: CGSize, at point: CGPoint) -> Bool {
        hideTooltip()
        guard let state = scrollState(at: point, delta: delta) else {
            return false
        }
        state.offset = state.clamped(CGPoint(x: state.offset.x + delta.width, y: state.offset.y + delta.height))
        return true
    }
}
