//
//  List.swift
//  Cacao
//
//  Created by Alsey Coleman Miller on 11/13/26.
//

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

    public var body: some View {
        ScrollView {
            _ListRows(content: content, selection: selection.map { binding in
                Binding<AnyHashable?>(
                    get: { binding.wrappedValue.map(AnyHashable.init) },
                    set: { binding.wrappedValue = $0?.base as? SelectionValue }
                )
            })
        }
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

/// The rows of a list, created lazily, each wrapped as a list row.
internal struct _ListRows<Content: View>: View, PrimitiveView {

    let content: Content

    let selection: Binding<AnyHashable?>?

    func resolve(in context: ResolveContext) -> Resolution {
        let selection = self.selection
        return LazyStack(axis: .vertical, alignment: HorizontalAlignment.leading.key, spacing: 0, rowTransform: { view, id, kind -> any View in
            switch kind {
            case .row:
                return _ListRow(content: AnyView(view), id: id, selection: selection)
            case .header:
                return AnyView(view)
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 16)
                    .padding(.top, 18)
                    .padding(.bottom, 6)
            case .footer:
                return AnyView(view)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 6)
            }
        })
        .resolve(content: content, in: context)
    }

    typealias Body = Never
}

/// A list row: padded content, a highlight when selected, and a separator.
internal struct _ListRow: View {

    let content: AnyView

    let id: AnyHashable

    let selection: Binding<AnyHashable?>?

    var body: some View {
        let isSelected = selection?.wrappedValue == id
        VStack(alignment: .leading, spacing: 0) {
            content
                .frame(maxWidth: .infinity, minHeight: 24, alignment: .leading)
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(isSelected ? Color.accentColor.opacity(0.2) : Color.clear)
                .contentShape(Rectangle())
                .modifier(_SelectionTap(id: id, selection: selection))
            Divider()
                .padding(.leading, 16)
        }
    }
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
