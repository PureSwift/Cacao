//
//  LayoutEngine.swift
//  Cacao
//
//  Created by Alsey Coleman Miller on 11/13/26.
//

import Foundation
#if canImport(CoreGraphics)
import CoreGraphics
#endif

// MARK: - NodeBehavior

/// How a node with layout lays out and draws.
///
/// Nodes with a behavior are the units of layout: a container's subviews are
/// the outermost units among its descendants, found through transparent
/// nodes (composite views, groups, `ForEach`, conditionals and so on).
@MainActor
internal protocol NodeBehavior {

    /// The size of the node for a proposal.
    func sizeThatFits(_ proposal: ProposedViewSize, node: ViewNode) -> CGSize

    /// Places the node's layout children within its frame, `bounds`.
    func placeChildren(in bounds: CGRect, proposal: ProposedViewSize, node: ViewNode)

    /// The node's spacing preferences.
    func spacing(node: ViewNode) -> ViewSpacing

    /// The node's explicit value for an alignment guide, if it has one.
    func explicitAlignment(
        _ key: AlignmentKey,
        size: CGSize,
        proposal: ProposedViewSize,
        node: ViewNode
    ) -> CGFloat?

    /// The content the node draws within its frame, if any.
    func displayContent(node: ViewNode) -> DisplayList.Content?

    /// An effect the node applies to its subtree's drawing, if any.
    func displayEffect(node: ViewNode) -> DisplayList.Effect?

    /// The node's children in drawing order, back to front.
    func displayOrder(of children: [ViewNode]) -> [ViewNode]

    /// Whether the node's own drawing takes a hit at `point`.
    func hitTest(_ point: CGPoint, node: ViewNode) -> Bool

    /// Whether the node and its subtree take hits at all.
    func allowsHitTesting(node: ViewNode) -> Bool
}

extension NodeBehavior {

    func placeChildren(in bounds: CGRect, proposal: ProposedViewSize, node: ViewNode) { }

    func spacing(node: ViewNode) -> ViewSpacing {
        ViewSpacing()
    }

    func explicitAlignment(
        _ key: AlignmentKey,
        size: CGSize,
        proposal: ProposedViewSize,
        node: ViewNode
    ) -> CGFloat? {
        nil
    }

    func displayContent(node: ViewNode) -> DisplayList.Content? {
        nil
    }

    func displayEffect(node: ViewNode) -> DisplayList.Effect? {
        nil
    }

    func displayOrder(of children: [ViewNode]) -> [ViewNode] {
        children
    }
}

// MARK: - LayoutTraits

/// Values that a container reads from its subviews, like layout priority.
internal struct LayoutTraits {

    var values: [ObjectIdentifier: Any] = [:]

    subscript<K: LayoutValueKey>(key: K.Type) -> K.Value {
        get { values[ObjectIdentifier(key)] as? K.Value ?? K.defaultValue }
        set { values[ObjectIdentifier(key)] = newValue }
    }

    /// These traits with `inner`'s values replacing any set here.
    func merging(_ inner: LayoutTraits) -> LayoutTraits {
        guard !inner.values.isEmpty else { return self }
        var result = self
        result.values.merge(inner.values) { $1 }
        return result
    }
}

/// The layout priority trait.
internal enum LayoutPriorityKey: LayoutValueKey {

    static let defaultValue: Double = 0
}

// MARK: - LayoutProxy

/// A layout child: a node with a behavior, or several children laid out as
/// a vertical stack where a single child is expected.
@MainActor
internal struct LayoutProxy {

    enum Storage {
        case node(ViewNode)
        case group([LayoutProxy])
    }

    let storage: Storage

    let traits: LayoutTraits

    init(node: ViewNode, traits: LayoutTraits = LayoutTraits()) {
        self.storage = .node(node)
        self.traits = traits
    }

    private init(group: [LayoutProxy]) {
        self.storage = .group(group)
        self.traits = LayoutTraits()
    }

    /// One proxy for a list of children: the child itself when there's one,
    /// or an implicit vertical stack of them.
    static func combining(_ children: [LayoutProxy]) -> LayoutProxy? {
        switch children.count {
        case 0: nil
        case 1: children[0]
        default: LayoutProxy(group: children)
        }
    }

    var priority: Double {
        traits[LayoutPriorityKey.self]
    }

    /// The priority a stack sizes the child with: spacers without an
    /// explicit priority come last, after every other child, as in SwiftUI.
    var stackPriority: Double {
        if case let .node(node) = storage, node.behavior is SpacerBehavior, traits.values[ObjectIdentifier(LayoutPriorityKey.self)] == nil {
            return -.infinity
        }
        return priority
    }

    /// An identifier unique among proxies of the same layout pass.
    var identity: ObjectIdentifier? {
        if case let .node(node) = storage {
            return ObjectIdentifier(node)
        }
        return nil
    }

