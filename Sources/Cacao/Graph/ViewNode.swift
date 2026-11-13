//
//  ViewNode.swift
//  Cacao
//
//  Created by Alsey Coleman Miller on 11/13/26.
//

import Foundation
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

    var layoutCache: Any?

    /// The node's frame in the root's coordinate space, from the last layout.
    var frame: CGRect = .zero

    /// The layout pass that last placed this node.
    var placedGeneration = -1

    var cachedLayoutChildren: [LayoutProxy]?

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
    }

    // MARK: Resolving

    /// Resolves the node's view and, recursively, its children.
    func resolve() {
        isDirty = false
        version += 1
        cachedLayoutChildren = nil
        let context = ResolveContext(node: self)
        let resolution: Resolution
        if let primitive = view as? any PrimitiveView {
            resolution = primitive.resolve(in: context)
        } else {
            resolution = resolveComposite(view, in: context)
        }
        behavior = resolution.behavior
        attributes = resolution.attributes
        reconcile(resolution.children)
    }

    private func resolveComposite<V: View>(_ view: V, in context: ResolveContext) -> Resolution {
        let body = context.evaluate {
            view.body
        } installing: {
            view
        }
        return Resolution(children: [ChildView(key: 0, view: body)])
    }

    /// Matches child views to existing child nodes by key and type, creating
    /// and removing nodes as needed, and resolves each child.
    private func reconcile(_ childViews: [ChildView]) {
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
                match.update(view: childView.view, environment: environment)
                node = match
            } else {
                node = ViewNode(
                    graph: graph,
                    parent: self,
                    key: key,
                    view: childView.view,
                    environment: environment
                )
                graph.nodeDidAppear(node)
            }
            node.resolve()
            newChildren.append(node)
        }
        children = newChildren
        for removed in existing.values {
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
