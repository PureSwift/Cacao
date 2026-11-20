//
//  GeometryReader.swift
//  Cacao
//
//  Created by Alsey Coleman Miller on 11/13/26.
//

import CacaoRender
import Foundation
#if canImport(CoreGraphics)
import CoreGraphics
#endif

// MARK: - GeometryProxy

/// A proxy for access to the size and coordinate space (for anchor
/// resolution) of the container view.
///
/// Reading geometry from a proxy records the read: when the container's
/// layout changes what a read would return, the container evaluates its
/// content again.
@MainActor
public struct GeometryProxy {

    let state: GeometryState

    weak var node: ViewNode?

    /// The size of the container view.
    public var size: CGSize {
        state.size
    }

    /// The safe area inset of the container view.
    public var safeAreaInsets: EdgeInsets {
        record { proxy in
            guard let node = proxy.node else { return [0, 0, 0, 0] }
            let insets = node.safeAreaInsets
            return [Double(insets.top), Double(insets.leading), Double(insets.bottom), Double(insets.trailing)]
        }.map { EdgeInsets(top: $0[0], leading: $0[1], bottom: $0[2], trailing: $0[3]) } ?? EdgeInsets()
    }

    /// Returns the container view's bounds rectangle, converted to a
    /// defined coordinate space.
    public func frame(in coordinateSpace: some CoordinateSpaceProtocol) -> CGRect {
        frame(in: coordinateSpace.coordinateSpace)
    }

    /// Returns the container view's bounds rectangle, converted to a
    /// defined coordinate space.
    public func frame(in coordinateSpace: CoordinateSpace) -> CGRect {
        let values = record { proxy in
            guard let node = proxy.node else { return [0, 0, 0, 0] }
            return node.frame(in: coordinateSpace, size: proxy.state.size).components
        }
        return values.map(CGRect.init(components:)) ?? CGRect(origin: CGPoint(x: 0, y: 0), size: size)
    }

    /// Returns the given coordinate space's bounds rectangle, converted to
    /// the local coordinate space.
    public func bounds(of coordinateSpace: NamedCoordinateSpace) -> CGRect? {
        let values = record { proxy -> [Double] in
            guard let node = proxy.node, let space = node.namedSpace(coordinateSpace.name) else { return [] }
            let origin = node.windowFrame.origin
            return space.windowFrame.offsetBy(dx: -origin.x, dy: -origin.y).components
        }
        guard let values, values.count == 4 else { return nil }
        return CGRect(components: values)
    }

    /// Resolves the value of an anchor to the container view.
    public subscript<T>(anchor: Anchor<T>) -> T {
        let values = record { proxy -> [Double] in
            guard let node = proxy.node else { return [] }
            return anchor.frame(relativeTo: node).components
        }
        let frame = values.flatMap { $0.count == 4 ? CGRect(components: $0) : nil }
            ?? node.map { anchor.frame(relativeTo: $0) }
            ?? .zero
        return anchor.source.make(frame)
    }

    /// Reads values from the container's geometry now, and again after
    /// each of its layouts.
    private func record(_ read: @escaping @MainActor (GeometryProxy) -> [Double]) -> [Double]? {
        let value = read(self)
        state.reads.append((read, value))
        return value
    }
}

/// What a geometry reader knows of its layout.
@MainActor
internal final class GeometryState {

    var size: CGSize = .zero

    /// Values read from a proxy, to read again after layout.
    var reads: [(read: @MainActor (GeometryProxy) -> [Double], value: [Double])] = []

    static func of(_ node: ViewNode) -> GeometryState {
        if let state = node.dynamicStorage["geometry"] as? GeometryState {
            return state
        }
        let state = GeometryState()
        node.dynamicStorage["geometry"] = state
        return state
    }

    /// Whether anything read from a proxy changed with the node's layout.
    func hasChanges(proxy: GeometryProxy) -> Bool {
        reads.contains { $0.read(proxy) != $0.value }
    }
}

extension ViewNode {

