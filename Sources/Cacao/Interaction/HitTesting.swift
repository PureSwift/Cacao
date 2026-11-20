//
//  HitTesting.swift
//  Cacao
//
//  Created by Alsey Coleman Miller on 11/13/26.
//

import CacaoRender
import Foundation
#if canImport(CoreGraphics)
import CoreGraphics
#endif

// MARK: - Gestures

/// A tap recognized on a node's views.
internal struct TapHandler {

    /// Called when a press starts, and when it moves in or out of the views.
    var onPressChanged: (@MainActor (Bool) -> Void)?

    /// Called when a press ends on the views.
    var action: @MainActor () -> Void
}

internal struct _TapGestureModifier: ViewModifier, PrimitiveViewModifier {

    let handler: TapHandler

    func resolve(content: any View, in context: ResolveContext) -> Resolution {
        var attributes = NodeAttributes()
        if context.environment.isEnabled {
            attributes.tap = handler
        } else {
            attributes.disabledTap = handler
        }
        return Resolution(children: [ChildView(key: 0, view: content)], attributes: attributes)
    }

    typealias Body = Never
}

internal struct _ContentShapeModifier<S: Shape>: ViewModifier, PrimitiveViewModifier {

    let shape: S

    func resolve(content: any View, in context: ResolveContext) -> Resolution {
        var attributes = NodeAttributes()
        let shape = self.shape
        attributes.contentShape = { rect in shape.path(in: rect) }
        return Resolution(children: [ChildView(key: 0, view: content)], attributes: attributes)
    }

    typealias Body = Never
}

extension View {

    /// Defines the content shape for hit testing.
    public func contentShape<S: Shape>(_ shape: S, eoFill: Bool = false) -> some View {
        modifier(_ContentShapeModifier(shape: shape))
    }

    /// Configures whether this view participates in hit test operations.
    public func allowsHitTesting(_ enabled: Bool) -> some View {
        modifier(_AttributesModifier { $0.allowsHitTesting = enabled })
    }
}

// MARK: - Hit testing

/// The phases of a pointer press.
package enum PointerPhase: Sendable {
    case began
    case moved
    case ended
    case cancelled
}

extension ViewNode {

    /// The union of the frames of the outermost units in this subtree.
    var subtreeFrame: CGRect {
        let frames = topLevelUnits.map(\.frame)
        return frames.dropFirst().reduce(frames.first ?? .null) { $0.union($1) }
    }

    /// The path from this node to the front-most node that takes a hit at
    /// `point`, or `nil` if none does.
    func hitTest(_ point: CGPoint) -> [ViewNode]? {
        guard attributes.allowsHitTesting, behavior?.allowsHitTesting(node: self) ?? true else {
            return nil
        }
        var childPoint = point
        if let clip = behavior as? ClipBehavior {
            let local = CGPoint(x: point.x - frame.minX, y: point.y - frame.minY)
            guard clip.path(node: self).contains(local) else { return nil }
        }
        if let scroll = behavior as? ScrollBehavior {
            guard frame.contains(point) else { return nil }
            let offset = scroll.state(of: self).offset
            childPoint = CGPoint(x: point.x + offset.x, y: point.y + offset.y)
        }
        for child in orderedChildren.reversed() {
            if let path = child.hitTest(childPoint) {
                return [self] + path
            }
        }
        if let contentShape = attributes.contentShape {
            let frame = subtreeFrame
            let local = CGPoint(x: point.x - frame.minX, y: point.y - frame.minY)
            if contentShape(CGRect(origin: CGPoint(x: 0, y: 0), size: frame.size)).contains(local) {
                return [self]
            }
        }
        if behavior?.hitTest(point, node: self) == true {
            return [self]
        }
        return nil
    }

    /// The scroll views containing `point`, outermost first.
    func scrollViews(at point: CGPoint) -> [(node: ViewNode, behavior: ScrollBehavior)] {
        var result: [(ViewNode, ScrollBehavior)] = []
        var childPoint = point
        if let scroll = behavior as? ScrollBehavior {
            guard frame.contains(point) else { return [] }
            result.append((self, scroll))
            let offset = scroll.state(of: self).offset
            childPoint = CGPoint(x: point.x + offset.x, y: point.y + offset.y)
        }
        for child in children {
            result.append(contentsOf: child.scrollViews(at: childPoint))
        }
        return result
    }
}

extension NodeBehavior {

    /// Whether the node's drawing takes hits at `point`: by default, if it
    /// draws content and `point` is within its frame.
    func hitTest(_ point: CGPoint, node: ViewNode) -> Bool {
        displayContent(node: node) != nil && node.frame.contains(point)
    }

    /// Whether the node and its subtree take hits at all.
    func allowsHitTesting(node: ViewNode) -> Bool {
        true
    }
}

extension ViewGraph {

    /// The path from the root to the front-most node that takes a hit at
    /// `point`, in the root's coordinate space.
    package func hitTest(_ point: CGPoint) -> [Int]? {
        root.hitTest(point)?.map(\.id)
    }
}
