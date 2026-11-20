//
//  AnimationEngine.swift
//  Cacao
//
//  Created by Alsey Coleman Miller on 11/13/26.
//

import CacaoRender
import Foundation
#if canImport(CoreGraphics)
import CoreGraphics
#endif

// MARK: - Property animations

/// A value moving from one set of numbers to another over time.
internal struct PropertyAnimation {

    var from: [Double]

    var to: [Double]

    let animation: Animation

    let start: Double

    /// The values at `time`, and whether the animation has finished.
    func values(at time: Double) -> (values: [Double], isFinished: Bool) {
        let progress = animation.progress(at: time - start)
        if progress.isFinished {
            return (to, true)
        }
        let amount = progress.value
        return (zip(from, to).map { $0 + ($1 - $0) * amount }, false)
    }
}

/// A view's animation state: what it last committed, and what's moving.
@MainActor
internal final class NodeAnimations {

    /// The last committed frame.
    var modelFrame: CGRect?

    var frame: PropertyAnimation?

    /// The last committed values of the node's behavior.
    var modelValues: [Double]?

    var values: PropertyAnimation?

    /// An insertion transition's progress from 0 to 1.
    var transition: (transition: AnyTransition, animation: PropertyAnimation)?

    /// A matched geometry move: the frame it moves from, animated from 0 to 1.
    var geometry: (from: CGRect, animation: PropertyAnimation)?

    /// For animatable views: the last committed animatable data.
    var modelViewData: [Double]?

    var viewData: PropertyAnimation?

    var isActive: Bool {
        frame != nil || values != nil || transition != nil || geometry != nil || viewData != nil
    }
}

/// A behavior with values that animate, like opacity or color.
@MainActor
internal protocol AnimatableBehavior: NodeBehavior {

    var animatableValues: [Double] { get }

    /// The behavior showing values partway through an animation.
    func applying(_ values: [Double]) -> any NodeBehavior
}

// MARK: - Removed views

/// A removed view still drawing while it transitions out.
internal struct Ghost {

    /// The index among its siblings it was removed from.
    let index: Int

    let items: [DisplayList.Item]

    let frame: CGRect

    let transition: AnyTransition

    let animation: PropertyAnimation

    let identity: Int
}

// MARK: - Graph

extension ViewGraph {

    /// The animation of the current update, from `withAnimation` or bindings.
    var currentAnimation: Animation? {
        currentTransaction.disablesAnimations ? nil : currentTransaction.animation
    }

    /// Records the transaction of a state change for the next update.
    func record(_ transaction: Transaction?) {
        guard let transaction else { return }
        if transaction.animation != nil || pendingTransaction == nil {
            pendingTransaction = transaction
        }
    }

    /// Animates what changed in the last layout: frames and values of nodes,
    /// with the transaction they were resolved in or the update's.
    func commitAnimations() {
        let time = self.time
        // Insertions and resolved transactions belong to the update's first
        // layout; later layouts only animate frames the update moved.
        // Updates since the last commit, which may be several when layout
        // updated views.
        let since = committedGeneration
        let isNewUpdate = since != updateGeneration
        committedGeneration = updateGeneration
        var matched: [AnyHashable: (frame: CGRect, node: Int)] = [:]
        func visit(_ node: ViewNode, inherited: Transaction) {
            let transaction = isNewUpdate && node.resolvedGeneration > since ? node.transaction : inherited
            let animation = transaction.disablesAnimations ? nil : transaction.animation
            let state = animations(of: node)
            if node.behavior != nil {
                commitFrame(node, state: state, animation: animation, time: time)
                commitValues(node, state: state, animation: animation, time: time)
            }
            if isNewUpdate, node.insertedGeneration > since, let animation, !((node.parent?.insertedGeneration ?? -1) > since) {
                let transition = node.transitionAttribute ?? .opacity
                state.transition = (transition, PropertyAnimation(from: [0], to: [1], animation: animation, start: time))
            }
            // A source that replaces another moves from where the other was;
            // views that aren't sources follow the source's frame.
            if let geometry = node.attributes.matchedGeometry, geometry.isSource, !geometry.properties.isEmpty {
                let key = geometry.key
                let frame = node.subtreeFrame
                matched[key] = (frame, node.id)
                if isNewUpdate, let previous = matchedFrames[key], previous.node != node.id, let animation, !frame.isNull, !previous.frame.isNull {
                    let start = geometry.frame(at: frame, matching: previous.frame.size, point: geometry.anchorPoint(in: previous.frame))
                    state.geometry = (start, PropertyAnimation(from: [0], to: [1], animation: animation, start: time))
                    state.transition = nil
                }
            }
            for child in node.children {
                visit(child, inherited: transaction)
            }
        }
        visit(root, inherited: baseTransaction)
        matchedFrames = matched
        baseTransaction = Transaction()
        if !nodeAnimations.isEmpty || !ghosts.isEmpty {
            setNeedsDisplay()
        }
    }

    private func commitFrame(_ node: ViewNode, state: NodeAnimations, animation: Animation?, time: Double) {
        let frame = node.frame
        defer { state.modelFrame = frame }
        guard let model = state.modelFrame, model != frame else { return }
        if let animation {
            // From where it shows: partway through a running animation, or
            // where it was committed.
            let current = state.frame?.values(at: time).values ?? model.components
            state.frame = PropertyAnimation(from: current, to: frame.components, animation: animation, start: time)
        } else {
            state.frame = nil
        }
    }