    /// The node's frame in a coordinate space, for a node of `size`.
    func frame(in space: CoordinateSpace, size: CGSize) -> CGRect {
        // Before its first layout, a view is at the origin.
        var window = windowFrame
        if window.isNull {
            window = CGRect(origin: CGPoint(x: 0, y: 0), size: size)
        }
        switch space {
        case .global:
            return window
        case .local:
            return CGRect(origin: CGPoint(x: 0, y: 0), size: size)
        case let .named(name):
            guard let named = namedSpace(name) else { return window }
            let space = named.windowFrame
            guard !space.isNull else { return window }
            return window.offsetBy(dx: -space.minX, dy: -space.minY)
        }
    }

    /// The nearest ancestor, or this node, with a coordinate space name.
    func namedSpace(_ name: AnyHashable) -> ViewNode? {
        var node: ViewNode? = self
        while let current = node {
            if current.attributes.coordinateSpaceName == name {
                return current
            }
            node = current.parent
        }
        return nil
    }

    /// How far the window's safe area reaches into the node's frame.
    var safeAreaInsets: EdgeInsets {
        let insets = graph.safeAreaInsets
        let window = windowFrame
        let safe = CGRect(
            x: insets.leading,
            y: insets.top,
            width: graph.size.width - insets.leading - insets.trailing,
            height: graph.size.height - insets.top - insets.bottom
        )
        return EdgeInsets(
            top: max(safe.minY - window.minY, 0),
            leading: max(safe.minX - window.minX, 0),
            bottom: max(window.maxY - safe.maxY, 0),
            trailing: max(window.maxX - safe.maxX, 0)
        )
    }
}

// MARK: - GeometryReader

/// A container view that defines its content as a function of its own size
/// and coordinate space.
public struct GeometryReader<Content: View>: View, PrimitiveView {

    public var content: (GeometryProxy) -> Content

    public init(@ViewBuilder content: @escaping (GeometryProxy) -> Content) {
        self.content = content
    }

    public typealias Body = Never

    func resolve(in context: ResolveContext) -> Resolution {
        let state = GeometryState.of(context.node)
        state.reads.removeAll()
        let proxy = GeometryProxy(state: state, node: context.node)
        return Resolution(
            behavior: GeometryReaderBehavior(),
            children: [ChildView(key: 0, view: ZStack(alignment: .topLeading) { content(proxy) })]
        )
    }
}

internal struct GeometryReaderBehavior: NodeBehavior {

    /// A geometry reader takes the space it's offered.
    func sizeThatFits(_ proposal: ProposedViewSize, node: ViewNode) -> CGSize {
        proposal.replacingUnspecifiedDimensions()
    }

    func placeChildren(in bounds: CGRect, proposal: ProposedViewSize, node: ViewNode) {
        let state = GeometryState.of(node)
        if let content = LayoutProxy.combining(node.layoutChildren) {
            content.place(at: bounds.origin, proposal: ProposedViewSize(bounds.size))
        }
        // Evaluates the content again for a new size, or new geometry it read.
        let proxy = GeometryProxy(state: state, node: node)
        if state.size != bounds.size {
            state.size = bounds.size
            node.invalidate()
        } else if !state.reads.isEmpty {
            node.graph.afterLayout { [weak node] in
                guard let node, node.isAttached, state.hasChanges(proxy: proxy) else { return }
                node.invalidate()
            }
        }
    }
}

// MARK: - onGeometryChange

internal struct _GeometryChangeModifier<T: Equatable>: ViewModifier, PrimitiveViewModifier {

    let transform: (GeometryProxy) -> T

    let action: (T, T) -> Void

    func resolve(content: any View, in context: ResolveContext) -> Resolution {
        Resolution(
            behavior: GeometryChangeBehavior(transform: transform, action: action),
            children: [ChildView(key: 0, view: content)]
        )
    }

    typealias Body = Never
}

/// Lays out its child as is, and reports a value of its geometry when it
/// changes, after layout.
internal struct GeometryChangeBehavior<T: Equatable>: UnaryLayoutBehavior {

