//
//  TabView.swift
//  Cacao
//
//  Created by Alsey Coleman Miller on 11/13/26.
//

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
                        (tabs[index].traits[TabItemKey.self] ?? AnyView(Text("Tab \(index + 1)")))
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

    internal let title: Text

    internal let value: Value

    internal let content: Content

    /// Creates a tab that the tab view presents when its value matches the
    /// selection.
    public init(_ titleKey: LocalizedStringKey, systemImage: String? = nil, value: Value, @ViewBuilder content: () -> Content) {
        self.title = Text(titleKey)
        self.value = value
        self.content = content()
    }

    public var body: some View {
        content
    }
}

extension Tab where Value == Int {

    /// Creates a tab with a title.
    public init(_ titleKey: LocalizedStringKey, systemImage: String? = nil, @ViewBuilder content: () -> Content) {
        self.title = Text(titleKey)
        self.value = -1
        self.content = content()
    }
}

extension Tab: OptionSource {

    func options() -> [Option] {
        var traits = LayoutTraits()
        traits[TabItemKey.self] = AnyView(title)
        return [Option(tag: value == (-1 as? Value) ? nil : AnyHashable(value), label: AnyView(content), traits: traits)]
    }
}
