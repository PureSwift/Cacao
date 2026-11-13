//
//  Grid.swift
//  Cacao
//
//  Created by Alsey Coleman Miller on 11/13/26.
//

import Foundation
#if canImport(CoreGraphics)
import CoreGraphics
#endif

// MARK: - GridItem

/// A description of a row or a column in a lazy grid.
public struct GridItem: Sendable {

    /// The size in the minor axis of one or more rows or columns in a grid
    /// layout.
    public enum Size: Sendable {
        /// A single item with the specified fixed size.
        case fixed(CGFloat)
        /// A single flexible item.
        case flexible(minimum: CGFloat = 10, maximum: CGFloat = .infinity)
        /// Multiple items in the space of a single flexible item.
        case adaptive(minimum: CGFloat, maximum: CGFloat = .infinity)
    }

    /// The size of the item.
    public var size: Size

    /// The spacing to the next item.
    public var spacing: CGFloat?

    /// The alignment to use when placing each view.
    public var alignment: Alignment?

    public init(_ size: Size = .flexible(), spacing: CGFloat? = nil, alignment: Alignment? = nil) {
        self.size = size
        self.spacing = spacing
        self.alignment = alignment
    }
}

/// A resolved track of a lazy grid: its length and the spacing after it.
internal struct GridTrack: Equatable {
    var length: CGFloat
    var spacing: CGFloat
    var alignment: Alignment
}

extension Array where Element == GridItem {

    /// The tracks for an available length: fixed items first, then flexible
    /// and adaptive items share the rest, and adaptive items fit as many
    /// tracks as their minimum allows.
    func tracks(in length: CGFloat, defaultAlignment: Alignment) -> [GridTrack] {
        guard !isEmpty else { return [] }
        let spacings = indices.map { index in index < count - 1 ? (self[index].spacing ?? defaultSpacing) : 0 }
        var remaining = length - spacings.reduce(0, +)
        var flexibleCount = 0
        for item in self {
            if case let .fixed(size) = item.size {
                remaining -= size
            } else {
                flexibleCount += 1
            }
        }
        let share = flexibleCount > 0 ? Swift.max(remaining, 0) / CGFloat(flexibleCount) : 0
        var tracks: [GridTrack] = []
        for (index, item) in enumerated() {
            let alignment = item.alignment ?? defaultAlignment
            switch item.size {
            case let .fixed(size):
                tracks.append(GridTrack(length: size, spacing: spacings[index], alignment: alignment))
            case let .flexible(minimum, maximum):
                tracks.append(GridTrack(length: Swift.min(Swift.max(share, minimum), maximum), spacing: spacings[index], alignment: alignment))
            case let .adaptive(minimum, maximum):
                let spacing = item.spacing ?? defaultSpacing
                let count = Swift.max(1, Int(((share + spacing) / (minimum + spacing)).rounded(.down)))
                let size = Swift.min((share - CGFloat(count - 1) * spacing) / CGFloat(count), maximum)
                for column in 0..<count {
                    tracks.append(GridTrack(
                        length: Swift.max(size, minimum),
                        spacing: column < count - 1 ? spacing : spacings[index],
                        alignment: alignment
                    ))
                }
            }
        }
        return tracks
    }
}

// MARK: - Lazy grids

/// A container view that arranges its child views in a grid that grows
/// vertically, creating items only as needed.
public struct LazyVGrid<Content: View>: View, PrimitiveView {

    internal let columns: [GridItem]

    internal let alignment: HorizontalAlignment

    internal let spacing: CGFloat?

    internal let content: Content

    public init(
        columns: [GridItem],
        alignment: HorizontalAlignment = .center,
        spacing: CGFloat? = nil,
        pinnedViews: PinnedScrollableViews = .init(),
        @ViewBuilder content: () -> Content
    ) {
        self.columns = columns
        self.alignment = alignment
        self.spacing = spacing
        self.content = content()
    }

    public typealias Body = Never

    func resolve(in context: ResolveContext) -> Resolution {
        LazyGrid(axis: .vertical, tracks: columns, spacing: spacing, alignment: Alignment(horizontal: alignment, vertical: .center))
            .resolve(content: content, in: context)
    }
}