    let transform: (GeometryProxy) -> T

    let action: (T, T) -> Void

    func sizeThatFits(_ proposal: ProposedViewSize, child: LayoutProxy) -> CGSize {
        child.size(in: proposal)
    }

    func placement(of child: LayoutProxy, size: CGSize, proposal: ProposedViewSize) -> (proposal: ProposedViewSize, origin: CGPoint) {
        (proposal, CGPoint(x: 0, y: 0))
    }

    func placeChildren(in bounds: CGRect, proposal: ProposedViewSize, node: ViewNode) {
        if let child = LayoutProxy.combining(node.layoutChildren) {
            child.place(at: bounds.origin, proposal: proposal)
        }
        let transform = self.transform, action = self.action
        node.graph.afterLayout { [weak node] in
            guard let node, node.isAttached else { return }
            let state = GeometryState.of(node)
            state.size = node.frame.size
            let value = transform(GeometryProxy(state: state, node: node))
            let key = "geometryChange"
            let old = (node.dynamicStorage[key] as? StorageBox<T>)?.value
            node.dynamicStorage[key] = StorageBox(value)
            if let old, old != value {
                action(old, value)
            } else if old == nil {
                // SwiftUI reports the first value too.
                action(value, value)
            }
        }
    }
}

extension View {

    /// Adds an action to be performed when a value, created from a
    /// geometry proxy, changes.
    public func onGeometryChange<T: Equatable>(
        for type: T.Type,
        of transform: @escaping (GeometryProxy) -> T,
        action: @escaping (T) -> Void
    ) -> some View {
        modifier(_GeometryChangeModifier(transform: transform) { _, new in action(new) })
    }

    /// Adds an action to be performed when a value, created from a
    /// geometry proxy, changes.
    public func onGeometryChange<T: Equatable>(
        for type: T.Type,
        of transform: @escaping (GeometryProxy) -> T,
        action: @escaping (T, T) -> Void
    ) -> some View {
        modifier(_GeometryChangeModifier(transform: transform, action: action))
    }
}

// MARK: - Anchors

/// An opaque value derived from an anchor source and a particular view.
public struct Anchor<Value>: Equatable, @unchecked Sendable {

    /// A type-erased geometry value that produces an anchored value of a
    /// given type.
    public struct Source: @unchecked Sendable {

        /// The value from the view's frame in a coordinate space.
        let make: @Sendable (CGRect) -> Value

        /// What the source is, to compare anchors.
        let key: AnyHashable
    }

    let nodeID: Int

    weak var node: ViewNode?

    let source: Source

    public static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.nodeID == rhs.nodeID && lhs.source.key == rhs.source.key
    }

    /// The anchored view's frame, relative to another view's.
    @MainActor
    func frame(relativeTo other: ViewNode) -> CGRect {
        guard let node, node.isAttached else { return .zero }
        let frame = node.windowFrame, base = other.windowFrame
        guard !frame.isNull, !base.isNull else { return .zero }
        return frame.offsetBy(dx: -base.minX, dy: -base.minY)
    }
}

extension Anchor.Source where Value == CGRect {

    /// The view's bounds.
    public static var bounds: Anchor<CGRect>.Source {
        Anchor<CGRect>.Source(make: { $0 }, key: "bounds")
    }

    /// A rectangle in the view's coordinate space.
    public static func rect(_ r: CGRect) -> Anchor<CGRect>.Source {
        Anchor<CGRect>.Source(
            make: { CGRect(x: $0.minX + r.minX, y: $0.minY + r.minY, width: r.width, height: r.height) },
            key: AnyHashable(r.components)
        )
    }
}

extension Anchor.Source where Value == CGPoint {

    /// A point in the view's coordinate space.
    public static func point(_ p: CGPoint) -> Anchor<CGPoint>.Source {
        Anchor<CGPoint>.Source(make: { CGPoint(x: $0.minX + p.x, y: $0.minY + p.y) }, key: AnyHashable([Double(p.x), Double(p.y)]))
    }

