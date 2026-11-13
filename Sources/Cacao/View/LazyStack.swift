//
//  LazyStack.swift
//  Cacao
//
//  Created by Alsey Coleman Miller on 11/13/26.
//

import Foundation
#if canImport(CoreGraphics)
import CoreGraphics
#endif

// MARK: - Sources

/// Content whose rows a lazy stack can create one at a time.
@MainActor
internal protocol LazyRowSource {

    var rowCount: Int { get }

    /// The identity and view of a row.
    func row(at index: Int) -> (id: AnyHashable, view: any View)

    /// The identity of a row, without making its view.
    func id(at index: Int) -> AnyHashable
}

extension ForEach: LazyRowSource where Content: View {

    var rowCount: Int {
        data.count
    }

    func row(at index: Int) -> (id: AnyHashable, view: any View) {
        let element = data[data.index(data.startIndex, offsetBy: index)]
        return (AnyHashable(identifier(element)), content(element))
    }

    func id(at index: Int) -> AnyHashable {
        AnyHashable(identifier(data[data.index(data.startIndex, offsetBy: index)]))
    }
}

extension TupleView: LazyRowSource {

    var rowCount: Int {
        children.count
    }

    func row(at index: Int) -> (id: AnyHashable, view: any View) {
        (AnyHashable(index), children[index])
    }

    func id(at index: Int) -> AnyHashable {
        AnyHashable(index)
    }
}

// MARK: - Views

/// A view that arranges its children in a line that grows vertically,
/// creating items only as needed.
public struct LazyVStack<Content: View>: View, PrimitiveView {

    internal let alignment: HorizontalAlignment

    internal let spacing: CGFloat?

    internal let content: Content

    public init(
        alignment: HorizontalAlignment = .center,
        spacing: CGFloat? = nil,
        pinnedViews: PinnedScrollableViews = .init(),
        @ViewBuilder content: () -> Content
    ) {
        self.alignment = alignment
        self.spacing = spacing
        self.content = content()
    }

    public typealias Body = Never

    func resolve(in context: ResolveContext) -> Resolution {
        LazyStack(axis: .vertical, alignment: alignment.key, spacing: spacing, rowTransform: nil)
            .resolve(content: content, in: context)
    }
}

/// A view that arranges its children in a line that grows horizontally,
/// creating items only as needed.
public struct LazyHStack<Content: View>: View, PrimitiveView {

    internal let alignment: VerticalAlignment

    internal let spacing: CGFloat?

    internal let content: Content

    public init(
        alignment: VerticalAlignment = .center,
        spacing: CGFloat? = nil,
        pinnedViews: PinnedScrollableViews = .init(),
        @ViewBuilder content: () -> Content
    ) {
        self.alignment = alignment
        self.spacing = spacing
        self.content = content()
    }

    public typealias Body = Never

    func resolve(in context: ResolveContext) -> Resolution {
        LazyStack(axis: .horizontal, alignment: alignment.key, spacing: spacing, rowTransform: nil)
            .resolve(content: content, in: context)
    }
}

/// A set of view types that may be pinned to the bounds of a scroll view.
public struct PinnedScrollableViews: OptionSet, Sendable {

    public let rawValue: UInt32

    public init(rawValue: UInt32) {
        self.rawValue = rawValue
    }

    public static let sectionHeaders = PinnedScrollableViews(rawValue: 1 << 0)

    public static let sectionFooters = PinnedScrollableViews(rawValue: 1 << 1)
}

// MARK: - LazyStack

/// The rows a lazy stack has created, and what it knows of all rows' lengths.
@MainActor
internal final class LazyStackState {

    /// The rows that exist, by index.
    var realized: Range<Int> = 0..<0

    /// The rows that should exist after the next update.
    var requested: Range<Int>?

    /// Whether the next update only changes which rows exist, so existing
    /// rows keep their views.
    var isRangeOnlyUpdate = false

    /// For a lazy grid: its length across, from the last layout.
    var crossLength: CGFloat?

    /// For a lazy grid: its tracks and how many they resolved to.
    var gridTracks: [GridItem]?

    var trackCount = 0

    /// The identity of each row, by index.
    private(set) var ids: [AnyHashable] = []

    /// Measured lengths along the stack's axis, by row identity, which
    /// follow rows when the data changes.
    private var lengthsByID: [AnyHashable: CGFloat] = [:]

    /// Measured lengths by index, or `nil` where not yet measured.
    private var lengths: [CGFloat?] = []

    private var measuredTotal: CGFloat = 0

    private var measuredCount = 0

    /// Row offsets and the total length, until a length changes.
    private var cachedOffsets: (spacing: CGFloat, offsets: [CGFloat])?

    /// Replaces the rows' identities, keeping lengths measured for them.
    func setIDs(_ ids: [AnyHashable]) {
        self.ids = ids
        lengths = ids.map { lengthsByID[$0] }
        measuredCount = 0
        measuredTotal = 0
        for length in lengths {
            if let length {
                measuredCount += 1
                measuredTotal += length
            }
        }
        cachedOffsets = nil
    }

