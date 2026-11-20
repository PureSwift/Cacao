//
//  ScrollTargets.swift
//  Cacao
//
//  Created by Alsey Coleman Miller on 11/13/26.
//

import CacaoRender
import Foundation
#if canImport(CoreGraphics)
import CoreGraphics
#endif

// MARK: - Scroll targets

/// A type defining the target in which a scroll view should try and scroll to.
public struct ScrollTarget: Sendable {

    /// The rect that a scrollable view should try and have contained.
    public var rect: CGRect

    /// The anchor to which the rect should be aligned within the visible
    /// region of the scrollable view.
    public var anchor: UnitPoint?

    public init(rect: CGRect, anchor: UnitPoint? = nil) {
        self.rect = rect
        self.anchor = anchor
    }
}

/// The context in which a scroll target behavior updates its scroll target.
public struct ScrollTargetBehaviorContext {

    /// The original target when the scroll gesture began.
    public var originalTarget: ScrollTarget

    /// The current velocity of the scrollable view's scroll gesture, in
    /// points per second.
    public var velocity: CGVector

    /// The size of the content of the scrollable view.
    public var contentSize: CGSize

    /// The size of the container of the scrollable view.
    public var containerSize: CGSize

    /// The axes in which the scrollable view is scrollable.
    public var axes: Axis.Set

    /// The frames of the scroll target layout's views, in the content.
    internal var layoutTargets: [CGRect]
}

/// A type that defines the scroll behavior of a scrollable view.
public protocol ScrollTargetBehavior {

    /// Updates the proposed target that a scrollable view should scroll to.
    func updateTarget(_ target: inout ScrollTarget, context: Self.TargetContext)

    /// The context in which a scroll target behavior updates its scroll target.
    typealias TargetContext = ScrollTargetBehaviorContext
}

/// How far a gesture must move, in points a second, to move a page.
private let pagingVelocity: CGFloat = 100

/// The scroll behavior that aligns scroll targets to container-based geometry.
public struct PagingScrollTargetBehavior: ScrollTargetBehavior {

    public init() { }

    public func updateTarget(_ target: inout ScrollTarget, context: TargetContext) {
        let start = context.originalTarget.rect.origin
        func page(_ axis: Axis, projected: CGFloat, start: CGFloat, velocity: CGFloat) -> CGFloat {
            let size = context.containerSize[axis]
            guard size > 0 else { return projected }
            let current = (start / size).rounded()
            var page: CGFloat
            if abs(velocity) > pagingVelocity {
                page = velocity > 0 ? (start / size).rounded(.down) + 1 : (start / size).rounded(.up) - 1
            } else {
                page = (projected / size).rounded()
            }
            page = min(max(page, current - 1), current + 1)
            let maxOffset = max(context.contentSize[axis] - size, 0)
            return min(max(page * size, 0), maxOffset)
        }
        if context.axes.contains(.horizontal) {
            target.rect.origin.x = page(.horizontal, projected: target.rect.minX, start: start.x, velocity: context.velocity.dx)
        }
        if context.axes.contains(.vertical) {
            target.rect.origin.y = page(.vertical, projected: target.rect.minY, start: start.y, velocity: context.velocity.dy)
        }
        target.anchor = nil
    }
}

/// The scroll behavior that aligns scroll targets to view-based geometry.
public struct ViewAlignedScrollTargetBehavior: ScrollTargetBehavior {

    /// A type that defines the amount of views that can be scrolled at a time.
    public struct LimitBehavior: Sendable, Equatable {

        let isLimited: Bool

        /// The automatic limit behavior.
        public static var automatic: LimitBehavior { LimitBehavior(isLimited: false) }

        /// The always limit behavior: one view at a time.
        public static var always: LimitBehavior { LimitBehavior(isLimited: true) }

        /// The never limit behavior.
        public static var never: LimitBehavior { LimitBehavior(isLimited: false) }

        /// The always limit behavior for compact sizes.
        public static var alwaysByFew: LimitBehavior { LimitBehavior(isLimited: true) }

