//
//  ScrollPosition.swift
//  Cacao
//
//  Created by Alsey Coleman Miller on 11/15/26.
//

import CacaoRender
import Foundation
#if canImport(CoreGraphics)
import CoreGraphics
#endif

/// A role a scroll view's default anchor plays.
public struct ScrollAnchorRole: Hashable, Sendable {

    private let id: Int

    /// Where the scroll view starts.
    public static let initialOffset = ScrollAnchorRole(id: 0)

    /// Where the scroll view stays when its content or size changes, if it
    /// was there.
    public static let sizeChanges = ScrollAnchorRole(id: 1)

    /// Where content smaller than the scroll view sits.
    public static let alignment = ScrollAnchorRole(id: 2)

    static let all: [ScrollAnchorRole] = [.initialOffset, .sizeChanges, .alignment]
}

/// A binding to the identity of the scroll target view at an anchor of a
/// scroll view.
internal struct ScrollPositionBinding {

    let id: Binding<AnyHashable?>

    let anchor: UnitPoint?
}

private struct ScrollPositionKey: EnvironmentKey {
    static var defaultValue: ScrollPositionBinding? { nil }
}

private struct DefaultScrollAnchorKey: EnvironmentKey {
    static let defaultValue: [ScrollAnchorRole: UnitPoint] = [:]
}

extension EnvironmentValues {

    /// The position binding of the scroll view in this environment.
    internal var scrollPosition: ScrollPositionBinding? {
        get { self[ScrollPositionKey.self] }
        set { self[ScrollPositionKey.self] = newValue }
    }

    /// The default anchors of scroll views in this environment, by role.
    internal var defaultScrollAnchors: [ScrollAnchorRole: UnitPoint] {
        get { self[DefaultScrollAnchorKey.self] }
        set { self[DefaultScrollAnchorKey.self] = newValue }
    }
}

extension View {

    /// Associates a binding to be updated when a scroll view within this
    /// view scrolls: the identity of its scroll target layout's view at the
    /// anchor, and scrolls to the view with the identity it's set to.
    public func scrollPosition<ID: Hashable>(id: Binding<ID?>, anchor: UnitPoint? = nil) -> some View {
        let erased = Binding<AnyHashable?>(
            get: { id.wrappedValue.map(AnyHashable.init) },
            set: { id.wrappedValue = $0?.base as? ID }
        )
        return environment(\.scrollPosition, ScrollPositionBinding(id: erased, anchor: anchor))
    }

    /// Associates an anchor to control which part of the scroll view's
    /// content is visible initially, as its size changes, and where content
    /// smaller than it sits.
    public func defaultScrollAnchor(_ anchor: UnitPoint?) -> some View {
        transformEnvironment(\.defaultScrollAnchors) { anchors in
            for role in ScrollAnchorRole.all {
                anchors[role] = anchor
            }
        }
    }

    /// Associates an anchor with a role of scroll views within this view.
    public func defaultScrollAnchor(_ anchor: UnitPoint?, for role: ScrollAnchorRole) -> some View {
        transformEnvironment(\.defaultScrollAnchors) { $0[role] = anchor }
    }
}

// MARK: - Scroll views

extension ScrollState {

    /// The offset that shows the content's point at `anchor` at the
    /// viewport's.
    func offset(anchoredAt anchor: UnitPoint) -> CGPoint {
        let max = maxOffset
        return CGPoint(x: max.x * anchor.x, y: max.y * anchor.y)
    }
}

extension ViewNode {

    /// The identity of the scroll target layout's view at a point of the
    /// content, or the nearest before it; `origin` is the content's.
    func scrollTarget(at point: CGPoint, origin: CGPoint) -> AnyHashable? {
        guard let target = firstNode(where: { $0.attributes.isScrollTargetLayout }) else { return nil }
        var layout = target
        while layout.behavior == nil, layout.children.count == 1 {
            layout = layout.children[0]
        }
        let local = CGPoint(x: point.x + origin.x - layout.frame.minX, y: point.y + origin.y - layout.frame.minY)
        // Lazy stacks know every row's position, created or not.
        if let lazy = layout.behavior as? LazyStackBehavior {
            let offsets = layout.lazyOffsets
            let ids = LazyStack.state(of: layout).elementIDs
            guard offsets.count == lazy.count + 1, ids.count == lazy.count, lazy.count > 0 else { return nil }
            let position = lazy.axis == .horizontal ? local.x : local.y
            // The last row starting at or before the position.
            var low = 0, high = lazy.count - 1
            while low < high {
                let middle = (low + high + 1) / 2
                if offsets[middle] <= position { low = middle } else { high = middle - 1 }
            }
            return ids[low]
        }
        // Otherwise the layout's views, through ForEach's.
        var views: [ViewNode] = []
        for child in layout.children {
            if child.view is any LazyRowSource {
                views += child.children
            } else {
                views.append(child)
            }
        }
        let absolute = CGPoint(x: point.x + origin.x, y: point.y + origin.y)
        let frames = views.map { ($0.key, $0.subtreeFrame) }
        if let hit = frames.first(where: { $0.1.contains(absolute) }) {
            return hit.0
        }
        // Past the end, the nearest before the point.
        return frames.last { $0.1.minY <= absolute.y && $0.1.minX <= absolute.x }?.0 ?? frames.first?.0
    }
}