    private func commitValues(_ node: ViewNode, state: NodeAnimations, animation: Animation?, time: Double) {
        guard let behavior = node.behavior as? any AnimatableBehavior else { return }
        let values = behavior.animatableValues
        defer { state.modelValues = values }
        guard let model = state.modelValues, model != values, model.count == values.count else { return }
        if let animation {
            let current = state.values?.values(at: time).values ?? model
            state.values = PropertyAnimation(from: current, to: values, animation: animation, start: time)
        } else {
            state.values = nil
        }
    }

    func animations(of node: ViewNode) -> NodeAnimations {
        if let state = nodeAnimations[node.id] {
            return state
        }
        let state = NodeAnimations()
        nodeAnimations[node.id] = state
        return state
    }

    /// The frame a node shows at a time: its frame, or partway to it.
    func presentationFrame(of node: ViewNode, state: NodeAnimations? = nil, time: Double? = nil) -> CGRect {
        guard let state = state ?? nodeAnimations[node.id], let animation = state.frame else {
            return node.frame
        }
        return CGRect(components: animation.values(at: time ?? self.time).values)
    }

    /// The behavior a node shows at the current time.
    func presentationBehavior(of node: ViewNode) -> (any NodeBehavior)? {
        guard let behavior = node.behavior as? any AnimatableBehavior,
              let animation = nodeAnimations[node.id]?.values else {
            return node.behavior
        }
        return behavior.applying(animation.values(at: time).values)
    }

    /// Advances animations to `time`: removes finished ones and re-resolves
    /// animatable views at their in-between values.
    package func advanceAnimations(to time: Double) {
        self.time = time
        showTooltipIfDue()
        // What was animating draws once more as it finishes: at its final
        // values, and without what only showed during a transition.
        let wasActive = hasActiveAnimations
        var finished: [Int] = []
        for (id, state) in nodeAnimations {
            if let animation = state.frame, animation.values(at: time).isFinished { state.frame = nil }
            if let animation = state.values, animation.values(at: time).isFinished { state.values = nil }
            if let transition = state.transition, transition.animation.values(at: time).isFinished { state.transition = nil }
            if let geometry = state.geometry, geometry.animation.values(at: time).isFinished { state.geometry = nil }
            if state.viewData != nil, let node = animatedViewNodes[id]?.node, node.isAttached {
                node.invalidateForAnimationFrame()
                if state.viewData!.values(at: time).isFinished { state.viewData = nil }
            }
            if !state.isActive, state.modelFrame == nil {
                finished.append(id)
            }
        }
        for id in finished {
            nodeAnimations[id] = nil
        }
        tickGestures()
        fireWakeups()
        advanceScrollAnimations()
        ghosts = ghosts.mapValues { list in
            list.filter { !$0.animation.values(at: time).isFinished }
        }.filter { !$0.value.isEmpty }
        if wasActive || hasActiveAnimations {
            setNeedsDisplay()
        }
    }

    /// Whether anything is animating, so the host keeps drawing frames.
    package var hasActiveAnimations: Bool {
        !ghosts.isEmpty || !scrollAnimations.isEmpty || gesturesNeedTicks || hasFrameWakeups || nodeAnimations.values.contains { $0.isActive }
    }

    /// Keeps a removed node's drawing to transition it out.
    func addGhost(for node: ViewNode, index: Int, in parent: ViewNode) {
        guard let animation = currentAnimation, !node.subtreeFrame.isNull else { return }
        let items = node.displayItems()
        guard !items.isEmpty else { return }
        let ghost = Ghost(
            index: index,
            items: items,
            frame: node.subtreeFrame,
            transition: node.transitionAttribute ?? .opacity,
            animation: PropertyAnimation(from: [1], to: [0], animation: animation, start: time),
            identity: node.id
        )
        ghosts[parent.id, default: []].append(ghost)
    }
}

extension ViewNode {

    /// The transition set on this node, or on the transparent nodes it wraps.
    var transitionAttribute: AnyTransition? {
        if let transition = attributes.transition {
            return transition
        }
        guard behavior == nil, children.count == 1 else { return nil }
        return children[0].transitionAttribute
    }

    /// Re-resolves an animatable view at its current in-between value.
    func invalidateForAnimationFrame() {
        isAnimationFrame = true
        invalidate()
    }
}

extension CGRect {

    var components: [Double] {
        [Double(minX), Double(minY), Double(width), Double(height)]
    }

    init(components: [Double]) {
        self.init(x: components[0], y: components[1], width: components[2], height: components[3])
    }
}

// MARK: - Animatable views

/// Interpolating an animatable view's data, for views and modifiers that
/// conform to `Animatable`.
internal enum AnimatableViews {

    /// The components of a view's animatable data, if it has any.
    static func components(of value: Any) -> [Double]? {
        guard let animatable = value as? any Animatable else { return nil }
        return components(animatable)
    }

    private static func components<A: Animatable>(_ value: A) -> [Double]? {
        guard let components = AnimatableVector.components(value.animatableData), !components.isEmpty else {
            return nil
        }
        return components
    }

    /// The view with its animatable data replaced by components.
    static func view(_ view: any View, with components: [Double]) -> any View {
        guard let animatable = view as? any Animatable else { return view }
        return replacing(animatable, components) as? any View ?? view
    }

    private static func replacing<A: Animatable>(_ value: A, _ components: [Double]) -> A {
        var value = value
        if let data = AnimatableVector.value(components, like: value.animatableData) {
            value.animatableData = data
        }
        return value
    }
}
