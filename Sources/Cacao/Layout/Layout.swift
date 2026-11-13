//
//  Layout.swift
//  Cacao
//
//  Created by Alsey Coleman Miller on 11/13/26.
//

import Foundation
#if canImport(CoreGraphics)
import CoreGraphics
#endif

// MARK: - Layout

/// A type that defines the geometry of a collection of views.
@MainActor
@preconcurrency
public protocol Layout {

    /// Cached values associated with the layout instance.
    associatedtype Cache = Void

    /// A collection of proxies for the subviews of a layout view.
    typealias Subviews = LayoutSubviews

    /// Properties of a layout container.
    static var layoutProperties: LayoutProperties { get }

    /// Returns the size of the composite view, given a proposed size and the
    /// view's subviews.
    func sizeThatFits(proposal: ProposedViewSize, subviews: Self.Subviews, cache: inout Self.Cache) -> CGSize

    /// Assigns positions to each of the layout's subviews.
    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Self.Subviews, cache: inout Self.Cache)

    /// Returns the preferred spacing values of the composite view.
    func spacing(subviews: Self.Subviews, cache: inout Self.Cache) -> ViewSpacing

    /// Returns the position of the specified horizontal alignment guide along
    /// the x axis.
    func explicitAlignment(
        of guide: HorizontalAlignment,
        in bounds: CGRect,
        proposal: ProposedViewSize,
        subviews: Self.Subviews,
        cache: inout Self.Cache
    ) -> CGFloat?

    /// Returns the position of the specified vertical alignment guide along
    /// the y axis.
    func explicitAlignment(
        of guide: VerticalAlignment,
        in bounds: CGRect,
        proposal: ProposedViewSize,
        subviews: Self.Subviews,
        cache: inout Self.Cache
    ) -> CGFloat?

    /// Creates and initializes a cache for a layout instance.
    func makeCache(subviews: Self.Subviews) -> Self.Cache

    /// Updates the layout's cache when something changes.
    func updateCache(_ cache: inout Self.Cache, subviews: Self.Subviews)
}

extension Layout {

    public static var layoutProperties: LayoutProperties {
        LayoutProperties()
    }

    public func updateCache(_ cache: inout Self.Cache, subviews: Self.Subviews) {
        cache = makeCache(subviews: subviews)
    }

    /// Merges the spacing preferences of every subview on every edge.
    public func spacing(subviews: Self.Subviews, cache: inout Self.Cache) -> ViewSpacing {
        guard let first = subviews.first else {
            return ViewSpacing()
        }
        var spacing = first.spacing
        for subview in subviews.dropFirst() {
            spacing.formUnion(subview.spacing)
        }
        return spacing
    }

    public func explicitAlignment(
        of guide: HorizontalAlignment,
        in bounds: CGRect,
        proposal: ProposedViewSize,
        subviews: Self.Subviews,
        cache: inout Self.Cache
    ) -> CGFloat? {
        nil
    }

    public func explicitAlignment(
        of guide: VerticalAlignment,
        in bounds: CGRect,
        proposal: ProposedViewSize,
        subviews: Self.Subviews,
        cache: inout Self.Cache
    ) -> CGFloat? {
        nil
    }
}

extension Layout where Self.Cache == () {

    public func makeCache(subviews: Self.Subviews) -> Self.Cache {
        ()
    }
}

extension Layout {

    /// Combines the specified views into a single composite view using the
    /// layout algorithms of the custom layout container.
    public func callAsFunction<V: View>(@ViewBuilder _ content: () -> V) -> some View {
        _LayoutView(layout: self, content: content())
    }
}

// MARK: - LayoutProperties

/// Layout-specific properties of a layout container.
public struct LayoutProperties: Sendable {

    /// The orientation of the containing stack-like container, which
    /// spacers and dividers use to decide their own axis.
    public var stackOrientation: Axis?

    public init() {
        self.stackOrientation = nil
    }
}

