//
//  TabView.swift
//  Cacao
//
//  Created by Alsey Coleman Miller on 11/13/26.
//

import CacaoRender
import Foundation
#if canImport(CoreGraphics)
import CoreGraphics
#endif

/// A view that switches between multiple child views using interactive
/// user interface elements.
///
/// Tabs are the views in its content, labeled with `tabItem(_:)` and
/// identified with `tag(_:)`, or `Tab`s. Every tab stays alive, keeping its
/// state, and only the selected one shows.
public struct TabView<SelectionValue: Hashable, Content: View>: View {

    internal let selection: Binding<SelectionValue>?

    internal let content: Content

    /// Creates a tab view that uses a provided selection value.
    @_disfavoredOverload
    public init(selection: Binding<SelectionValue>?, @ViewBuilder content: () -> Content) {
        self.selection = selection
        self.content = content()
    }

    @State private var ownSelection: AnyHashable?

    @Environment(\.colorScheme) private var colorScheme

    public var body: some View {
        let tabs = Cacao.options(in: content)
        let tags = tabs.enumerated().map { $0.element.tag ?? AnyHashable($0.offset) }
        let selected: AnyHashable = selection.map { AnyHashable($0.wrappedValue) } ?? ownSelection ?? tags.first ?? AnyHashable(0)
        let selectedIndex = tags.firstIndex(of: selected) ?? 0
        let selection = self.selection
        let ownSelection = $ownSelection
        VStack(spacing: 0) {
            HStack(spacing: 4) {
                ForEach(tabs.indices, id: \.self) { index in
                    let isSelected = index == selectedIndex
                    Button {
                        if let selection, let value = tags[index].base as? SelectionValue {
                            selection.wrappedValue = value
                        } else {
                            ownSelection.wrappedValue = tags[index]
                        }
                    } label: {
                        HStack(spacing: 6) {
                            tabs[index].traits[TabItemKey.self] ?? AnyView(Text("Tab \(index + 1)"))
                            if let badge = tabs[index].traits[BadgeKey.self] {
                                badge
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(.white)
                                    .padding(.horizontal, 5)
                                    .background { Capsule().fill(Color.red) }
                            }
                        }
                            .foregroundStyle(isSelected ? Color.accentColor : Color.secondary)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 6)
                            .background {
                                RoundedRectangle(cornerRadius: 7)
                                    .fill(isSelected ? Color.accentColor.opacity(0.15) : Color.clear)
                            }
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(8)
            .frame(maxWidth: .infinity)
            .background(Color.barBackground(colorScheme))
            Divider()
            _TabPages(pages: tabs.map(\.label), selected: selectedIndex)
        }
    }
}

extension TabView where SelectionValue == Int {

    /// Creates a tab view that manages its own selection.
    public init(@ViewBuilder content: () -> Content) {
        self.selection = nil
        self.content = content()
    }
}

/// Every tab's page, only the selected one shown and taking hits.
private struct _TabPages: View, PrimitiveView {

    let pages: [AnyView]

    let selected: Int

    func resolve(in context: ResolveContext) -> Resolution {
        Resolution(
            behavior: _TabPagesBehavior(selected: selected),
            children: pages.enumerated().map { ChildView(key: $0.offset, view: $0.element) }
        )
    }

    typealias Body = Never
}

private struct _TabPagesBehavior: NodeBehavior {

    let selected: Int

    func sizeThatFits(_ proposal: ProposedViewSize, node: ViewNode) -> CGSize {
        proposal.replacingUnspecifiedDimensions(by: CGSize(width: 320, height: 480))
    }

    func placeChildren(in bounds: CGRect, proposal: ProposedViewSize, node: ViewNode) {
        for index in node.children.indices {
            guard let page = LayoutProxy.combining(node.layoutChildren(ofChildAt: index)) else { continue }
            let size = page.size(in: ProposedViewSize(bounds.size))
            page.place(
                at: CGPoint(x: bounds.midX - size.width / 2, y: bounds.midY - size.height / 2),
                proposal: ProposedViewSize(bounds.size)
            )
        }
    }

    func displayOrder(of children: [ViewNode]) -> [ViewNode] {
        children.indices.contains(selected) ? [children[selected]] : []
    }
}

/// The tab item trait, set with `tabItem(_:)`.
internal enum TabItemKey: LayoutValueKey {
    static var defaultValue: AnyView? { nil }
}

extension View {

    /// Sets the tab bar item associated with this view.
    public func tabItem<V: View>(@ViewBuilder _ label: () -> V) -> some View {
        var traits = LayoutTraits()
        traits[TabItemKey.self] = AnyView(label())
        return modifier(_TraitWritingModifier(traits: traits))
    }
}

/// The content and behavior of a tab.
public struct Tab<Value: Hashable, Content: View>: View {

    internal let label: AnyView

    internal let value: Value

    internal let role: TabRole?

    internal let content: Content

    /// Creates a tab that the tab view presents when its value matches the
    /// selection.
    public init(
        _ titleKey: LocalizedStringKey,
        systemImage: String? = nil,
        value: Value,
        role: TabRole? = nil,
        @ViewBuilder content: () -> Content
    ) {
        self.label = Self.label(Text(titleKey), systemImage: systemImage)
        self.value = value
        self.role = role
        self.content = content()
    }

    /// Creates a tab with a title from a string.
    @_disfavoredOverload
    public init<S: StringProtocol>(
        _ title: S,
        systemImage: String? = nil,
        value: Value,
        role: TabRole? = nil,
        @ViewBuilder content: () -> Content
    ) {
        self.label = Self.label(Text(title), systemImage: systemImage)
        self.value = value
        self.role = role
        self.content = content()
    }

    /// Creates a tab with a role, labeled for it.
    public init(value: Value, role: TabRole?, @ViewBuilder content: () -> Content) {
        self.label = role == .search ? Self.label(Text("Search"), systemImage: "magnifyingglass") : AnyView(EmptyView())
        self.value = value
        self.role = role
        self.content = content()
    }

    private static func label(_ title: Text, systemImage: String?) -> AnyView {
        guard let systemImage else { return AnyView(title) }
        return AnyView(Label(title: { title }, icon: { Image(systemName: systemImage) }))
    }

    public var body: some View {
        content
    }
}

extension Tab where Value == Int {

    /// Creates a tab with a title.
    public init(_ titleKey: LocalizedStringKey, systemImage: String? = nil, @ViewBuilder content: () -> Content) {
        self.label = Self.label(Text(titleKey), systemImage: systemImage)
        self.value = -1
        self.role = nil
        self.content = content()
    }
}

extension Tab: OptionSource {

    func options() -> [Option] {
        var traits = LayoutTraits()
        traits[TabItemKey.self] = label
        return [Option(tag: value == (-1 as? Value) ? nil : AnyHashable(value), label: AnyView(content), traits: traits)]
    }
}

/// A value that defines the purpose of a tab.
public struct TabRole: Hashable, Sendable {

    private let name: String

    /// The search role.
    public static let search = TabRole(name: "search")
}

// MARK: - Tab content

/// A type that provides content for programmatically selectable tabs in a
/// tab view.
@MainActor
@preconcurrency
public protocol TabContent<TabValue> {

    /// The type used to drive selection for the tab.
    associatedtype TabValue: Hashable

    /// The tabs, as views a tab view lists.
    var _tabs: AnyView { get }
}

extension Tab: TabContent {

    public typealias TabValue = Value

    public var _tabs: AnyView { AnyView(self) }
}

extension ForEach: TabContent where Content: View & TabContent {

    public typealias TabValue = Content.TabValue

    public var _tabs: AnyView { AnyView(self) }
}

/// Tabs from a tab content builder.
public struct _TabGroup<TabValue: Hashable>: View, TabContent {

    internal let parts: [AnyView]

    public var _tabs: AnyView { AnyView(self) }

    public var body: some View {
        ForEach(parts.indices, id: \.self) { parts[$0] }
    }
}

extension _TabGroup: OptionSource {

    func options() -> [Option] {
        parts.flatMap { Cacao.options(in: $0) }
    }
}

/// A result builder that constructs tabs for a tab view that supports
/// programmatic selection, giving its tabs the type of the selection.
@MainActor
@resultBuilder
public struct TabContentBuilder<TabValue: Hashable> {

    public static func buildExpression<C: TabContent>(_ content: C) -> _TabGroup<TabValue> where C.TabValue == TabValue {
        _TabGroup(parts: [content._tabs])
    }

    public static func buildBlock(_ parts: _TabGroup<TabValue>...) -> _TabGroup<TabValue> {
        _TabGroup(parts: parts.flatMap(\.parts))
    }

    public static func buildOptional(_ part: _TabGroup<TabValue>?) -> _TabGroup<TabValue> {
        part ?? _TabGroup(parts: [])
    }

    public static func buildEither(first part: _TabGroup<TabValue>) -> _TabGroup<TabValue> {
        part
    }

    public static func buildEither(second part: _TabGroup<TabValue>) -> _TabGroup<TabValue> {
        part
    }

    public static func buildLimitedAvailability(_ part: _TabGroup<TabValue>) -> _TabGroup<TabValue> {
        part
    }
}

extension TabView {

    /// Creates a tab view that uses a builder to create and specify
    /// selection values for its tabs.
    public init(
        selection: Binding<SelectionValue>,
        @TabContentBuilder<SelectionValue> content: () -> _TabGroup<SelectionValue>
    ) where Content == _TabGroup<SelectionValue> {
        self.selection = selection
        self.content = content()
    }
}

/// A container that you can use to add hierarchy within a tab view.
///
/// Cacao lists a section's tabs with the others, without its title.
public struct TabSection<SelectionValue: Hashable>: View, TabContent {

    public typealias TabValue = SelectionValue

    internal let title: Text

    internal let content: _TabGroup<SelectionValue>

    /// Creates a section with a title and its tabs.
    public init(_ titleKey: LocalizedStringKey, @TabContentBuilder<SelectionValue> content: () -> _TabGroup<SelectionValue>) {
        self.title = Text(titleKey)
        self.content = content()
    }

    /// Creates a section with a title from a string and its tabs.
    @_disfavoredOverload
    public init<S: StringProtocol>(_ title: S, @TabContentBuilder<SelectionValue> content: () -> _TabGroup<SelectionValue>) {
        self.title = Text(title)
        self.content = content()
    }

    public var _tabs: AnyView { AnyView(self) }

    public var body: some View {
        content
    }
}

extension TabSection: OptionSource {

    func options() -> [Option] {
        content.options()
    }
}

// MARK: - Style

/// A specification for the appearance and interaction of a tab view.
///
/// Cacao draws every tab view with a tab bar, whatever its style.
@MainActor
@preconcurrency
public protocol TabViewStyle { }

/// The default tab view style.
public struct DefaultTabViewStyle: TabViewStyle {
    public init() { }
}

/// A tab bar style that adapts to each platform.
public struct SidebarAdaptableTabViewStyle: TabViewStyle {
    public init() { }
}

/// A tab view style that displays a tab bar when possible.
public struct TabBarOnlyTabViewStyle: TabViewStyle {
    public init() { }
}

extension TabViewStyle where Self == DefaultTabViewStyle {
    public static var automatic: DefaultTabViewStyle { DefaultTabViewStyle() }
}

extension TabViewStyle where Self == SidebarAdaptableTabViewStyle {
    public static var sidebarAdaptable: SidebarAdaptableTabViewStyle { SidebarAdaptableTabViewStyle() }
}

extension TabViewStyle where Self == TabBarOnlyTabViewStyle {
    public static var tabBarOnly: TabBarOnlyTabViewStyle { TabBarOnlyTabViewStyle() }
}

extension View {

    /// Sets the style for the tab view within the current environment.
    public func tabViewStyle<S: TabViewStyle>(_ style: S) -> some View {
        self
    }
}
