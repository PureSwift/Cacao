//
//  ViewNode.swift
//  Cacao
//
//  Created by Alsey Coleman Miller on 11/13/26.
//

import Foundation
import Observation
#if canImport(CoreGraphics)
import CoreGraphics
#endif

/// A view's place in the retained view tree.
///
/// A node keeps its view's state for as long as the view keeps its identity:
/// the same type at the same structural position (and the same `id`, inside
/// a `ForEach` or under `.id(_:)`). Each update replaces the node's view value
/// and resolves it again.
@MainActor
internal final class ViewNode {

    unowned let graph: ViewGraph

    weak var parent: ViewNode?

    /// The node's structural identity among its siblings.
    let key: AnyHashable

    /// The type of the node's view; a different type is a different node.
    let viewType: ObjectIdentifier

    /// A number unique to this node within its graph.
    let id: Int

    let depth: Int

    private(set) var view: any View

    var environment: EnvironmentValues

    private(set) var children: [ViewNode] = []

    /// How the node lays out and draws, or `nil` for a transparent node.
    private(set) var behavior: (any NodeBehavior)?

    private(set) var attributes = NodeAttributes()

    /// Storage of dynamic properties such as `@State`, by property label.
    var dynamicStorage: [String: AnyObject] = [:]

    /// Whether the node must be resolved again.
    private(set) var isDirty = false

    /// Incremented each time the node is resolved, for the display list.
    private(set) var version = 0

    private(set) lazy var observationToken = ObservationToken(node: self)

    // MARK: Layout state

    var layoutGeneration = -1

    var sizeCache: [ProposedViewSize: CGSize] = [:]

    /// Explicit alignment guides by guide and proposal; `nil` values too.
    var explicitAlignmentCache: [ExplicitAlignmentKey: CGFloat?] = [:]

    var layoutCache: Any?

    /// The node's frame in the root's coordinate space, from the last layout.
    var frame: CGRect = .zero

    /// The layout pass that last placed this node.
    var placedGeneration = -1

    /// Where and with which proposal the node was last placed.
    var lastPlacement: (origin: CGPoint, proposal: ProposedViewSize)?

    var cachedLayoutChildren: [LayoutProxy]?

    /// Whether the node's measurements from the last layout still hold:
    /// false once it or a node in its subtree is resolved.
    var isLayoutValid = false

    /// Marks this node's and its ancestors' measurements stale.
    func invalidateLayout() {
        var node: ViewNode? = self
        while let current = node, current.isLayoutValid {
            current.isLayoutValid = false
            node = current.parent
        }
    }

    init(
        graph: ViewGraph,
        parent: ViewNode?,
        key: AnyHashable,
        view: any View,
        environment: EnvironmentValues
    ) {
        self.graph = graph
        self.parent = parent
        self.key = key
        self.view = view
        self.viewType = ObjectIdentifier(type(of: view))
        self.environment = environment
        self.depth = (parent?.depth ?? -1) + 1
        self.id = graph.makeNodeID()
    }

    /// Marks the node to be resolved on the next update.
    func invalidate() {
        guard !isDirty else { return }
        isDirty = true
        graph.nodeDidInvalidate(self)
    }

    /// Replaces the view value and environment, to be resolved next.
    func update(view: any View, environment: EnvironmentValues) {
        self.view = view
        self.environment = environment
        wasUpdatedByParent = true
    }

    /// Whether the node got a new view value from its parent since it was
    /// last resolved, rather than only being invalidated itself.
    private(set) var wasUpdatedByParent = false

    /// The transaction the node was last resolved in.
    private(set) var transaction = Transaction()

    /// The update the node was last resolved in.
    private(set) var resolvedGeneration = -1

    /// The update that created the node.
    var insertedGeneration = -1

    /// Whether the next resolve shows an animatable view's in-between value.
    var isAnimationFrame = false

    /// Modifiers from ancestors that this node applies to each of its views,
    /// innermost first.
    var pushedModifiers: [(any View) -> any View] = []

    /// Whether this modifier's node passes it down to a custom view below,
    /// whose body has several views, rather than applying it itself.
    var pushesModifier = false

    /// For a custom view: how many views its body is made of.
    private(set) var bodyViewCount = 1

    // MARK: Resolving

    /// Resolves the node's view and, recursively, its children.
    func resolve() {
        resolve(isRetry: false)
    }

    private func resolve(isRetry: Bool) {
        graph.statistics.resolves += 1
        invalidateLayout()
        isDirty = false
        version += 1
        cachedLayoutChildren = nil
        transaction = graph.currentTransaction
        resolvedGeneration = graph.updateGeneration
        let context = ResolveContext(node: self)
        let resolution: Resolution
        if let primitive = view as? any PrimitiveView {
            // Primitives read observable values too, like a ForEach's
            // content closure.
            let token = observationToken
            resolution = withObservationTracking {
                primitive.resolve(in: context)
            } onChange: {
                token.invalidate()
            }
        } else {
            resolution = resolveComposite(view, in: context)
        }
        // A transparent node's children are its layout parent's: that
        // parent's list of layout children changes with them.
        if behavior == nil || resolution.behavior == nil {
            var node = parent
            while let current = node {
                current.cachedLayoutChildren = nil
                if current.behavior != nil { break }
                node = current.parent
            }
        }
        behavior = resolution.behavior
        attributes = resolution.attributes
        wasUpdatedByParent = false
        isAnimationFrame = false
        // A modifier like animation(_:value:) changes the transaction of
        // its subtree.
        if let transform = resolution.transaction {
            let previous = graph.currentTransaction
            transform(&graph.currentTransaction)
            transaction = graph.currentTransaction
            reconcile(resolution.children, keepingExisting: resolution.keepsExistingChildren)
            graph.currentTransaction = previous
        } else {
            reconcile(resolution.children, keepingExisting: resolution.keepsExistingChildren)
        }
        // A modifier over a custom view applies to each view of its body
        // when the body, now resolved, has several.
        if resolution.canPushModifier || pushesModifier, !isRetry {
            let needed = resolution.canPushModifier && hasMultiViewBody
            if needed != pushesModifier {
                pushesModifier = needed
                resolve(isRetry: true)
            }
        }
    }