    /// A unit point of the view's bounds.
    public static func unitPoint(_ p: UnitPoint) -> Anchor<CGPoint>.Source {
        Anchor<CGPoint>.Source(
            make: { CGPoint(x: $0.minX + $0.width * p.x, y: $0.minY + $0.height * p.y) },
            key: AnyHashable("unit \(p.x) \(p.y)")
        )
    }

    public static var topLeading: Anchor<CGPoint>.Source { unitPoint(.topLeading) }
    public static var top: Anchor<CGPoint>.Source { unitPoint(.top) }
    public static var topTrailing: Anchor<CGPoint>.Source { unitPoint(.topTrailing) }
    public static var leading: Anchor<CGPoint>.Source { unitPoint(.leading) }
    public static var center: Anchor<CGPoint>.Source { unitPoint(.center) }
    public static var trailing: Anchor<CGPoint>.Source { unitPoint(.trailing) }
    public static var bottomLeading: Anchor<CGPoint>.Source { unitPoint(.bottomLeading) }
    public static var bottom: Anchor<CGPoint>.Source { unitPoint(.bottom) }
    public static var bottomTrailing: Anchor<CGPoint>.Source { unitPoint(.bottomTrailing) }
}

internal struct _AnchorPreferenceModifier<A, Key: PreferenceKey>: ViewModifier, PrimitiveViewModifier {

    let source: Anchor<A>.Source

    let transform: (Anchor<A>) -> Key.Value

    func resolve(content: any View, in context: ResolveContext) -> Resolution {
        let node = context.node
        let anchor = Anchor<A>(nodeID: node.id, node: node, source: source)
        var attributes = NodeAttributes()
        attributes.preference = PreferenceValue(keyID: ObjectIdentifier(Key.self), value: transform(anchor))
        return Resolution(children: [ChildView(key: 0, view: content)], attributes: attributes)
    }

    typealias Body = Never
}

extension View {

    /// Sets a value for the specified preference key, the value is a
    /// function of a geometry value tied to the current coordinate space.
    public func anchorPreference<A, K: PreferenceKey>(
        key: K.Type = K.self,
        value: Anchor<A>.Source,
        transform: @escaping (Anchor<A>) -> K.Value
    ) -> some View {
        modifier(_AnchorPreferenceModifier<A, K>(source: value, transform: transform))
    }

    /// Reads the specified preference value from the view, using it to
    /// produce a second view that is applied as an overlay to the original view.
    public func overlayPreferenceValue<K: PreferenceKey, V: View>(
        _ key: K.Type,
        alignment: Alignment = .center,
        @ViewBuilder _ transform: @escaping (K.Value) -> V
    ) -> some View {
        overlay(alignment: alignment) { _PreferenceReader<K, V>(transform: transform) }
            .modifier(_PreferenceSourceModifier())
    }

    /// Reads the specified preference value from the view, using it to
    /// produce a second view that is applied as the background of the
    /// original view.
    public func backgroundPreferenceValue<K: PreferenceKey, V: View>(
        _ key: K.Type,
        alignment: Alignment = .center,
        @ViewBuilder _ transform: @escaping (K.Value) -> V
    ) -> some View {
        background(alignment: alignment) { _PreferenceReader<K, V>(transform: transform) }
            .modifier(_PreferenceSourceModifier())
    }
}

/// Marks where a preference reader finds the views it reads from.
internal struct _PreferenceSourceModifier: ViewModifier, PrimitiveViewModifier {

    func resolve(content: any View, in context: ResolveContext) -> Resolution {
        var attributes = NodeAttributes()
        attributes.isPreferenceSource = true
        return Resolution(children: [ChildView(key: 0, view: content)], attributes: attributes)
    }

    typealias Body = Never
}

/// A view made from a preference value of the view it overlays or backs.
internal struct _PreferenceReader<Key: PreferenceKey, Content: View>: View, PrimitiveView {

    let transform: (Key.Value) -> Content

    typealias Body = Never

