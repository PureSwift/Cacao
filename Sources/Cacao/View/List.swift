//
//  List.swift
//  Cacao
//
//  Created by Alsey Coleman Miller on 11/13/26.
//

import CacaoRender
import Foundation
#if canImport(CoreGraphics)
import CoreGraphics
#endif

/// A container that presents rows of data arranged in a single column,
/// optionally providing the ability to select one member.
///
/// Rows are created as they scroll into view, so lists of any length cost
/// only what's visible.
public struct List<SelectionValue: Hashable, Content: View>: View {

    internal let content: Content

    internal let selection: Binding<SelectionValue?>?

    /// Creates a list with the given content that supports selecting a
    /// single row; rows are identified by their `ForEach` identity or `tag`.
    public init(selection: Binding<SelectionValue?>?, @ViewBuilder content: () -> Content) {
        self.selection = selection
        self.content = content()
    }

    @Environment(\.listStyleKind) private var style

    @Environment(\.scrollContentBackgroundVisibility) private var backgroundVisibility

    @Environment(\.colorScheme) private var colorScheme

    public var body: some View {
        ScrollView {
            _ListRows(content: content, style: style, selection: selection.map { binding in
                Binding<AnyHashable?>(
                    get: { binding.wrappedValue.map(AnyHashable.init) },
                    set: { binding.wrappedValue = $0?.base as? SelectionValue }
                )
            })
            .padding(.vertical, style.isGrouped ? 8 : 0)
        }
        .background(style.isGrouped && backgroundVisibility != .hidden ? Color.groupedBackground(colorScheme) : Color.clear)
    }
}

extension List where SelectionValue == Never {

    /// Creates a list with the given content.
    public init(@ViewBuilder content: () -> Content) {
        self.selection = nil
        self.content = content()
    }

    /// Creates a list that computes its rows on demand from an underlying
    /// collection of identifiable data.
    public init<Data: RandomAccessCollection, RowContent: View>(
        _ data: Data,
        @ViewBuilder rowContent: @escaping (Data.Element) -> RowContent
    ) where Content == ForEach<Data, Data.Element.ID, RowContent>, Data.Element: Identifiable {
        self.init { ForEach(data, content: rowContent) }
    }

    /// Creates a list that identifies its rows based on a key path to the
    /// identifier of the underlying data.
    public init<Data: RandomAccessCollection, ID: Hashable, RowContent: View>(
        _ data: Data,
        id: KeyPath<Data.Element, ID>,
        @ViewBuilder rowContent: @escaping (Data.Element) -> RowContent
    ) where Content == ForEach<Data, ID, RowContent> {
        self.init { ForEach(data, id: id, content: rowContent) }
    }

    /// Creates a list that computes its views on demand over a constant range.
    public init<RowContent: View>(
        _ data: Range<Int>,
        @ViewBuilder rowContent: @escaping (Int) -> RowContent
    ) where Content == ForEach<Range<Int>, Int, RowContent> {
        self.init { ForEach(data, content: rowContent) }
    }
}

extension List {

    /// Creates a list that computes its rows on demand from identifiable
    /// data, optionally allowing users to select a single row.
    public init<Data: RandomAccessCollection, RowContent: View>(
        _ data: Data,
        selection: Binding<SelectionValue?>?,
        @ViewBuilder rowContent: @escaping (Data.Element) -> RowContent
    ) where Content == ForEach<Data, Data.Element.ID, RowContent>, Data.Element: Identifiable {
        self.init(selection: selection) { ForEach(data, content: rowContent) }
    }

    /// Creates a list that identifies its rows based on a key path to the
    /// identifier of the underlying data, optionally allowing users to select
    /// a single row.
    public init<Data: RandomAccessCollection, ID: Hashable, RowContent: View>(
        _ data: Data,
        id: KeyPath<Data.Element, ID>,
        selection: Binding<SelectionValue?>?,
        @ViewBuilder rowContent: @escaping (Data.Element) -> RowContent
    ) where Content == ForEach<Data, ID, RowContent> {
        self.init(selection: selection) { ForEach(data, id: id, content: rowContent) }
    }
}

/// Where a row of a list is: a section's header or footer, or a row, and
/// whether it's its section's first or last row.
internal struct ListRowPosition: Equatable {
    var kind: RowKind
    var isFirst: Bool
    var isLast: Bool
}

/// The styles of lists Cacao draws.
internal enum ListStyleKind: Equatable, Sendable {
    case automatic
    case plain
    case inset
    case grouped
    case insetGrouped
    case sidebar

