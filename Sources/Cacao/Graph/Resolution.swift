//
//  Resolution.swift
//  Cacao
//
//  Created by Alsey Coleman Miller on 11/13/26.
//

import Foundation
#if canImport(CoreGraphics)
import CoreGraphics
#endif
import Observation

/// What a view contributes to its node: its behavior and its child views.
internal struct Resolution {

    /// How the node lays out and draws, or `nil` for a transparent node,
    /// whose children take part in layout as if they were its parent's.
    var behavior: (any NodeBehavior)?

    /// The child views, keyed by their structural identity within this node.
    var children: [ChildView]

    /// Traits, identifiers, preferences and lifecycle actions of the node.
    var attributes: NodeAttributes

    /// Whether existing children that aren't invalidated keep their views,
    /// as when a lazy stack only creates rows that scrolled into view.
    var keepsExistingChildren = false

    /// Changes the transaction for the node's subtree in this update.
    var transaction: ((inout Transaction) -> Void)?

    init(
        behavior: (any NodeBehavior)? = nil,
        children: [ChildView] = [],
        attributes: NodeAttributes = NodeAttributes()
    ) {
        self.behavior = behavior
        self.children = children
        self.attributes = attributes
    }
}

/// A child view and its identity within its parent node.
internal struct ChildView {

    /// The child's structural identity among its siblings.
    var key: AnyHashable

    var view: any View

    /// The child's environment, or `nil` to inherit the parent's.
    var environment: EnvironmentValues?

    init<Key: Hashable>(key: Key, view: any View, environment: EnvironmentValues? = nil) {
        self.key = AnyHashable(key)
        self.view = view
        self.environment = environment
    }
}

/// Attributes of a node that aren't its layout or drawing.
internal struct NodeAttributes {

    /// Values that containers read from their subviews, like layout priority.
    var traits = LayoutTraits()

    /// The accessibility identifier, which also identifies the view in tests.
    var identifier: String?

    /// A preference value this node sets for its subtree.
    var preference: PreferenceValue?

    /// A function that transforms a preference value from this node's subtree.
    var preferenceTransform: PreferenceTransform?

    /// An action called when a preference from this node's subtree changes.
    var preferenceObserver: PreferenceObserver?

    var onAppear: (() -> Void)?

    var onDisappear: (() -> Void)?

    /// A tap gesture on the node's views.
    var tap: TapHandler?

    /// The shape, in the subtree's frame, that takes hits for the node.
    var contentShape: ((CGRect) -> Path)?

    /// Whether the node and its subtree take hits.
    var allowsHitTesting = true

    /// How the node handles keyboard focus, if it can be focused.
    var focus: FocusTarget?

    /// A binding between a focus state and the focusable view in the subtree.
    var focusBinding: FocusBinding?

    /// A drag gesture on the node's views.
    var drag: DragHandler?

    /// Menu items shown on a secondary click.
    var contextMenu: AnyView?

    /// How the node animates in and out.
    var transition: AnyTransition?

    /// The node's matched geometry group.
    var matchedGeometry: AnyHashable?

    /// Gestures attached to the node's views.
    var gestures: [GestureAttachment] = []

    /// The name of the node's coordinate space.
    var coordinateSpaceName: AnyHashable?

    /// Whether the node's layout's views are where scroll views settle.
    var isScrollTargetLayout = false

    /// What the node tells assistive technologies.
    var accessibility: AccessibilityAttributes?

    /// What the node does when the pointer hovers over it.
    var hover: HoverHandler?

    /// A keyboard shortcut that presses the node's control.
    var keyboardShortcut: KeyboardShortcut?

    /// Handlers of keys pressed while the node or a descendant has focus.
    var keyPress: [KeyPressHandler] = []

    /// Whether preference readers in the node's overlay or background read
    /// from the node's views.
    var isPreferenceSource = false
}

// MARK: - ResolveContext

/// The node a view is resolved in, and the services resolving uses.
@MainActor
internal struct ResolveContext {

    let node: ViewNode

    var environment: EnvironmentValues {
        node.environment
    }

    var graph: ViewGraph {
        node.graph
    }

    /// Connects the dynamic properties of `value` to the node, then evaluates
    /// `body`, recording the observable properties it reads so that a change
    /// to any of them invalidates the node.
    func evaluate<Result>(
        _ body: () -> Result,
        installing value: () -> Any
    ) -> Result {
        DynamicProperties.install(in: value(), node: node)
        let token = node.observationToken
        return withObservationTracking(body, onChange: {
            token.invalidate()
        })
    }
}

extension ResolveContext {

    /// For an animatable view or modifier: the value to evaluate, with its
    /// animatable data partway through an animation when one is running,
    /// starting one when the data changed in an animated transaction.
    func animatedValue<V>(_ value: V) -> V {
        guard let components = AnimatableViews.components(of: value) else {
            return value
        }
        let graph = self.graph
        let state = graph.animations(of: node)
        defer { state.modelViewData = components }
        if node.isAnimationFrame, let animation = state.viewData {
            let current = animation.values(at: graph.time).values
            return (AnimatableViews.view(value as! any View, with: current) as? V) ?? value
        }
        guard let model = state.modelViewData, model != components, model.count == components.count else {
            return value
        }
        guard let animation = graph.currentAnimation else {
            state.viewData = nil
            return value
        }
        let from = state.viewData?.values(at: graph.time).values ?? model
        state.viewData = PropertyAnimation(from: from, to: components, animation: animation, start: graph.time)
        graph.animatedViewNodes[node.id] = WeakNodeReference(node)
        return (AnimatableViews.view(value as! any View, with: from) as? V) ?? value
    }
}

/// Invalidates a node when an observable property its body read changes.
internal final class ObservationToken: @unchecked Sendable {

    private weak var node: ViewNode?

    private weak var queue: InvalidationQueue?

    @MainActor
    init(node: ViewNode) {
        self.node = node
        self.queue = node.graph.invalidations
    }

    func invalidate() {
        queue?.enqueue(node, transaction: Transaction.current)
    }
}