    func resolve(in context: ResolveContext) -> Resolution {
        let node = context.node
        // The overlaid or backed view: the other child of the overlay layout.
        var value = Key.defaultValue
        var ancestor = node.parent
        while let current = ancestor, !current.attributes.isPreferenceSource {
            ancestor = current.parent
        }
        if let source = ancestor, let layout = source.firstNode(where: { $0.behavior != nil }) {
            let siblings = layout.children.filter { !$0.contains(node) }
            value = PreferenceKeyInfo(Key.self).value(siblings) as? Key.Value ?? Key.defaultValue
        }
        // Read again when the value changes.
        let info = PreferenceKeyInfo(Key.self)
        let last = value
        node.graph.observeUpdates(of: node) { [weak node] in
            guard let node, node.isAttached, let source = ancestor,
                  let layout = source.firstNode(where: { $0.behavior != nil }) else { return }
            let siblings = layout.children.filter { !$0.contains(node) }
            let current = info.value(siblings)
            if !Self.isEqual(current, last) {
                node.invalidate()
            }
        }
        return Resolution(children: [ChildView(key: 0, view: transform(value))])
    }

    private static func isEqual(_ lhs: Any, _ rhs: Key.Value) -> Bool {
        guard let lhs = lhs as? Key.Value else { return false }
        return equal(lhs, rhs)
    }

    private static func equal(_ lhs: Key.Value, _ rhs: Key.Value) -> Bool {
        if let lhs = lhs as? any Equatable {
            return lhs.isEqual(to: rhs)
        }
        // Without equality, the value is read once per update.
        return true
    }
}

private extension Equatable {

    func isEqual(to other: Any) -> Bool {
        guard let other = other as? Self else { return false }
        return self == other
    }
}

extension ViewNode {

    /// Whether a node is this node or one of its descendants.
    func contains(_ node: ViewNode) -> Bool {
        var current: ViewNode? = node
        while let candidate = current {
            if candidate === self { return true }
            current = candidate.parent
        }
        return false
    }
}

// MARK: - ViewThatFits

/// A view that adapts to the available space by providing the first child
/// view that fits.
public struct ViewThatFits<Content: View>: View, PrimitiveView {

    let axes: Axis.Set

    let content: Content

    /// Produces a view constrained in the given axes from a list of candidate
    /// views.
    public init(in axes: Axis.Set = [.horizontal, .vertical], @ViewBuilder content: () -> Content) {
        self.axes = axes
        self.content = content()
    }

    public typealias Body = Never

    func resolve(in context: ResolveContext) -> Resolution {
        let rows = FlattenedRows(content)
        let children = (0..<rows.rowCount).map { index -> ChildView in
            let row = rows.row(at: index)
            return ChildView(key: row.id, view: row.view)
        }
        return Resolution(behavior: ViewThatFitsBehavior(axes: axes), children: children)
    }
}

internal struct ViewThatFitsBehavior: NodeBehavior {

    let axes: Axis.Set

    /// The index of the first candidate whose ideal size fits the proposal
    /// along the axes, or the last.
    private func choice(_ proposal: ProposedViewSize, node: ViewNode) -> Int {
        let count = node.children.count
        guard count > 1 else { return 0 }
        for index in 0..<(count - 1) {
            guard let child = LayoutProxy.combining(node.layoutChildren(ofChildAt: index)) else { continue }
            let ideal = child.size(in: ProposedViewSize(
                width: axes.contains(.horizontal) ? nil : proposal.width,
                height: axes.contains(.vertical) ? nil : proposal.height
            ))
            let fitsWidth = !axes.contains(.horizontal) || proposal.width.map { ideal.width <= $0 + 0.001 } ?? true
            let fitsHeight = !axes.contains(.vertical) || proposal.height.map { ideal.height <= $0 + 0.001 } ?? true
            if fitsWidth && fitsHeight {
                return index
            }
        }
        return count - 1
    }

