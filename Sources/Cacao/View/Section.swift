//
//  Section.swift
//  Cacao
//
//  Created by Alsey Coleman Miller on 11/13/26.
//

import CacaoRender
import Foundation
#if canImport(CoreGraphics)
import CoreGraphics
#endif

// MARK: - Section

/// A container view that you can use to add hierarchy within certain views,
/// like lists and forms.
public struct Section<Parent: View, Content: View, Footer: View>: View {

    internal let header: Parent

    internal let content: Content

    internal let footer: Footer

    /// Creates a section with a header, footer, and the provided section content.
    public init(@ViewBuilder content: () -> Content, @ViewBuilder header: () -> Parent, @ViewBuilder footer: () -> Footer) {
        self.header = header()
        self.content = content()
        self.footer = footer()
    }

    /// Creates a section with the provided section content, header and
    /// footer views.
    public init(header: Parent, footer: Footer, @ViewBuilder content: () -> Content) {
        self.header = header
        self.content = content()
        self.footer = footer
    }

    /// Outside of lists and forms, a section stacks its header, content and footer.
    public var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            header
            content
            footer
        }
    }
}

extension Section where Footer == EmptyView {

    /// Creates a section with a header and the provided section content.
    public init(@ViewBuilder content: () -> Content, @ViewBuilder header: () -> Parent) {
        self.init(content: content, header: header, footer: { EmptyView() })
    }
}

extension Section where Parent == EmptyView {

    /// Creates a section with a footer and the provided section content.
    public init(@ViewBuilder content: () -> Content, @ViewBuilder footer: () -> Footer) {
        self.init(content: content, header: { EmptyView() }, footer: footer)
    }
}

extension Section where Parent == EmptyView, Footer == EmptyView {

    /// Creates a section with the provided section content.
    public init(@ViewBuilder content: () -> Content) {
        self.init(content: content, header: { EmptyView() }, footer: { EmptyView() })
    }
}

extension Section where Parent == Text, Footer == EmptyView {

    /// Creates a section with the provided section content, with a header
    /// generated from a localized string.
    public init(_ titleKey: LocalizedStringKey, @ViewBuilder content: () -> Content) {
        self.init(content: content, header: { Text(titleKey) })
    }

    /// Creates a section with the provided section content, with a header
    /// generated from a string.
    @_disfavoredOverload
    public init<S: StringProtocol>(_ title: S, @ViewBuilder content: () -> Content) {
        self.init(content: content, header: { Text(title) })
    }
}

/// A section's parts, for containers that style sections.
@MainActor
internal protocol SectionProtocol {
    var headerView: AnyView? { get }
    var footerView: AnyView? { get }
    var contentView: any View { get }
}

extension Section: SectionProtocol {
    var headerView: AnyView? { Parent.self == EmptyView.self ? nil : AnyView(header) }
    var footerView: AnyView? { Footer.self == EmptyView.self ? nil : AnyView(footer) }
    var contentView: any View { content }
}

// MARK: - Flattened rows

/// What a row of a list or form is: a section's header or footer, or a row.
internal enum RowKind: Equatable {
    case header
    case row
    case footer
}

/// The rows of content, found from its structure: tuples, groups,
/// conditionals and sections are flattened, and a `ForEach` contributes its
/// rows without making their views until they're needed.
@MainActor
internal struct FlattenedRows: LazyRowSource {

    private enum Segment {
        case single(id: AnyHashable, view: any View, kind: RowKind, section: Int)
        case source(id: AnyHashable, source: any LazyRowSource, section: Int)
    }

    private struct SegmentID: Hashable {
        let segment: AnyHashable
        let row: AnyHashable
    }

    private var segments: [Segment] = []

    /// The first row of each segment.
    private var starts: [Int] = []

    private(set) var rowCount = 0

    private var sectionCount = 0

    init(_ content: any View) {
        append(content, path: "", section: 0)
    }

    private mutating func append(_ view: any View, path: String, section: Int) {
        func add(_ segment: Segment, count: Int) {
            starts.append(rowCount)
            segments.append(segment)
            rowCount += count
        }
        switch view {
        case let tuple as any _TupleContent:
            for (index, child) in tuple.tupleChildren.enumerated() {
                append(child, path: path + "/\(index)", section: section)
            }
        case let unwrap as any _StructuralWrapper:
            if let inner = unwrap.wrappedContent {
                append(inner, path: path + "/" + unwrap.structuralKey, section: section)
            }
        case let section as any SectionProtocol:
            sectionCount += 1
            let index = sectionCount
            if let header = section.headerView {
                add(.single(id: AnyHashable(path + "/header"), view: header, kind: .header, section: index), count: 1)
            }
            append(section.contentView, path: path + "/content", section: index)
            if let footer = section.footerView {
                add(.single(id: AnyHashable(path + "/footer"), view: footer, kind: .footer, section: index), count: 1)
            }
        case let source as any LazyRowSource:
            // A ForEach of sections expands them one by one.
            if source.rowCount > 0, source.row(at: 0).view is any SectionProtocol {
                for index in 0..<source.rowCount {
                    let row = source.row(at: index)
                    append(row.view, path: path + "/#\(row.id)", section: section)
                }
            } else {
                add(.source(id: AnyHashable(path), source: source, section: section), count: source.rowCount)
            }
        default:
            add(.single(id: AnyHashable(path), view: view, kind: .row, section: section), count: 1)
        }
    }