// MARK: - LayoutValueKey

/// A key for accessing a layout value of a layout container's subviews.
public protocol LayoutValueKey {

    /// The type of the key's value.
    associatedtype Value

    /// The default value of the key.
    static var defaultValue: Self.Value { get }
}

// MARK: - LayoutSubviews

/// A collection of proxy values that represent the subviews of a layout view.
public struct LayoutSubviews: Equatable, RandomAccessCollection {

    public typealias Element = LayoutSubview

    public typealias Index = Int

    public typealias SubSequence = LayoutSubviews

    internal let storage: [LayoutSubview]

    public let startIndex: Int

    public let endIndex: Int

    /// The layout direction inherited by the container view.
    public var layoutDirection: LayoutDirection

    internal init(_ subviews: [LayoutSubview], layoutDirection: LayoutDirection = .leftToRight) {
        self.storage = subviews
        self.startIndex = subviews.startIndex
        self.endIndex = subviews.endIndex
        self.layoutDirection = layoutDirection
    }

    private init(storage: [LayoutSubview], bounds: Range<Int>, layoutDirection: LayoutDirection) {
        self.storage = storage
        self.startIndex = bounds.lowerBound
        self.endIndex = bounds.upperBound
        self.layoutDirection = layoutDirection
    }

    public subscript(index: Int) -> LayoutSubview {
        storage[index]
    }

    public subscript(bounds: Range<Int>) -> LayoutSubviews {
        LayoutSubviews(storage: storage, bounds: bounds, layoutDirection: layoutDirection)
    }

    public static func == (lhs: LayoutSubviews, rhs: LayoutSubviews) -> Bool {
        Array(lhs) == Array(rhs)
    }

    internal var proxies: [LayoutProxy] {
        map(\.proxy)
    }
}

// MARK: - LayoutSubview

/// A proxy that represents one subview of a layout.
public struct LayoutSubview: Equatable {

    internal let proxy: LayoutProxy

    private let identity: ObjectIdentifier?

    private let index: Int

    @MainActor
    internal init(proxy: LayoutProxy, index: Int) {
        self.proxy = proxy
        self.identity = proxy.identity
        self.index = index
    }

    /// Asks the subview for its size.
    @MainActor
    public func sizeThatFits(_ proposal: ProposedViewSize) -> CGSize {
        proxy.size(in: proposal)
    }

    /// Asks the subview for its dimensions and alignment guides.
    @MainActor
    public func dimensions(in proposal: ProposedViewSize) -> ViewDimensions {
        proxy.dimensions(in: proposal)
    }

    /// Assigns a position and proposed size to the subview.
    @MainActor
    public func place(
        at position: CGPoint,
        anchor: UnitPoint = .topLeading,
        proposal: ProposedViewSize
    ) {
        let size = proxy.size(in: proposal)
        proxy.place(
            at: CGPoint(x: position.x - anchor.x * size.width, y: position.y - anchor.y * size.height),
            proposal: proposal
        )
    }

    /// The layout priority of the subview.
    @MainActor
    public var priority: Double {
        proxy.priority
    }

    /// The subview's spacing preferences.
    @MainActor
    public var spacing: ViewSpacing {
        proxy.spacing
    }

    /// Gets the value for the subview that's associated with the specified key.
    @MainActor
    public subscript<K: LayoutValueKey>(key: K.Type) -> K.Value {
        proxy.traits[key]
    }

    public static func == (lhs: LayoutSubview, rhs: LayoutSubview) -> Bool {
        lhs.identity == rhs.identity && lhs.index == rhs.index
    }
}

// MARK: - Layout behavior

/// Runs a `Layout` for a node, keeping its cache for the layout pass.
internal struct LayoutBehavior<L: Layout>: NodeBehavior {

    let layout: L