        /// The always limit behavior for single views.
        public static var alwaysByOne: LimitBehavior { LimitBehavior(isLimited: true) }
    }

    let limitBehavior: LimitBehavior

    public init(limitBehavior: LimitBehavior = .automatic) {
        self.limitBehavior = limitBehavior
    }

    public func updateTarget(_ target: inout ScrollTarget, context: TargetContext) {
        let start = context.originalTarget.rect.origin
        func align(_ axis: Axis, projected: CGFloat, start: CGFloat, velocity: CGFloat) -> CGFloat {
            let edges = context.layoutTargets.map { $0.origin[axis] }.sorted()
            guard !edges.isEmpty else { return projected }
            let maxOffset = max(context.contentSize[axis] - context.containerSize[axis], 0)
            func nearest(to position: CGFloat) -> Int {
                edges.indices.min { abs(edges[$0] - position) < abs(edges[$1] - position) } ?? 0
            }
            let current = nearest(to: start)
            var index = nearest(to: projected)
            if index == current, abs(velocity) > pagingVelocity {
                index += velocity > 0 ? 1 : -1
            }
            if limitBehavior.isLimited {
                index = min(max(index, current - 1), current + 1)
            }
            index = min(max(index, 0), edges.count - 1)
            return min(max(edges[index], 0), maxOffset)
        }
        if context.axes.contains(.horizontal) {
            target.rect.origin.x = align(.horizontal, projected: target.rect.minX, start: start.x, velocity: context.velocity.dx)
        }
        if context.axes.contains(.vertical) {
            target.rect.origin.y = align(.vertical, projected: target.rect.minY, start: start.y, velocity: context.velocity.dy)
        }
        target.anchor = nil
    }
}

extension ScrollTargetBehavior where Self == PagingScrollTargetBehavior {

    /// The scroll behavior that aligns scroll targets to container-based geometry.
    public static var paging: PagingScrollTargetBehavior { PagingScrollTargetBehavior() }
}

extension ScrollTargetBehavior where Self == ViewAlignedScrollTargetBehavior {

    /// The scroll behavior that aligns scroll targets to view-based geometry.
    public static var viewAligned: ViewAlignedScrollTargetBehavior { ViewAlignedScrollTargetBehavior() }

    /// The scroll behavior that aligns scroll targets to view-based geometry.
    public static func viewAligned(limitBehavior: ViewAlignedScrollTargetBehavior.LimitBehavior) -> ViewAlignedScrollTargetBehavior {
        ViewAlignedScrollTargetBehavior(limitBehavior: limitBehavior)
    }
}

private struct ScrollTargetBehaviorKey: EnvironmentKey {
    nonisolated(unsafe) static let defaultValue: (any ScrollTargetBehavior)? = nil
}

extension EnvironmentValues {

    /// How scroll views in the environment settle.
    internal var scrollTargetBehavior: (any ScrollTargetBehavior)? {
        get { self[ScrollTargetBehaviorKey.self] }
        set { self[ScrollTargetBehaviorKey.self] = newValue }
    }
}

extension View {

    /// Sets the scroll behavior of views scrollable in the provided axes.
    public func scrollTargetBehavior(_ behavior: some ScrollTargetBehavior) -> some View {
        environment(\.scrollTargetBehavior, behavior)
    }

    /// Configures the outermost layout as a scroll target layout.
    public func scrollTargetLayout(isEnabled: Bool = true) -> some View {
        modifier(_AttributesModifier { $0.isScrollTargetLayout = isEnabled })
    }
}

// MARK: - Snapping

extension ScrollState {