    /// Whether rows sit on cards in sections, over a grouped background.
    var isGrouped: Bool {
        self == .grouped || self == .insetGrouped
    }

    /// The space between rows and the list's sides.
    var margin: CGFloat {
        switch self {
        case .automatic, .plain, .grouped: 0
        case .inset, .sidebar: 8
        case .insetGrouped: 16
        }
    }

    /// The space around a row's content.
    var rowInsets: EdgeInsets {
        switch self {
        case .sidebar: EdgeInsets(top: 6, leading: 10, bottom: 6, trailing: 10)
        default: EdgeInsets(top: 10, leading: 16, bottom: 10, trailing: 16)
        }
    }

    var showsSeparators: Bool {
        self != .sidebar
    }

    /// The corner radius of a selected row's highlight.
    var highlightRadius: CGFloat {
        switch self {
        case .inset, .sidebar: 6
        default: 0
        }
    }
}

/// The rows of a list, created lazily, each wrapped as a list row.
internal struct _ListRows<Content: View>: View, PrimitiveView {

    let content: Content

    let style: ListStyleKind

    let selection: Binding<AnyHashable?>?

    func resolve(in context: ResolveContext) -> Resolution {
        let selection = self.selection, style = self.style
        // A split view's sidebar tells it whether a row is selected: when
        // it's collapsed to one column, that's when its detail shows.
        if let selection, let navigation = context.environment.navigationContext, !navigation.isDetail,
           let link = navigation.split {
            let isEmpty = selection.wrappedValue == nil
            let changed = link.sidebarSelection?.isEmpty != isEmpty
            link.sidebarSelection = (isEmpty, { selection.wrappedValue = nil })
            if changed, navigation.isCollapsed {
                navigation.onChange()
            }
        }
        let margin = style.margin + (style.isGrouped ? 4 : 0)
        return LazyStack(axis: .vertical, alignment: HorizontalAlignment.leading.key, spacing: 0, rowTransform: { view, id, position -> any View in
            switch position.kind {
            case .row:
                return _ListRow(content: AnyView(view), id: id, selection: selection, style: style, position: position)
            case .header:
                return AnyView(view)
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 16 + margin)
                    .padding(.top, style == .sidebar ? 12 : 18)
                    .padding(.bottom, 6)
            case .footer:
                return AnyView(view)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 16 + margin)
                    .padding(.vertical, 6)
            }
        })
        .resolve(content: content, in: context)
    }

    typealias Body = Never
}

/// What a row's views ask of the list: set with `listRowBackground`,
/// `listRowInsets` and `listRowSeparator`.
internal struct ListRowTraits: Equatable {

    var background: AnyView?

    /// A way to tell backgrounds apart: equal when the views are equal, or
    /// of the same type when they can't be compared.
    var backgroundIdentity: AnyHashable?

    var insets: EdgeInsets?

    var hiddenSeparators: VerticalEdge.Set?

    var separatorTint: Color?

    var badge: Text?

    static func == (lhs: ListRowTraits, rhs: ListRowTraits) -> Bool {
        lhs.backgroundIdentity == rhs.backgroundIdentity && (lhs.background == nil) == (rhs.background == nil)
            && lhs.insets == rhs.insets && lhs.hiddenSeparators?.rawValue == rhs.hiddenSeparators?.rawValue
            && lhs.separatorTint == rhs.separatorTint && lhs.badge == rhs.badge
    }

    /// This row's traits, with any that aren't set taken from `other`.
    func merging(_ other: ListRowTraits) -> ListRowTraits {
        var result = self
        if result.background == nil {
            result.background = other.background
            result.backgroundIdentity = other.backgroundIdentity
        }
        result.insets = result.insets ?? other.insets
        result.hiddenSeparators = result.hiddenSeparators ?? other.hiddenSeparators
        result.separatorTint = result.separatorTint ?? other.separatorTint
        result.badge = result.badge ?? other.badge
        return result
    }
}

/// The traits of a list row, from its views.
internal enum ListRowTraitsKey: PreferenceKey {

    static var defaultValue: ListRowTraits { ListRowTraits() }

    static func reduce(value: inout ListRowTraits, nextValue: () -> ListRowTraits) {
        value = value.merging(nextValue())
    }
}

/// A list row: its content with the row's insets, background and
/// highlight when selected, then its separator.
internal struct _ListRow: View {

    let content: AnyView

    let id: AnyHashable

    let selection: Binding<AnyHashable?>?

    let style: ListStyleKind

    let position: ListRowPosition

    @State private var traits = ListRowTraits()