/// A container view that arranges its child views in a grid that grows
/// horizontally, creating items only as needed.
public struct LazyHGrid<Content: View>: View, PrimitiveView {

    internal let rows: [GridItem]

    internal let alignment: VerticalAlignment

    internal let spacing: CGFloat?

    internal let content: Content

    public init(
        rows: [GridItem],
        alignment: VerticalAlignment = .center,
        spacing: CGFloat? = nil,
        pinnedViews: PinnedScrollableViews = .init(),
        @ViewBuilder content: () -> Content
    ) {
        self.rows = rows
        self.alignment = alignment
        self.spacing = spacing
        self.content = content()
    }

    public typealias Body = Never

    func resolve(in context: ResolveContext) -> Resolution {
        LazyGrid(axis: .horizontal, tracks: rows, spacing: spacing, alignment: Alignment(horizontal: .center, vertical: alignment))
            .resolve(content: content, in: context)
    }
}

/// A lazy grid: a lazy stack along its axis whose rows are lines of items,
/// as many as the tracks across fit.
@MainActor
internal struct LazyGrid {

    let axis: Axis

    let tracks: [GridItem]

    let spacing: CGFloat?

    let alignment: Alignment

    func resolve(content: any View, in context: ResolveContext) -> Resolution {
        let node = context.node
        let state = LazyStack.state(of: node)
        // The length across, from the last layout, or the window's.
        let window = axis == .vertical ? context.graph.size.width : context.graph.size.height
        let across = state.crossLength ?? (window > 0 ? window : 600)
        let resolved = tracks.tracks(in: across, defaultAlignment: alignment)
        state.gridTracks = tracks
        state.trackCount = resolved.count
        let lines = _GridLines(items: FlattenedRows(content), perLine: max(resolved.count, 1), tracks: tracks, axis: axis, alignment: alignment)
        return LazyStack(axis: axis, alignment: (axis == .vertical ? alignment.horizontal.key : alignment.vertical.key), spacing: spacing, rowTransform: nil)
            .resolve(content: lines, in: context)
    }
}

/// The lines of a lazy grid, each one row (or column) of items.
internal struct _GridLines: View, PrimitiveView, LazyRowSource {

    let items: FlattenedRows

    let perLine: Int

    let tracks: [GridItem]

    let axis: Axis

    let alignment: Alignment

    var rowCount: Int {
        (items.rowCount + perLine - 1) / perLine
    }

    func row(at index: Int) -> (id: AnyHashable, view: any View) {
        let range = (index * perLine)..<min((index + 1) * perLine, items.rowCount)
        let cells = range.map { AnyView(items.row(at: $0).view) }
        let ids = range.map { items.id(at: $0) }
        return (AnyHashable(ids), _GridLine(cells: cells, ids: ids, tracks: tracks, axis: axis, alignment: alignment))
    }

    func id(at index: Int) -> AnyHashable {
        let range = (index * perLine)..<min((index + 1) * perLine, items.rowCount)
        return AnyHashable(range.map { items.id(at: $0) })
    }

    func resolve(in context: ResolveContext) -> Resolution {
        Resolution()
    }

    typealias Body = Never
}

/// One line of a lazy grid: its cells placed in the grid's tracks.
internal struct _GridLine: View {

    let cells: [AnyView]

    let ids: [AnyHashable]

    let tracks: [GridItem]

    let axis: Axis

    let alignment: Alignment

    var body: some View {
        _GridLineLayout(tracks: tracks, axis: axis, alignment: alignment) {
            ForEach(cells.indices, id: \.self) { index in
                cells[index].id(ids[index])
            }
        }
    }
}

/// Places a line's cells in the tracks resolved for its length across.
internal struct _GridLineLayout: Layout {

    let tracks: [GridItem]

    let axis: Axis

    let alignment: Alignment