    /// Where a scroll that would come to rest at `projected`, moving at
    /// `velocity` points a second, settles, if the scroll view snaps.
    package func snappedOffset(projected: CGPoint, from start: CGPoint, velocity: CGSize) -> CGPoint? {
        guard let behavior = targetBehavior else { return nil }
        let context = ScrollTargetBehaviorContext(
            originalTarget: ScrollTarget(rect: CGRect(origin: start, size: viewportSize)),
            velocity: CGVector(dx: velocity.width, dy: velocity.height),
            contentSize: contentSize,
            containerSize: viewportSize,
            axes: axes,
            layoutTargets: targetLayoutFrames()
        )
        var target = ScrollTarget(rect: CGRect(origin: clamped(projected), size: viewportSize))
        behavior.updateTarget(&target, context: context)
        return clamped(target.rect.origin)
    }

    /// The frames of the scroll target layout's views, relative to the
    /// content's origin.
    func targetLayoutFrames() -> [CGRect] {
        targetLayout?() ?? []
    }

    /// The largest distance a gesture may move from its start: a page,
    /// for paging scroll views.
    package var gestureLimit: CGSize? {
        guard targetBehavior is PagingScrollTargetBehavior else { return nil }
        return viewportSize
    }
}

extension ViewNode {

    /// The frames of a scroll target layout's views in a scroll view's
    /// content, relative to the content's origin.
    func scrollTargetFrames(origin: CGPoint) -> [CGRect]? {
        guard let target = firstNode(where: { $0.attributes.isScrollTargetLayout }) else { return nil }
        // The layout under the attribute's transparent wrappers.
        var layout = target
        while layout.behavior == nil, layout.children.count == 1 {
            layout = layout.children[0]
        }
        // Lazy stacks know every row's position, created or not.
        if let lazy = layout.behavior as? LazyStackBehavior {
            let offsets = layout.lazyOffsets
            guard offsets.count == lazy.count + 1 else { return [] }
            return (0..<lazy.count).map { index in
                var frame = CGRect(x: layout.frame.minX - origin.x, y: layout.frame.minY - origin.y, width: layout.frame.width, height: layout.frame.height)
                if lazy.axis == .horizontal {
                    frame.origin.x += offsets[index]
                    frame.size.width = offsets[index + 1] - offsets[index]
                } else {
                    frame.origin.y += offsets[index]
                    frame.size.height = offsets[index + 1] - offsets[index]
                }
                return frame
            }
        }
        return layout.children.map { $0.subtreeFrame.offsetBy(dx: -origin.x, dy: -origin.y) }
    }

    /// The first node in this subtree, depth first, that matches.
    func firstNode(where predicate: (ViewNode) -> Bool) -> ViewNode? {
        if predicate(self) { return self }
        for child in children {
            if let match = child.firstNode(where: predicate) {
                return match
            }
        }
        return nil
    }
}

// MARK: - ScrollViewReader

/// A proxy value that supports programmatic scrolling of the scrollable
/// views within a view hierarchy.
@MainActor
public struct ScrollViewProxy {

    weak var node: ViewNode?

    /// Scans all scroll views contained by the proxy for the first with a
    /// child view with identifier `id`, and then scrolls to that view.
    public func scrollTo<ID: Hashable>(_ id: ID, anchor: UnitPoint? = nil) {
        guard let node, node.isAttached else { return }
        node.graph.scroll(to: AnyHashable(id), in: node, anchor: anchor)
    }
}

/// A view that provides programmatic scrolling, by working with a proxy to
/// scroll to known child views.
public struct ScrollViewReader<Content: View>: View, PrimitiveView {

    /// The view builder that creates the reader's content.
    public var content: (ScrollViewProxy) -> Content

    public init(@ViewBuilder content: @escaping (ScrollViewProxy) -> Content) {
        self.content = content
    }

    public typealias Body = Never

    func resolve(in context: ResolveContext) -> Resolution {
        Resolution(children: [ChildView(key: 0, view: content(ScrollViewProxy(node: context.node)))])
    }
}

extension ViewGraph {