    var body: some View {
        let isSelected = selection?.wrappedValue == id
        let insets = traits.insets ?? style.rowInsets
        let hidesSeparator = traits.hiddenSeparators?.contains(.bottom) ?? false
        let showsSeparator = style.showsSeparators && !hidesSeparator && !(style.isGrouped && position.isLast)
        let traits = $traits
        VStack(alignment: .leading, spacing: 0) {
            _ListRowContent(content: content, badge: self.traits.badge)
                .padding(insets)
                .background(_ListRowFill(
                    background: self.traits.background,
                    highlight: isSelected ? Color.accentColor.opacity(0.2) : nil,
                    radius: style.highlightRadius
                ))
                .contentShape(Rectangle())
                .modifier(_SelectionTap(id: id, selection: selection))
            if showsSeparator {
                Divider(tint: self.traits.separatorTint)
                    .padding(.leading, insets.leading)
            }
        }
        .modifier(_ListRowChrome(style: style, position: position))
        .onPreferenceChange(ListRowTraitsKey.self) { value in
            if traits.wrappedValue != value {
                traits.wrappedValue = value
            }
        }
    }
}

/// A row's content, and its badge at the trailing edge when it has one.
/// The content keeps its identity whether there's a badge or not.
private struct _ListRowContent: View, PrimitiveView {

    let content: AnyView

    let badge: Text?

    func resolve(in context: ResolveContext) -> Resolution {
        let content = self.content.frame(maxWidth: .infinity, minHeight: 24, alignment: .leading)
        guard let badge else {
            return Resolution(children: [ChildView(key: "content", view: content)])
        }
        var environment = context.environment
        environment.stackOrientation = .horizontal
        return Resolution(
            behavior: LayoutBehavior(layout: HStackLayout(alignment: .center, spacing: 8)),
            children: [
                ChildView(key: "content", view: content, environment: environment),
                ChildView(key: "badge", view: badge.font(.callout).foregroundStyle(.secondary), environment: environment),
            ]
        )
    }

    typealias Body = Never
}

/// What's behind a row's content: its custom background, then its
/// selection highlight. Adds views only for the layers there are.
private struct _ListRowFill: View, PrimitiveView {

    let background: AnyView?

    let highlight: Color?

    let radius: CGFloat

    func resolve(in context: ResolveContext) -> Resolution {
        let highlight = self.highlight.map { RoundedRectangle(cornerRadius: radius).fill($0) }
        switch (background, highlight) {
        case let (background?, highlight?):
            return Resolution(children: [ChildView(key: "both", view: ZStack { background; highlight })])
        case let (background?, nil):
            return Resolution(children: [ChildView(key: "background", view: background)])
        case let (nil, highlight?):
            return Resolution(children: [ChildView(key: "highlight", view: highlight)])
        case (nil, nil):
            return Resolution()
        }
    }

    typealias Body = Never
}

/// A row's card in a grouped list, rounded at its section's ends, and its
/// margins: nothing in plain lists.
private struct _ListRowChrome: ViewModifier, PrimitiveViewModifier {

    let style: ListStyleKind

    let position: ListRowPosition

    func resolve(content: any View, in context: ResolveContext) -> Resolution {
        guard style.isGrouped || style.margin > 0 else {
            return Resolution(children: [ChildView(key: 0, view: content)])
        }
        var row = AnyView(_fromValue: content)!
        if style.isGrouped {
            let radius: CGFloat = style == .insetGrouped ? 10 : 0
            let card = UnevenRoundedRectangle(
                topLeadingRadius: position.isFirst ? radius : 0,
                bottomLeadingRadius: position.isLast ? radius : 0,
                bottomTrailingRadius: position.isLast ? radius : 0,
                topTrailingRadius: position.isFirst ? radius : 0
            )
            .fill(Color.controlBackground(context.environment.colorScheme))
            row = AnyView(row.background(card))
        }
        return Resolution(children: [ChildView(key: 0, view: row.padding(.horizontal, style.margin))])
    }

    typealias Body = Never
}

/// Selects a row when tapped, in a list with selection.
internal struct _SelectionTap: ViewModifier, PrimitiveViewModifier {

    let id: AnyHashable

    let selection: Binding<AnyHashable?>?

    func resolve(content: any View, in context: ResolveContext) -> Resolution {
        var attributes = NodeAttributes()
        if let selection {
            let id = self.id
            attributes.tap = TapHandler(action: { selection.wrappedValue = id })
        }
        return Resolution(children: [ChildView(key: 0, view: content)], attributes: attributes)
    }

    typealias Body = Never
}