    private func resolveComposite<V: View>(_ view: V, in context: ResolveContext) -> Resolution {
        let shown = context.animatedValue(view)
        let body = evaluateBody(shown, in: context)
        let items = ContentViews(body)?.items
        let count = items?.count ?? 1
        if count != bodyViewCount {
            bodyViewCount = count
            if version > 1 {
                modifiersAboveNeedUpdate()
            }
        }
        guard !pushedModifiers.isEmpty else {
            return Resolution(children: [ChildView(key: 0, view: body)])
        }
        // Modifiers from above apply to each view of the body, or pass on
        // to the custom view it is.
        let modifiers = pushedModifiers
        let views = items ?? [(AnyHashable(0), body)]
        if views.count == 1, ContentViews.canPushModifiers(into: views[0].view) {
            return Resolution(children: [ChildView(key: views[0].id, view: views[0].view, modifiers: modifiers)])
        }
        return Resolution(children: views.map { item in
            ChildView(key: item.id, view: modifiers.reduce(item.view) { $1($0) })
        })
    }

    /// Whether the custom view below this modifier, through other built-in
    /// modifiers, groups and custom views of one view, has a body of several.
    private var hasMultiViewBody: Bool {
        var node = contentChild
        while let current = node {
            if !(current.view is any PrimitiveView) {
                if current.bodyViewCount != 1 {
                    return true
                }
            } else if current.view is any _StructuralWrapper, current.children.count == 1 {
                node = current.children[0]
                continue
            } else if !((current.view as? any _ModifiedViews)?.isPrimitive ?? false) {
                return false
            }
            node = current.contentChild
        }
        return false
    }

    /// Updates the modifiers whose content leads, through custom views of
    /// one view, to this custom view, whose body changed how many views it is.
    private func modifiersAboveNeedUpdate() {
        var child = self
        while let current = child.parent,
              current.contentChild === child || (current.view is any _StructuralWrapper && current.children.count == 1) {
            if (current.view as? any _ModifiedViews)?.isPrimitive ?? false {
                current.invalidate()
            } else if current.view is any PrimitiveView {
                return
            }
            child = current
        }
    }

    /// The child holding a modifier's content or a custom view's body.
    private var contentChild: ViewNode? {
        children.first { $0.key == AnyHashable(0) }
    }

    private func evaluateBody<V: View>(_ view: V, in context: ResolveContext) -> any View {
        context.evaluate {
            view.body
        } installing: {
            view
        }
    }

    /// Matches child views to existing child nodes by key and type, creating
    /// and removing nodes as needed, and resolves each child.
    private func reconcile(_ childViews: [ChildView], keepingExisting: Bool = false) {
        var existing: [AnyHashable: ViewNode] = [:]
        for child in children {
            existing[child.key] = child
        }
        var newChildren: [ViewNode] = []
        newChildren.reserveCapacity(childViews.count)
        var seenKeys: [AnyHashable: Int] = [:]
        for childView in childViews {
            // Disambiguate duplicate keys, such as repeated ForEach IDs.
            var key = childView.key
            if let count = seenKeys[key] {
                seenKeys[key] = count + 1
                key = AnyHashable(DuplicateKey(key: key, occurrence: count))
            } else {
                seenKeys[key] = 1
            }
            let environment = childView.environment ?? self.environment
            let node: ViewNode
            if let match = existing[key], match.viewType == ObjectIdentifier(type(of: childView.view)) {
                existing[key] = nil
                if keepingExisting, !match.isDirty {
                    newChildren.append(match)
                    continue
                }
                match.update(view: childView.view, environment: environment)
                match.pushedModifiers = childView.modifiers
                node = match
            } else {
                node = ViewNode(
                    graph: graph,
                    parent: self,
                    key: key,
                    view: childView.view,
                    environment: environment
                )
                node.insertedGeneration = graph.updateGeneration
                node.pushedModifiers = childView.modifiers
                graph.nodeDidAppear(node)
            }
            node.resolve()
            newChildren.append(node)
        }
        let previous = children
        children = newChildren
        for removed in existing.values {
            // Removed with an animation, a view keeps drawing as it
            // transitions out.
            if graph.currentAnimation != nil, let index = previous.firstIndex(where: { $0 === removed }) {
                graph.addGhost(for: removed, index: index, in: self)
            }
            removed.tearDown()
        }
    }

    /// Removes the node and its subtree from the graph.
    func tearDown() {
        for child in children {
            child.tearDown()
        }
        graph.nodeDidDisappear(self)
        children = []
        dynamicStorage = [:]
        parent = nil
    }

    // MARK: Traversal

    /// Visits this node and its descendants, depth first.
    func forEachNode(_ body: (ViewNode) -> Void) {
        body(self)
        for child in children {
            child.forEachNode(body)
        }
    }

    /// The outermost nodes with a behavior in this node's subtree, including
    /// this node if it has one.
    var topLevelUnits: [ViewNode] {
        if behavior != nil {
            return [self]
        }
        return children.flatMap(\.topLevelUnits)
    }
}

/// The key of a child whose key repeats one of its earlier siblings'.
private struct DuplicateKey: Hashable {

    let key: AnyHashable

    let occurrence: Int
}