    /// The segment containing a row, and the row's index within it.
    private func locate(_ index: Int) -> (segment: Segment, offset: Int) {
        var low = 0
        var high = starts.count - 1
        while low < high {
            let middle = (low + high + 1) / 2
            if starts[middle] <= index { low = middle } else { high = middle - 1 }
        }
        return (segments[low], index - starts[low])
    }

    func row(at index: Int) -> (id: AnyHashable, view: any View) {
        switch locate(index) {
        case let (.single(id, view, _, _), _):
            return (id, view)
        case let (.source(id, source, _), offset):
            let row = source.row(at: offset)
            return (AnyHashable(SegmentID(segment: id, row: row.id)), row.view)
        }
    }

    func id(at index: Int) -> AnyHashable {
        switch locate(index) {
        case let (.single(id, _, _, _), _):
            return id
        case let (.source(id, source, _), offset):
            return AnyHashable(SegmentID(segment: id, row: source.id(at: offset)))
        }
    }

    /// The identity of a row as its content knows it: a `ForEach` element's
    /// own identity, for selection.
    func elementID(at index: Int) -> AnyHashable {
        switch locate(index) {
        case let (.single(id, _, _, _), _):
            return id
        case let (.source(_, source, _), offset):
            return source.id(at: offset)
        }
    }

    func kind(at index: Int) -> RowKind {
        switch locate(index) {
        case let (.single(_, _, kind, _), _): kind
        case (.source, _): .row
        }
    }

    /// What a row is, and whether it's the first or last row of its section.
    func position(at index: Int) -> ListRowPosition {
        let section = self.section(at: index)
        func isRow(_ other: Int) -> Bool {
            other >= 0 && other < rowCount && self.kind(at: other) == .row && self.section(at: other) == section
        }
        return ListRowPosition(kind: self.kind(at: index), isFirst: !isRow(index - 1), isLast: !isRow(index + 1))
    }

    func section(at index: Int) -> Int {
        switch locate(index) {
        case let (.single(_, _, _, section), _): section
        case let (.source(_, _, section), _): section
        }
    }
}

/// A tuple's views, for flattening.
@MainActor
internal protocol _TupleContent {
    var tupleChildren: [any View] { get }
}

extension TupleView: _TupleContent {
    var tupleChildren: [any View] { children }
}

/// A structural wrapper around one view, or none.
@MainActor
internal protocol _StructuralWrapper {
    var wrappedContent: (any View)? { get }
    var structuralKey: String { get }
}

extension Group: _StructuralWrapper where Content: View {
    var wrappedContent: (any View)? { content }
    var structuralKey: String { "group" }
}

extension Optional: _StructuralWrapper where Wrapped: View {
    var wrappedContent: (any View)? { self }
    var structuralKey: String { "some" }
}

extension _ConditionalContent: _StructuralWrapper {
    var wrappedContent: (any View)? {
        switch storage {
        case let .trueContent(view): view
        case let .falseContent(view): view
        }
    }
    var structuralKey: String {
        switch storage {
        case .trueContent: "true"
        case .falseContent: "false"
        }
    }
}

extension AnyView: _StructuralWrapper {
    var wrappedContent: (any View)? { view }
    var structuralKey: String { "\(ObjectIdentifier(type(of: view)))" }
}

// MARK: - Form

/// A container for grouping controls used for data entry, such as in
/// settings or inspectors.
public struct Form<Content: View>: View {

    internal let content: Content

    /// Creates a form with the provided content.
    public init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    @Environment(\.colorScheme) private var colorScheme

    public var body: some View {
        let rows = FlattenedRows(content)
        let sections = Self.sections(rows)
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                ForEach(sections.indices, id: \.self) { index in
                    let section = sections[index]
                    VStack(alignment: .leading, spacing: 6) {
                        if let header = section.header {
                            header
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                                .padding(.horizontal, 14)
                        }
                        if !section.rows.isEmpty {
                            VStack(alignment: .leading, spacing: 0) {
                                ForEach(section.rows.indices, id: \.self) { row in
                                    section.rows[row]
                                        .frame(maxWidth: .infinity, minHeight: 24, alignment: .leading)
                                        .padding(.horizontal, 14)
                                        .padding(.vertical, 9)
                                    if row < section.rows.count - 1 {
                                        Divider().padding(.leading, 14)
                                    }
                                }
                            }
                            .background {
                                RoundedRectangle(cornerRadius: 10).fill(Color.controlBackground(colorScheme))
                            }
                        }
                        if let footer = section.footer {
                            footer
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                                .padding(.horizontal, 14)
                        }
                    }
                }
            }
            .padding(20)
        }
        .background(Color.groupedBackground(colorScheme))
    }

    private struct FormSection {
        var header: AnyView?
        var rows: [AnyView] = []
        var footer: AnyView?
    }

    /// Groups rows into sections; rows outside sections form their own.
    private static func sections(_ rows: FlattenedRows) -> [FormSection] {
        var sections: [FormSection] = []
        var current: Int?
        for index in 0..<rows.rowCount {
            let section = rows.section(at: index)
            if section != current || sections.isEmpty {
                sections.append(FormSection())
                current = section
            }
            let view = AnyView(rows.row(at: index).view)
            switch rows.kind(at: index) {
            case .header: sections[sections.count - 1].header = view
            case .footer: sections[sections.count - 1].footer = view
            case .row: sections[sections.count - 1].rows.append(view)
            }
        }
        return sections
    }
}

extension Color {

    /// The background behind grouped content, like forms.
    internal static func groupedBackground(_ colorScheme: ColorScheme) -> Color {
        colorScheme == .dark ? Color(white: 0.07) : Color(red: 0.95, green: 0.95, blue: 0.97)
    }
}