    func sizeThatFits(_ proposal: ProposedViewSize, node: ViewNode) -> CGSize {
        let index = choice(proposal, node: node)
        return LayoutProxy.combining(node.layoutChildren(ofChildAt: index))?.size(in: proposal) ?? .zero
    }

    func placeChildren(in bounds: CGRect, proposal: ProposedViewSize, node: ViewNode) {
        let index = choice(proposal, node: node)
        node.dynamicStorage["viewThatFits"] = StorageBox(index)
        for other in node.children.indices where other != index {
            LayoutProxy.combining(node.layoutChildren(ofChildAt: other))?
                .place(at: bounds.origin, proposal: ProposedViewSize(width: 0, height: 0))
        }
        guard let child = LayoutProxy.combining(node.layoutChildren(ofChildAt: index)) else { return }
        let size = child.size(in: proposal)
        child.place(
            at: CGPoint(x: bounds.minX + (bounds.width - size.width) / 2, y: bounds.minY + (bounds.height - size.height) / 2),
            proposal: proposal
        )
    }

    /// Only the chosen candidate draws and takes hits.
    func displayOrder(of children: [ViewNode]) -> [ViewNode] {
        guard let parent = children.first?.parent, let index = (parent.dynamicStorage["viewThatFits"] as? StorageBox<Int>)?.value,
              children.indices.contains(index) else {
            return Array(children.prefix(1))
        }
        return [children[index]]
    }
}

// MARK: - zIndex

internal struct ZIndexKey: LayoutValueKey {
    static let defaultValue: Double = 0
}

extension View {

    /// Controls the display order of overlapping views.
    public func zIndex(_ value: Double) -> some View {
        modifier(_AttributesModifier { $0.traits[ZIndexKey.self] = value })
    }
}

extension ViewNode {

    /// The node's display order of its children: its behavior's, then by
    /// z-index, front-most last.
    var orderedChildren: [ViewNode] {
        let ordered = behavior?.displayOrder(of: children) ?? children
        guard ordered.contains(where: { $0.zIndex != 0 }) else { return ordered }
        return ordered.enumerated()
            .sorted { ($0.element.zIndex, $0.offset) < ($1.element.zIndex, $1.offset) }
            .map(\.element)
    }

    /// The z-index set on the node or the transparent nodes it wraps.
    var zIndex: Double {
        if let value = attributes.traits.values[ObjectIdentifier(ZIndexKey.self)] as? Double {
            return value
        }
        guard behavior == nil, children.count == 1 else { return 0 }
        return children[0].zIndex
    }
}

// MARK: - position

internal struct _PositionLayout: ViewModifier, LayoutModifier {

    let position: CGPoint

    var behavior: any NodeBehavior { PositionBehavior(position: position) }

    typealias Body = Never
}

/// Takes the space offered, and centers the child at a point in it.
internal struct PositionBehavior: UnaryLayoutBehavior {

    let position: CGPoint

    func sizeThatFits(_ proposal: ProposedViewSize, child: LayoutProxy) -> CGSize {
        proposal.replacingUnspecifiedDimensions()
    }

    func placement(of child: LayoutProxy, size: CGSize, proposal: ProposedViewSize) -> (proposal: ProposedViewSize, origin: CGPoint) {
        let childSize = child.size(in: ProposedViewSize(size))
        return (ProposedViewSize(size), CGPoint(x: position.x - childSize.width / 2, y: position.y - childSize.height / 2))
    }
}

extension View {

    /// Positions the center of this view at the specified point in its
    /// parent's coordinate space.
    public func position(_ position: CGPoint) -> some View {
        modifier(_PositionLayout(position: position))
    }

    /// Positions the center of this view at the specified coordinates in
    /// its parent's coordinate space.
    public func position(x: CGFloat = 0, y: CGFloat = 0) -> some View {
        position(CGPoint(x: x, y: y))
    }
}

// MARK: - Safe area

/// A set of symbolic safe area regions.
public struct SafeAreaRegions: OptionSet, Sendable {

    public let rawValue: UInt

    public init(rawValue: UInt) {
        self.rawValue = rawValue
    }