    /// Scrolls the scroll views in a subtree to show the view with an
    /// identity, animated in the current transaction.
    func scroll(to id: AnyHashable, in subtree: ViewNode, anchor: UnitPoint?) {
        guard let found = findScrollTarget(id, in: subtree) else { return }
        let target = found.node
        var frame = found.frame
        var ancestor = target.parent
        let animation = (Transaction.current?.disablesAnimations ?? false) ? nil : Transaction.current?.animation
        while let node = ancestor {
            defer { ancestor = node.parent }
            guard let scroll = node.behavior as? ScrollBehavior else { continue }
            let state = scroll.state(of: node)
            let viewport = state.viewportSize
            // The frame relative to the content's origin.
            let relative = CGRect(x: frame.minX - node.frame.minX, y: frame.minY - node.frame.minY, width: frame.width, height: frame.height)
            var offset = state.offset
            func position(_ axis: Axis, current: CGFloat) -> CGFloat {
                let start = relative.origin[axis], length = relative.size[axis], visible = viewport[axis]
                if let anchor {
                    let unit = axis == .horizontal ? anchor.x : anchor.y
                    return start + length * unit - visible * unit
                }
                // Only as far as needed to show it.
                if start < current { return start }
                if start + length > current + visible { return min(start, start + length - visible) }
                return current
            }
            if state.axes.contains(.horizontal) { offset.x = position(.horizontal, current: offset.x) }
            if state.axes.contains(.vertical) { offset.y = position(.vertical, current: offset.y) }
            offset = state.clamped(offset)
            setScrollOffset(offset, of: state, animation: animation)
            // Outer scroll views show the scroll view itself.
            frame = node.frame
        }
    }

    /// The node or lazy row with an identity in a subtree, and its frame.
    private func findScrollTarget(_ id: AnyHashable, in subtree: ViewNode) -> (node: ViewNode, frame: CGRect)? {
        if let node = subtree.firstNode(where: { $0.key == id && $0 !== subtree }) {
            return (node, node.subtreeFrame)
        }
        // Rows of lazy stacks that aren't created.
        guard let lazy = subtree.firstNode(where: { node in
            guard node.behavior is LazyStackBehavior else { return false }
            let state = LazyStack.state(of: node)
            return state.elementIDs.contains(id) || state.ids.contains(id)
        }), let behavior = lazy.behavior as? LazyStackBehavior else { return nil }
        let state = LazyStack.state(of: lazy)
        let offsets = lazy.lazyOffsets
        guard let index = state.elementIDs.firstIndex(of: id) ?? state.ids.firstIndex(of: id),
              offsets.count == behavior.count + 1 else { return nil }
        var frame = lazy.frame
        if behavior.axis == .horizontal {
            frame.origin.x += offsets[index]
            frame.size.width = offsets[index + 1] - offsets[index]
        } else {
            frame.origin.y += offsets[index]
            frame.size.height = offsets[index + 1] - offsets[index]
        }
        return (lazy, frame)
    }

    /// Moves a scroll view, animated or not.
    func setScrollOffset(_ offset: CGPoint, of state: ScrollState, animation: Animation?) {
        let key = ObjectIdentifier(state)
        guard let animation else {
            scrollAnimations[key] = nil
            state.offset = offset
            return
        }
        let current = scrollAnimations[key].map { CGPoint(components: $0.animation.values(at: time).values) } ?? state.offset
        scrollAnimations[key] = (state, PropertyAnimation(
            from: [Double(current.x), Double(current.y)],
            to: [Double(offset.x), Double(offset.y)],
            animation: animation,
            start: time
        ))
        setNeedsDisplay()
    }

    /// Stops animating a scroll view, as when the user scrolls it.
    package func cancelScrollAnimation(of state: ScrollState) {
        scrollAnimations[ObjectIdentifier(state)] = nil
    }

    /// Moves animated scroll views to the current time.
    func advanceScrollAnimations() {
        for (key, entry) in scrollAnimations {
            let (values, isFinished) = entry.animation.values(at: time)
            entry.state.offset = entry.state.clamped(CGPoint(components: values))
            if isFinished {
                scrollAnimations[key] = nil
            }
        }
    }
}

extension CGPoint {

    init(components: [Double]) {
        self.init(x: components[0], y: components[1])
    }
}