    /// Records a measured row length.
    func setLength(_ length: CGFloat, at index: Int) {
        guard lengths.indices.contains(index), lengths[index] != length else { return }
        if let old = lengths[index] {
            measuredTotal -= old
        } else {
            measuredCount += 1
        }
        measuredTotal += length
        lengths[index] = length
        lengthsByID[ids[index]] = length
        cachedOffsets = nil
    }

    /// The length to assume for rows not yet measured.
    var estimatedLength: CGFloat {
        measuredCount > 0 ? measuredTotal / CGFloat(measuredCount) : 44
    }

    /// Each row's offset along the axis, and the total length last.
    func offsets(spacing: CGFloat) -> [CGFloat] {
        if let cached = cachedOffsets, cached.spacing == spacing {
            return cached.offsets
        }
        let estimate = estimatedLength
        var offsets: [CGFloat] = []
        offsets.reserveCapacity(lengths.count + 1)
        var position: CGFloat = 0
        for (index, length) in lengths.enumerated() {
            offsets.append(position)
            position += (length ?? estimate) + (index < lengths.count - 1 ? spacing : 0)
        }
        offsets.append(position)
        cachedOffsets = (spacing, offsets)
        return offsets
    }
}

/// Describes a lazy stack's node: which rows to create, and its behavior.
@MainActor
internal struct LazyStack {

    /// Rows created before the stack knows its visible area.
    static let initialRows = 32

    /// The most rows created by one update beyond those that are visible.
    static let budget = 48

    let axis: Axis

    let alignment: AlignmentKey

    let spacing: CGFloat?

    /// Wraps each row's view, for lists: given the view, its element's
    /// identity and whether it's a section header, row or footer.
    let rowTransform: ((any View, AnyHashable, RowKind) -> any View)?

    func resolve(content: any View, in context: ResolveContext) -> Resolution {
        let source = FlattenedRows(content)
        let node = context.node
        let state = Self.state(of: node)
        let count = source.rowCount
        var range = state.requested ?? (state.realized.isEmpty ? 0..<min(count, Self.initialRows) : state.realized)
        range = range.clamped(to: 0..<count)
        state.requested = nil
        state.realized = range
        let keepsExisting = state.isRangeOnlyUpdate && !node.wasUpdatedByParent
        state.isRangeOnlyUpdate = false
        // The data can only change when the parent passes a new view.
        if !keepsExisting || state.ids.count != count {
            state.setIDs((0..<count).map { source.id(at: $0) })
        }
        var environment = context.environment
        environment.stackOrientation = axis
        let children = range.map { index -> ChildView in
            let row = source.row(at: index)
            let view = rowTransform.map { $0(row.view, source.elementID(at: index), source.kind(at: index)) } ?? row.view
            return ChildView(key: row.id, view: view, environment: environment)
        }
        var resolution = Resolution(
            behavior: LazyStackBehavior(axis: axis, alignment: alignment, spacing: spacing ?? defaultSpacing, count: count),
            children: children
        )
        resolution.keepsExistingChildren = keepsExisting
        return resolution
    }

    static func state(of node: ViewNode) -> LazyStackState {
        if let state = node.dynamicStorage["lazy"] as? LazyStackState {
            return state
        }
        let state = LazyStackState()
        node.dynamicStorage["lazy"] = state
        node.graph.lazyStacks.append(WeakNodeReference(node))
        return state
    }
}

internal struct LazyStackBehavior: NodeBehavior {

    let axis: Axis

    let alignment: AlignmentKey

    let spacing: CGFloat

    let count: Int

    private var minorAxis: Axis { axis.other }

    /// A realized row's units, measured for a minor-axis proposal.
    private struct Row {
        var units: [(proxy: LayoutProxy, size: CGSize)]
        var length: CGFloat
    }

    private func rows(of node: ViewNode, minor: CGFloat?) -> [Row] {
        node.children.indices.map { index in
            let proposal = ProposedViewSize(nil, in: axis, by: minor)
            let units = node.layoutChildren(ofChildAt: index).map { ($0, $0.size(in: proposal)) }
            let length = units.reduce(0) { $0 + $1.1[axis] } + CGFloat(max(units.count - 1, 0)) * spacing
            return Row(units: units, length: length)
        }
    }

    /// Records realized rows' lengths, and returns every row's offset along
    /// the axis and the total length.
    private func offsets(state: LazyStackState, rows: [Row]) -> (offsets: [CGFloat], total: CGFloat) {
        for (row, index) in zip(rows, state.realized) {
            state.setLength(row.length, at: index)
        }
        let offsets = state.offsets(spacing: spacing)
        return (offsets, offsets.last ?? 0)
    }