    /// The safe area defined by the device and containers within the user
    /// interface.
    public static let container = SafeAreaRegions(rawValue: 1)

    /// The safe area matching the current extent of any software keyboard.
    public static let keyboard = SafeAreaRegions(rawValue: 2)

    /// All safe area regions.
    public static let all: SafeAreaRegions = [.container, .keyboard]
}

internal struct _IgnoresSafeAreaLayout: ViewModifier, LayoutModifier {

    let edges: Edge.Set

    var behavior: any NodeBehavior { IgnoresSafeAreaBehavior(edges: edges) }

    typealias Body = Never
}

/// Sizes like its child, then extends the child into the window's safe
/// area insets on the edges where it reaches them.
internal struct IgnoresSafeAreaBehavior: NodeBehavior {

    let edges: Edge.Set

    func sizeThatFits(_ proposal: ProposedViewSize, node: ViewNode) -> CGSize {
        LayoutProxy.combining(node.layoutChildren)?.size(in: proposal) ?? .zero
    }

    func placeChildren(in bounds: CGRect, proposal: ProposedViewSize, node: ViewNode) {
        guard let child = LayoutProxy.combining(node.layoutChildren) else { return }
        let insets = node.graph.safeAreaInsets
        let window = node.graph.size
        var frame = bounds
        if edges.contains(.top), bounds.minY <= insets.top + 0.5 {
            frame.size.height += frame.minY
            frame.origin.y = 0
        }
        if edges.contains(.leading), bounds.minX <= insets.leading + 0.5 {
            frame.size.width += frame.minX
            frame.origin.x = 0
        }
        if edges.contains(.bottom), bounds.maxY >= window.height - insets.bottom - 0.5 {
            frame.size.height = window.height - frame.minY
        }
        if edges.contains(.trailing), bounds.maxX >= window.width - insets.trailing - 0.5 {
            frame.size.width = window.width - frame.minX
        }
        child.place(at: frame.origin, proposal: ProposedViewSize(frame.size))
    }
}

internal struct _SafeAreaInsetLayout: ViewModifier, LayoutModifier {

    let edge: Edge

    let spacing: CGFloat?

    var behavior: any NodeBehavior { SafeAreaInsetBehavior(edge: edge, spacing: spacing ?? 0) }

    typealias Body = Never
}

/// Places the inset content along an edge, and the main content in the
/// rest of the space.
internal struct SafeAreaInsetBehavior: NodeBehavior {

    let edge: Edge

    let spacing: CGFloat

    private var axis: Axis {
        edge == .top || edge == .bottom ? .vertical : .horizontal
    }

    private func parts(_ node: ViewNode) -> (content: LayoutProxy?, inset: LayoutProxy?) {
        (LayoutProxy.combining(node.layoutChildren(ofChildAt: 0)), LayoutProxy.combining(node.layoutChildren(ofChildAt: 1)))
    }

    private func insetSize(_ inset: LayoutProxy?, proposal: ProposedViewSize) -> CGSize {
        guard let inset else { return .zero }
        return inset.size(in: axis == .vertical
            ? ProposedViewSize(width: proposal.width, height: nil)
            : ProposedViewSize(width: nil, height: proposal.height))
    }

    func sizeThatFits(_ proposal: ProposedViewSize, node: ViewNode) -> CGSize {
        let (content, inset) = parts(node)
        let insetSize = insetSize(inset, proposal: proposal)
        let length = insetSize[axis] + (inset == nil ? 0 : spacing)
        var remaining = proposal
        if axis == .vertical {
            remaining.height = proposal.height.map { max($0 - length, 0) }
        } else {
            remaining.width = proposal.width.map { max($0 - length, 0) }
        }
        let contentSize = content?.size(in: remaining) ?? .zero
        return axis == .vertical
            ? CGSize(width: max(contentSize.width, insetSize.width), height: contentSize.height + length)
            : CGSize(width: contentSize.width + length, height: max(contentSize.height, insetSize.height))
    }

