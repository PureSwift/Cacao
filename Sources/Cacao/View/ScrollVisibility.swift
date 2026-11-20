//
//  ScrollVisibility.swift
//  Cacao
//
//  Created by Alsey Coleman Miller on 11/20/26.
//

import CacaoRender
import Foundation
#if canImport(CoreGraphics)
import CoreGraphics
#endif

extension View {

    /// Adds an action to be called when the view crosses the threshold to be
    /// considered on or off screen.
    ///
    /// `threshold` is the fraction of the view, from 0 to 1, that has to
    /// show in the scroll view around it for it to count as visible.
    public func onScrollVisibilityChange(threshold: Double = 0.5, _ action: @escaping (Bool) -> Void) -> some View {
        modifier(_ScrollVisibilityModifier(threshold: threshold, action: action))
    }
}

/// Tells an action when enough of its content shows in the scroll view
/// around it, and when it no longer does: after layouts and as it scrolls.
internal struct _ScrollVisibilityModifier: ViewModifier, PrimitiveViewModifier {

    let threshold: Double

    let action: (Bool) -> Void

    func resolve(content: any View, in context: ResolveContext) -> Resolution {
        let node = context.node
        let threshold = self.threshold, action = self.action
        let check = { [weak node] in
            guard let node, node.isAttached, let fraction = node.fractionVisibleInScrollView else { return }
            let isVisible = fraction >= threshold
            guard (node.dynamicStorage["scrollVisibility"] as? StorageBox<Bool>)?.value != isVisible else { return }
            node.dynamicStorage["scrollVisibility"] = StorageBox(isVisible)
            action(isVisible)
        }
        context.graph.scrollVisibilityObservers[node.id] = (WeakNodeReference(node), check)
        context.graph.afterLayout(check)
        return Resolution(children: [ChildView(key: 0, view: content)])
    }

    typealias Body = Never
}

extension ViewGraph {

    /// Runs the checks of views that watch how much of them shows, after a
    /// scroll view moved.
    func scrollVisibilityDidChange() {
        guard !scrollVisibilityObservers.isEmpty else { return }
        scrollVisibilityObservers = scrollVisibilityObservers.filter { $0.value.node.node?.isAttached == true }
        for observer in scrollVisibilityObservers.values {
            observer.check()
        }
    }
}

extension ViewNode {

    /// How much of the view shows in the nearest scroll view around it,
    /// from 0 to 1: all of it outside a scroll view, and `nil` before it's
    /// laid out.
    var fractionVisibleInScrollView: Double? {
        let frame = windowFrame
        guard !frame.isNull, frame.width > 0, frame.height > 0 else { return nil }
        var ancestor = parent
        while let node = ancestor {
            if node.behavior is ScrollBehavior {
                // Where the scroll view is, as scroll views around it show it.
                var viewport = node.frame
                var outer = node.parent
                while let container = outer {
                    if let scroll = container.behavior as? ScrollBehavior {
                        let offset = scroll.state(of: container).offset
                        viewport = viewport.offsetBy(dx: -offset.x, dy: -offset.y)
                    }
                    outer = container.parent
                }
                let shown = frame.intersection(viewport)
                guard !shown.isNull else { return 0 }
                return Double(shown.width * shown.height) / Double(frame.width * frame.height)
            }
            ancestor = node.parent
        }
        return 1
    }
}