    private func subviews(of node: ViewNode) -> LayoutSubviews {
        LayoutSubviews(
            node.layoutChildren.enumerated().map { LayoutSubview(proxy: $0.element, index: $0.offset) },
            layoutDirection: node.environment.layoutDirection
        )
    }

    private func withCache<Result>(
        node: ViewNode,
        subviews: LayoutSubviews,
        _ body: (inout L.Cache) -> Result
    ) -> Result {
        // The node resets its layout cache at the start of each layout pass.
        var cache = (node.layoutCache as? L.Cache) ?? layout.makeCache(subviews: subviews)
        let result = body(&cache)
        node.layoutCache = cache
        return result
    }

    func sizeThatFits(_ proposal: ProposedViewSize, node: ViewNode) -> CGSize {
        let subviews = subviews(of: node)
        return withCache(node: node, subviews: subviews) { cache in
            layout.sizeThatFits(proposal: proposal, subviews: subviews, cache: &cache)
        }
    }

    func placeChildren(in bounds: CGRect, proposal: ProposedViewSize, node: ViewNode) {
        let subviews = subviews(of: node)
        withCache(node: node, subviews: subviews) { cache in
            layout.placeSubviews(in: bounds, proposal: proposal, subviews: subviews, cache: &cache)
        }
    }

    func spacing(node: ViewNode) -> ViewSpacing {
        let subviews = subviews(of: node)
        return withCache(node: node, subviews: subviews) { cache in
            layout.spacing(subviews: subviews, cache: &cache)
        }
    }

    func explicitAlignment(
        _ key: AlignmentKey,
        size: CGSize,
        proposal: ProposedViewSize,
        node: ViewNode
    ) -> CGFloat? {
        let subviews = subviews(of: node)
        let bounds = CGRect(origin: .zero, size: size)
        return withCache(node: node, subviews: subviews) { cache in
            switch key.axis {
            case .horizontal:
                layout.explicitAlignment(
                    of: HorizontalAlignment(key.id),
                    in: bounds,
                    proposal: proposal,
                    subviews: subviews,
                    cache: &cache
                )
            case .vertical:
                layout.explicitAlignment(
                    of: VerticalAlignment(key.id),
                    in: bounds,
                    proposal: proposal,
                    subviews: subviews,
                    cache: &cache
                )
            }
        }
    }
}

/// A view that lays out its content with a `Layout`.
internal struct _LayoutView<L: Layout, Content: View>: View, PrimitiveView {

    let layout: L

    let content: Content

    func resolve(in context: ResolveContext) -> Resolution {
        var environment = context.environment
        environment.stackOrientation = L.layoutProperties.stackOrientation
        return Resolution(
            behavior: LayoutBehavior(layout: layout),
            children: [ChildView(key: 0, view: content, environment: environment)]
        )
    }

    typealias Body = Never
}

// MARK: - AnyLayout

/// A type-erased instance of the layout protocol.
public struct AnyLayout: Layout {

    /// The cached values of the wrapped layout.
    public struct Cache {
        internal var value: Any
    }

    private let box: any AnyLayoutBox

    /// Creates a type-erased value that wraps the specified layout.
    public init<L: Layout>(_ layout: L) {
        if let layout = layout as? AnyLayout {
            self.box = layout.box
        } else {
            self.box = ConcreteLayoutBox(layout: layout)
        }
    }

    public func makeCache(subviews: Subviews) -> Cache {
        Cache(value: box.makeCache(subviews: subviews))
    }

    public func updateCache(_ cache: inout Cache, subviews: Subviews) {
        box.updateCache(&cache.value, subviews: subviews)
    }