    func placeChildren(in bounds: CGRect, proposal: ProposedViewSize, node: ViewNode) {
        let (content, inset) = parts(node)
        let size = insetSize(inset, proposal: ProposedViewSize(bounds.size))
        let length = size[axis] + (inset == nil ? 0 : spacing)
        var contentFrame = bounds
        var insetOrigin = bounds.origin
        switch edge {
        case .top:
            contentFrame.origin.y += length
            contentFrame.size.height -= length
        case .bottom:
            contentFrame.size.height -= length
            insetOrigin.y = bounds.maxY - size.height
        case .leading:
            contentFrame.origin.x += length
            contentFrame.size.width -= length
        case .trailing:
            contentFrame.size.width -= length
            insetOrigin.x = bounds.maxX - size.width
        }
        content?.place(at: contentFrame.origin, proposal: ProposedViewSize(contentFrame.size))
        inset?.place(
            at: insetOrigin,
            proposal: axis == .vertical
                ? ProposedViewSize(width: bounds.width, height: size.height)
                : ProposedViewSize(width: size.width, height: bounds.height)
        )
    }
}

internal struct _SafeAreaInsetView<Content: View, Inset: View>: View, PrimitiveView {

    let content: Content

    let edge: Edge

    let spacing: CGFloat?

    let inset: Inset

    typealias Body = Never

    func resolve(in context: ResolveContext) -> Resolution {
        Resolution(
            behavior: SafeAreaInsetBehavior(edge: edge, spacing: spacing ?? 0),
            children: [ChildView(key: 0, view: content), ChildView(key: 1, view: inset)]
        )
    }
}

extension View {

    /// Expands the safe area of a view.
    public func ignoresSafeArea(_ regions: SafeAreaRegions = .all, edges: Edge.Set = .all) -> some View {
        modifier(_IgnoresSafeAreaLayout(edges: edges))
    }

    /// Changes the view's proposed area to extend outside the screen's safe areas.
    @available(*, deprecated, renamed: "ignoresSafeArea(_:edges:)")
    public func edgesIgnoringSafeArea(_ edges: Edge.Set) -> some View {
        ignoresSafeArea(.all, edges: edges)
    }

    /// Shows the specified content beside the modified view, along a
    /// vertical edge.
    public func safeAreaInset<V: View>(
        edge: VerticalEdge,
        alignment: HorizontalAlignment = .center,
        spacing: CGFloat? = nil,
        @ViewBuilder content: () -> V
    ) -> some View {
        _SafeAreaInsetView(content: self, edge: edge == .top ? .top : .bottom, spacing: spacing, inset: content())
    }

    /// Shows the specified content beside the modified view, along a
    /// horizontal edge.
    public func safeAreaInset<V: View>(
        edge: HorizontalEdge,
        alignment: VerticalAlignment = .center,
        spacing: CGFloat? = nil,
        @ViewBuilder content: () -> V
    ) -> some View {
        _SafeAreaInsetView(content: self, edge: edge == .leading ? .leading : .trailing, spacing: spacing, inset: content())
    }

    /// Adds the provided insets into the safe area of this view.
    public func safeAreaPadding(_ insets: EdgeInsets) -> some View {
        padding(insets)
    }

    /// Adds the provided insets into the safe area of this view.
    public func safeAreaPadding(_ edges: Edge.Set = .all, _ length: CGFloat? = nil) -> some View {
        padding(edges, length)
    }

    /// Adds the provided insets into the safe area of this view.
    public func safeAreaPadding(_ length: CGFloat) -> some View {
        padding(length)
    }
}

/// A vertical edge.
public enum VerticalEdge: Int8, CaseIterable, Hashable, Sendable {
    case top
    case bottom
}

/// A horizontal edge.
public enum HorizontalEdge: Int8, CaseIterable, Hashable, Sendable {
    case leading
    case trailing
}

/// A value kept in a node's storage.
internal final class StorageBox<Value> {

    var value: Value

    init(_ value: Value) {
        self.value = value
    }
}