    private func resolved(_ length: CGFloat) -> [GridTrack] {
        tracks.tracks(in: length, defaultAlignment: alignment)
    }

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout Void) -> CGSize {
        let cross = axis.other
        let across = proposal[cross].flatMap { $0.isFinite ? $0 : nil } ?? 300
        let tracks = resolved(across)
        var along: CGFloat = 0
        for (subview, track) in zip(subviews, tracks) {
            let size = subview.sizeThatFits(ProposedViewSize(nil, in: axis, by: track.length))
            along = max(along, size[axis])
        }
        let total = tracks.reduce(0) { $0 + $1.length + $1.spacing }
        return CGSize(along, in: axis, by: max(across, total))
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout Void) {
        let cross = axis.other
        let tracks = resolved(bounds.size[cross])
        var position = cross == .horizontal ? bounds.minX : bounds.minY
        for (subview, track) in zip(subviews, tracks) {
            let cellProposal = ProposedViewSize(nil, in: axis, by: track.length)
            let dimensions = subview.dimensions(in: cellProposal)
            let cell = CGSize(bounds.size[axis], in: axis, by: track.length)
            let container = ViewDimensions(size: cell)
            let origin = CGPoint(
                x: container[track.alignment.horizontal] - dimensions[track.alignment.horizontal],
                y: container[track.alignment.vertical] - dimensions[track.alignment.vertical]
            )
            let base = cross == .horizontal ? CGPoint(x: position, y: bounds.minY) : CGPoint(x: bounds.minX, y: position)
            subview.place(at: CGPoint(x: base.x + origin.x, y: base.y + origin.y), proposal: cellProposal)
            position += track.length + track.spacing
        }
    }
}

// MARK: - Grid

/// A container view that arranges other views in a two dimensional layout.
///
/// Columns are as wide as their widest cell, rows as tall as their tallest;
/// views outside of a `GridRow` span every column.
public struct Grid<Content: View>: View, PrimitiveView {

    internal let alignment: Alignment

    internal let horizontalSpacing: CGFloat?

    internal let verticalSpacing: CGFloat?

    internal let content: Content

    public init(
        alignment: Alignment = .center,
        horizontalSpacing: CGFloat? = nil,
        verticalSpacing: CGFloat? = nil,
        @ViewBuilder content: () -> Content
    ) {
        self.alignment = alignment
        self.horizontalSpacing = horizontalSpacing
        self.verticalSpacing = verticalSpacing
        self.content = content()
    }

    public typealias Body = Never

    func resolve(in context: ResolveContext) -> Resolution {
        Resolution(
            behavior: GridBehavior(
                alignment: alignment,
                horizontalSpacing: horizontalSpacing ?? defaultSpacing,
                verticalSpacing: verticalSpacing ?? defaultSpacing
            ),
            children: [ChildView(key: 0, view: content)]
        )
    }
}

/// A horizontal row in a two dimensional grid container.
public struct GridRow<Content: View>: View, PrimitiveView {

    internal let alignment: VerticalAlignment?

    internal let content: Content

    public init(alignment: VerticalAlignment? = nil, @ViewBuilder content: () -> Content) {
        self.alignment = alignment
        self.content = content()
    }

    public typealias Body = Never

    func resolve(in context: ResolveContext) -> Resolution {
        Resolution(behavior: GridRowBehavior(alignment: alignment), children: [ChildView(key: 0, view: content)])
    }
}

/// Marks a grid row; its grid lays out its cells.
internal struct GridRowBehavior: NodeBehavior {

    let alignment: VerticalAlignment?

    func sizeThatFits(_ proposal: ProposedViewSize, node: ViewNode) -> CGSize {
        // Alone, outside a grid, a row is a horizontal stack.
        StackAlgorithm(axis: .horizontal, alignment: (alignment ?? .center).key, uniformSpacing: nil, children: node.layoutChildren)
            .size(in: proposal)
    }

    func placeChildren(in bounds: CGRect, proposal: ProposedViewSize, node: ViewNode) {
        guard node.parentGridPlacesCells == false else { return }
        StackAlgorithm(axis: .horizontal, alignment: (alignment ?? .center).key, uniformSpacing: nil, children: node.layoutChildren)
            .place(in: bounds, proposal: proposal)
    }
}

internal struct GridBehavior: NodeBehavior {