    func sizeThatFits(_ proposal: ProposedViewSize, node: ViewNode) -> CGSize {
        let state = LazyStack.state(of: node)
        let rows = rows(of: node, minor: proposal[minorAxis])
        let total = offsets(state: state, rows: rows).total
        let minor = proposal[minorAxis].flatMap { $0.isFinite ? $0 : nil }
            ?? rows.flatMap { $0.units.map { $0.size[minorAxis] } }.max() ?? 0
        return CGSize(total, in: axis, by: minor)
    }

    func placeChildren(in bounds: CGRect, proposal: ProposedViewSize, node: ViewNode) {
        let state = LazyStack.state(of: node)
        let minor = bounds.size[minorAxis]
        let rows = rows(of: node, minor: minor)
        let offsets = offsets(state: state, rows: rows).offsets
        let container = ViewDimensions(size: CGSize(0, in: axis, by: minor))
        for (row, index) in zip(rows, state.realized) {
            var position = offsets[index]
            for unit in row.units {
                let unitProposal = ProposedViewSize(nil, in: axis, by: minor)
                let dimensions = unit.proxy.dimensions(in: unitProposal)
                let minorOrigin = container[alignment] - dimensions[alignment]
                let origin = CGPoint(position, in: axis, by: minorOrigin)
                unit.proxy.place(at: CGPoint(x: bounds.minX + origin.x, y: bounds.minY + origin.y), proposal: unitProposal)
                position += unit.size[axis] + spacing
            }
        }
        node.lazyOffsets = offsets
        // A lazy grid whose track count changes with its length across
        // regroups its items.
        if let tracks = state.gridTracks {
            let across = bounds.size[minorAxis]
            if state.crossLength != across {
                state.crossLength = across
                let count = tracks.tracks(in: across, defaultAlignment: .center).count
                if count != state.trackCount {
                    node.invalidate()
                }
            }
        }
        node.graph.requestLazyRows(node)
    }
}

// MARK: - Realizing rows

extension ViewNode {

    /// The offset of each row of a lazy stack, from its last layout.
    var lazyOffsets: [CGFloat] {
        get { dynamicStorage["lazyOffsets"].flatMap { ($0 as? LazyOffsets)?.values } ?? [] }
        set {
            if let box = dynamicStorage["lazyOffsets"] as? LazyOffsets {
                box.values = newValue
            } else {
                dynamicStorage["lazyOffsets"] = LazyOffsets(newValue)
            }
        }
    }

    /// The part of the window this node's content shows in, in its own
    /// (unscrolled) coordinate space: the innermost scroll view's viewport
    /// moved by its offset, or the window.
    var visibleRect: CGRect {
        var ancestor = parent
        while let node = ancestor {
            if let scroll = node.behavior as? ScrollBehavior {
                let state = scroll.state(of: node)
                return CGRect(
                    x: node.frame.minX + state.offset.x,
                    y: node.frame.minY + state.offset.y,
                    width: node.frame.width,
                    height: node.frame.height
                )
            }
            ancestor = node.parent
        }
        return CGRect(origin: CGPoint(x: 0, y: 0), size: graph.size)
    }
}

private final class LazyOffsets {
    var values: [CGFloat]
    init(_ values: [CGFloat]) { self.values = values }
}

extension WeakNodeReference {

    convenience init(_ node: ViewNode) {
        self.init()
        self.node = node
    }
}

extension ViewGraph {

    /// Asks a lazy stack for the rows its visible area needs, with half a
    /// viewport more on each side, invalidating it if they aren't created.
    func requestLazyRows(_ node: ViewNode) {
        guard let behavior = node.behavior as? LazyStackBehavior, behavior.count > 0 else { return }
        let state = LazyStack.state(of: node)
        let offsets = node.lazyOffsets
        guard offsets.count == behavior.count + 1 else { return }
        let axis = behavior.axis
        let visible = node.visibleRect
        let start = visible.origin[axis] - node.frame.origin[axis]
        let length = visible.size[axis]
        let overscan = length / 2
        func index(at position: CGFloat) -> Int {
            // The last row starting at or before the position.
            var low = 0
            var high = behavior.count - 1
            while low < high {
                let middle = (low + high + 1) / 2
                if offsets[middle] <= position { low = middle } else { high = middle - 1 }
            }
            return low
        }
        let visibleRows = index(at: start)..<(index(at: start + length) + 1)
        // Rows change only when a visible row is missing.
        if state.realized.lowerBound <= visibleRows.lowerBound, visibleRows.upperBound <= state.realized.upperBound {
            return
        }
        var target = index(at: start - overscan)..<(index(at: start + length + overscan) + 1)
        // Create at most the budget of new rows, visible rows first.
        let new = target.filter { !state.realized.contains($0) }.count
        if new > LazyStack.budget {
            target = visibleRows
        }
        guard target != state.realized else { return }
        state.requested = target
        state.isRangeOnlyUpdate = true
        node.invalidate()
    }

    /// Checks every lazy stack after scrolling.
    func scrollDidChange() {
        lazyStacks.removeAll { $0.node == nil || !($0.node!.isAttached) }
        for reference in lazyStacks {
            if let node = reference.node {
                requestLazyRows(node)
            }
        }
    }
}