    public func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout Cache) -> CGSize {
        box.sizeThatFits(proposal: proposal, subviews: subviews, cache: &cache.value)
    }

    public func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout Cache) {
        box.placeSubviews(in: bounds, proposal: proposal, subviews: subviews, cache: &cache.value)
    }

    public func spacing(subviews: Subviews, cache: inout Cache) -> ViewSpacing {
        box.spacing(subviews: subviews, cache: &cache.value)
    }

    public func explicitAlignment(
        of guide: HorizontalAlignment,
        in bounds: CGRect,
        proposal: ProposedViewSize,
        subviews: Subviews,
        cache: inout Cache
    ) -> CGFloat? {
        box.explicitAlignment(of: guide, in: bounds, proposal: proposal, subviews: subviews, cache: &cache.value)
    }

    public func explicitAlignment(
        of guide: VerticalAlignment,
        in bounds: CGRect,
        proposal: ProposedViewSize,
        subviews: Subviews,
        cache: inout Cache
    ) -> CGFloat? {
        box.explicitAlignment(of: guide, in: bounds, proposal: proposal, subviews: subviews, cache: &cache.value)
    }
}

@MainActor
private protocol AnyLayoutBox {

    func makeCache(subviews: LayoutSubviews) -> Any

    func updateCache(_ cache: inout Any, subviews: LayoutSubviews)

    func sizeThatFits(proposal: ProposedViewSize, subviews: LayoutSubviews, cache: inout Any) -> CGSize

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: LayoutSubviews, cache: inout Any)

    func spacing(subviews: LayoutSubviews, cache: inout Any) -> ViewSpacing

    func explicitAlignment(
        of guide: HorizontalAlignment,
        in bounds: CGRect,
        proposal: ProposedViewSize,
        subviews: LayoutSubviews,
        cache: inout Any
    ) -> CGFloat?

    func explicitAlignment(
        of guide: VerticalAlignment,
        in bounds: CGRect,
        proposal: ProposedViewSize,
        subviews: LayoutSubviews,
        cache: inout Any
    ) -> CGFloat?
}

private struct ConcreteLayoutBox<L: Layout>: AnyLayoutBox {

    let layout: L

    private func with<Result>(_ cache: inout Any, subviews: LayoutSubviews, _ body: (inout L.Cache) -> Result) -> Result {
        var typed = (cache as? L.Cache) ?? layout.makeCache(subviews: subviews)
        let result = body(&typed)
        cache = typed
        return result
    }

    func makeCache(subviews: LayoutSubviews) -> Any {
        layout.makeCache(subviews: subviews)
    }

    func updateCache(_ cache: inout Any, subviews: LayoutSubviews) {
        with(&cache, subviews: subviews) { layout.updateCache(&$0, subviews: subviews) }
    }

    func sizeThatFits(proposal: ProposedViewSize, subviews: LayoutSubviews, cache: inout Any) -> CGSize {
        with(&cache, subviews: subviews) { layout.sizeThatFits(proposal: proposal, subviews: subviews, cache: &$0) }
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: LayoutSubviews, cache: inout Any) {
        with(&cache, subviews: subviews) { layout.placeSubviews(in: bounds, proposal: proposal, subviews: subviews, cache: &$0) }
    }

    func spacing(subviews: LayoutSubviews, cache: inout Any) -> ViewSpacing {
        with(&cache, subviews: subviews) { layout.spacing(subviews: subviews, cache: &$0) }
    }

    func explicitAlignment(
        of guide: HorizontalAlignment,
        in bounds: CGRect,
        proposal: ProposedViewSize,
        subviews: LayoutSubviews,
        cache: inout Any
    ) -> CGFloat? {
        with(&cache, subviews: subviews) {
            layout.explicitAlignment(of: guide, in: bounds, proposal: proposal, subviews: subviews, cache: &$0)
        }
    }

    func explicitAlignment(
        of guide: VerticalAlignment,
        in bounds: CGRect,
        proposal: ProposedViewSize,
        subviews: LayoutSubviews,
        cache: inout Any
    ) -> CGFloat? {
        with(&cache, subviews: subviews) {
            layout.explicitAlignment(of: guide, in: bounds, proposal: proposal, subviews: subviews, cache: &$0)
        }
    }
}