    let alignment: Alignment

    let horizontalSpacing: CGFloat

    let verticalSpacing: CGFloat

    /// The grid's rows: cells of a `GridRow`, or one spanning view.
    private struct Row {
        var proxy: LayoutProxy
        var cells: [LayoutProxy]?
        var alignment: VerticalAlignment?
    }

    private func rows(_ node: ViewNode) -> [Row] {
        node.layoutChildren.map { proxy in
            if case let .node(rowNode) = proxy.storage, let behavior = rowNode.behavior as? GridRowBehavior {
                return Row(proxy: proxy, cells: rowNode.layoutChildren, alignment: behavior.alignment)
            }
            return Row(proxy: proxy, cells: nil, alignment: nil)
        }
    }

    /// Column widths and row heights at the cells' ideal sizes.
    private func measure(_ rows: [Row]) -> (columns: [CGFloat], heights: [CGFloat]) {
        var columns: [CGFloat] = []
        var heights: [CGFloat] = []
        for row in rows {
            guard let cells = row.cells else {
                heights.append(0)
                continue
            }
            var height: CGFloat = 0
            for (index, cell) in cells.enumerated() {
                let size = cell.size(in: .unspecified)
                if columns.count <= index { columns.append(0) }
                columns[index] = max(columns[index], size.width)
                height = max(height, size.height)
            }
            heights.append(height)
        }
        return (columns, heights)
    }

    private func width(_ columns: [CGFloat]) -> CGFloat {
        columns.reduce(0, +) + CGFloat(max(columns.count - 1, 0)) * horizontalSpacing
    }

    func sizeThatFits(_ proposal: ProposedViewSize, node: ViewNode) -> CGSize {
        let rows = rows(node)
        var (columns, heights) = measure(rows)
        var gridWidth = width(columns)
        for (index, row) in rows.enumerated() where row.cells == nil {
            let size = row.proxy.size(in: ProposedViewSize(width: proposal.width ?? gridWidth, height: nil))
            heights[index] = size.height
            gridWidth = max(gridWidth, size.width)
        }
        if columns.isEmpty, proposal.width == nil {
            columns = []
        }
        let height = heights.reduce(0, +) + CGFloat(max(heights.count - 1, 0)) * verticalSpacing
        return CGSize(width: gridWidth, height: height)
    }

    func placeChildren(in bounds: CGRect, proposal: ProposedViewSize, node: ViewNode) {
        let rows = rows(node)
        let (columns, heights) = measure(rows)
        var y = bounds.minY
        for (index, row) in rows.enumerated() {
            if let cells = row.cells, case let .node(rowNode) = row.proxy.storage {
                let height = heights[index]
                rowNode.parentGridPlacesCells = true
                rowNode.place(at: CGPoint(x: bounds.minX, y: y), proposal: ProposedViewSize(width: bounds.width, height: height))
                var x = bounds.minX
                for (column, cell) in cells.enumerated() {
                    let cellSize = CGSize(width: columns[column], height: height)
                    let dimensions = cell.dimensions(in: .unspecified)
                    let container = ViewDimensions(size: cellSize)
                    let vertical = row.alignment ?? alignment.vertical
                    cell.place(
                        at: CGPoint(
                            x: x + container[alignment.horizontal] - dimensions[alignment.horizontal],
                            y: y + container[vertical] - dimensions[vertical]
                        ),
                        proposal: .unspecified
                    )
                    x += columns[column] + horizontalSpacing
                }
                y += height + verticalSpacing
            } else {
                let size = row.proxy.size(in: ProposedViewSize(width: bounds.width, height: nil))
                row.proxy.place(at: CGPoint(x: bounds.minX, y: y), proposal: ProposedViewSize(width: bounds.width, height: nil))
                y += size.height + verticalSpacing
            }
        }
    }
}

extension ViewNode {

    /// Whether a grid places this row's cells itself.
    var parentGridPlacesCells: Bool {
        get { (dynamicStorage["gridPlaced"] as? ValueBox<Bool>)?.value ?? false }
        set { dynamicStorage["gridPlaced"] = ValueBox(newValue) }
    }
}