    func size(in proposal: ProposedViewSize) -> CGSize {
        switch storage {
        case let .node(node):
            node.sizeThatFits(proposal)
        case let .group(children):
            StackAlgorithm(axis: .vertical, alignment: HorizontalAlignment.center.key, uniformSpacing: nil, children: children)
                .size(in: proposal)
        }
    }

    func dimensions(in proposal: ProposedViewSize) -> ViewDimensions {
        let size = size(in: proposal)
        return ViewDimensions(size: size) { key in
            self.explicitAlignment(key, size: size, proposal: proposal)
        }
    }

    func explicitAlignment(_ key: AlignmentKey, size: CGSize, proposal: ProposedViewSize) -> CGFloat? {
        switch storage {
        case let .node(node):
            node.explicitAlignment(key, size: size, proposal: proposal)
        case let .group(children):
            StackAlgorithm(axis: .vertical, alignment: HorizontalAlignment.center.key, uniformSpacing: nil, children: children)
                .explicitAlignment(key, size: size, proposal: proposal)
        }
    }

    var spacing: ViewSpacing {
        switch storage {
        case let .node(node):
            node.spacing
        case let .group(children):
            StackAlgorithm(axis: .vertical, alignment: HorizontalAlignment.center.key, uniformSpacing: nil, children: children)
                .spacing()
        }
    }

    /// Places the child with its top-leading corner at `origin`, in the
    /// root's coordinate space, sized for `proposal`.
    func place(at origin: CGPoint, proposal: ProposedViewSize) {
        switch storage {
        case let .node(node):
            node.place(at: origin, proposal: proposal)
        case let .group(children):
            let size = size(in: proposal)
            StackAlgorithm(axis: .vertical, alignment: HorizontalAlignment.center.key, uniformSpacing: nil, children: children)
                .place(in: CGRect(origin: origin, size: size), proposal: proposal)
        }
    }

    var isPlaced: Bool {
        switch storage {
        case let .node(node):
            node.placedGeneration == node.graph.layoutGeneration
        case let .group(children):
            children.allSatisfy(\.isPlaced)
        }
    }
}

// MARK: - ViewNode layout

extension ViewNode {

    /// The node's layout children: the outermost nodes with a behavior among
    /// its descendants, with the traits set on the way down to them.
    var layoutChildren: [LayoutProxy] {
        if let cachedLayoutChildren {
            return cachedLayoutChildren
        }
        let result = Self.flatten(children, traits: LayoutTraits())
        cachedLayoutChildren = result
        return result
    }

    /// The layout children of one of this node's children.
    func layoutChildren(ofChildAt index: Int) -> [LayoutProxy] {
        guard children.indices.contains(index) else {
            return []
        }
        return Self.flatten([children[index]], traits: LayoutTraits())
    }

    private static func flatten(_ nodes: [ViewNode], traits: LayoutTraits) -> [LayoutProxy] {
        var result: [LayoutProxy] = []
        for node in nodes {
            let traits = traits.merging(node.attributes.traits)
            if node.behavior != nil {
                result.append(LayoutProxy(node: node, traits: traits))
            } else {
                result.append(contentsOf: flatten(node.children, traits: traits))
            }
        }
        return result
    }

    private func resetLayoutCachesIfNeeded() {
        if layoutGeneration != graph.layoutGeneration {
            layoutGeneration = graph.layoutGeneration
            sizeCache.removeAll(keepingCapacity: true)
            layoutCache = nil
        }
    }

    func sizeThatFits(_ proposal: ProposedViewSize) -> CGSize {
        resetLayoutCachesIfNeeded()
        if let size = sizeCache[proposal] {
            return size
        }
        let size = behavior?.sizeThatFits(proposal, node: self) ?? .zero
        sizeCache[proposal] = size
        return size
    }

    func explicitAlignment(_ key: AlignmentKey, size: CGSize, proposal: ProposedViewSize) -> CGFloat? {
        resetLayoutCachesIfNeeded()
        return behavior?.explicitAlignment(key, size: size, proposal: proposal, node: self)
    }

    var spacing: ViewSpacing {
        resetLayoutCachesIfNeeded()
        return behavior?.spacing(node: self) ?? ViewSpacing()
    }

    func dimensions(in proposal: ProposedViewSize) -> ViewDimensions {
        LayoutProxy(node: self).dimensions(in: proposal)
    }

    /// Sets the node's frame for `proposal` with its top-leading corner at
    /// `origin`, then places its children. Children its behavior leaves
    /// unplaced are centered in the frame with the same proposal.
    func place(at origin: CGPoint, proposal: ProposedViewSize) {
        let size = sizeThatFits(proposal)
        frame = CGRect(origin: origin, size: size)
        placedGeneration = graph.layoutGeneration
        behavior?.placeChildren(in: frame, proposal: proposal, node: self)
        for child in layoutChildren where !child.isPlaced {
            let childSize = child.size(in: proposal)
            child.place(
                at: CGPoint(x: frame.midX - childSize.width / 2, y: frame.midY - childSize.height / 2),
                proposal: proposal
            )
        }
    }
}
