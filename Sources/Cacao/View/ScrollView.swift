//
//  ScrollView.swift
//  Cacao
//
//  Created by Alsey Coleman Miller on 11/13/26.
//

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
        return Resolution(
            behavior: ScrollBehavior(axes: axes, showsIndicators: showsIndicators),
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
        let target = clamped(CGPoint(x: offset.x + delta.width, y: offset.y + delta.height))
        return target != clamped(offset)
    }
}

/// The effect of a scroll view on its content's drawing.
package struct ScrollEffect: Equatable, Sendable {

    /// The visible area, in the root's coordinate space.
    package var viewport: CGRect

    /// How far the content is scrolled.
    package var offset: CGPoint

    /// Whether to draw scroll indicators.
    package var showsIndicators: Bool

    /// The size of the content, for indicators.
    package var contentSize: CGSize
}

// MARK: - Behavior

internal struct ScrollBehavior: NodeBehavior {

    let axes: Axis.Set

    let showsIndicators: Bool

    func state(of node: ViewNode) -> ScrollState {
        if let state = node.dynamicStorage["scroll"] as? ScrollState, state.axes == axes {
            return state
        }
        let state = ScrollState(axes: axes)
        state.onChange = { [weak graph = node.graph] in
            graph?.setNeedsDisplay()
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
        let content = LayoutProxy.combining(node.layoutChildren)?.size(in: contentProposal(proposal)) ?? .zero
        func dimension(_ proposed: CGFloat?, _ content: CGFloat) -> CGFloat {
            guard let proposed, proposed.isFinite else { return content }
            return proposed
        }
        return CGSize(width: dimension(proposal.width, content.width), height: dimension(proposal.height, content.height))
    }

    func placeChildren(in bounds: CGRect, proposal: ProposedViewSize, node: ViewNode) {
        let state = state(of: node)
        guard let content = LayoutProxy.combining(node.layoutChildren) else {
            state.contentSize = .zero
            state.viewportSize = bounds.size
            return
        }
        let childProposal = contentProposal(ProposedViewSize(bounds.size))
        let size = content.size(in: childProposal)
        // Content smaller than the viewport is centered on the axes that
        // don't scroll, and starts at the top-leading edge on those that do.
        let origin = CGPoint(
            x: axes.contains(.horizontal) ? bounds.minX : bounds.minX + (bounds.width - size.width) / 2,
            y: axes.contains(.vertical) ? bounds.minY : bounds.minY + (bounds.height - size.height) / 2
        )
        content.place(at: origin, proposal: childProposal)
        state.contentSize = size
        state.viewportSize = bounds.size
        let clamped = state.clamped(state.offset)
        if clamped != state.offset {
            state.offset = clamped
        }
    }

    func displayEffect(node: ViewNode) -> DisplayList.Effect? {
        let state = state(of: node)
        return .scroll(ScrollEffect(
            viewport: node.frame,
            offset: state.offset,
            showsIndicators: showsIndicators,
            contentSize: state.contentSize
        ))
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
        guard let state = scrollState(at: point, delta: delta) else {
            return false
        }
        state.offset = state.clamped(CGPoint(x: state.offset.x + delta.width, y: state.offset.y + delta.height))
        return true
    }
}
