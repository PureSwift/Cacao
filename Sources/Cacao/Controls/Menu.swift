//
//  Menu.swift
//  Cacao
//
//  Created by Alsey Coleman Miller on 11/13/26.
//

import CacaoRender
import Foundation
#if canImport(CoreGraphics)
import CoreGraphics
#endif

/// A control for presenting a menu of actions.
public struct Menu<Label: View, Content: View>: View {

    internal let label: Label

    internal let content: Content

    /// Creates a menu with a custom label.
    public init(@ViewBuilder content: () -> Content, @ViewBuilder label: () -> Label) {
        self.label = label()
        self.content = content()
    }

    public var body: some View {
        _PopupButton(
            label: AnyView(label),
            content: AnyView(_MenuContent(content: AnyView(content)))
        )
    }
}

extension Menu where Label == Text {

    /// Creates a menu that generates its label from a localized string key.
    public init(_ titleKey: LocalizedStringKey, @ViewBuilder content: () -> Content) {
        self.init(content: content) { Text(titleKey) }
    }

    /// Creates a menu that generates its label from a string.
    @_disfavoredOverload
    public init<S: StringProtocol>(_ title: S, @ViewBuilder content: () -> Content) {
        self.init(content: content) { Text(title) }
    }
}

/// A button that opens a popup below itself: bordered, with a chevron, or
/// plain text with `.menuStyle(.borderlessButton)`; or in a menu, a
/// submenu item that opens its menu beside itself.
internal struct _PopupButton: View, PrimitiveView {

    let label: AnyView

    let content: AnyView

    func resolve(in context: ResolveContext) -> Resolution {
        let node = context.node
        let graph = context.graph
        let content = self.content
        let isInMenu = context.environment.isInMenu
        let dismissPopupsAbove = context.environment.dismissPopupsAbove
        // The popup it opened, while it shows.
        let storage = node.dynamicStorage["popup"] as? StorageBox<Int?> ?? StorageBox<Int?>(nil)
        node.dynamicStorage["popup"] = storage
        if let id = storage.value, !graph.presentations.contains(where: { $0.id == id }) {
            storage.value = nil
        }
        let isOpen = storage.value != nil
        // An open menu shows what it has now, as when its items change.
        if let id = storage.value {
            graph.deferAction { [weak graph] in
                graph?.updatePresentation(id, content: content)
            }
        }
        let open: @MainActor (_ focusesFirstItem: Bool) -> Void = { [weak node] focusesFirstItem in
            guard let node, storage.value == nil else { return }
            // Another submenu of the same menu closes.
            dismissPopupsAbove?()
            let id = node.graph.presentPopup(
                anchor: node.windowFrame,
                edge: isInMenu ? .trailing : .bottom,
                content: content,
                opener: node,
                onDismiss: { [weak node] in node?.invalidate() }
            )
            storage.value = id
            node.invalidate()
            if focusesFirstItem {
                node.graph.focusFirstItem(inPresentation: id)
            }
        }
        let showsIndicator = context.environment.menuIndicatorVisibility != .hidden
        let view: AnyView
        if isInMenu {
            view = AnyView(_SubmenuItem(label: label, isOpen: isOpen, open: open))
        } else if context.environment.menuStyle == .borderlessButton {
            // Plain text, highlighted while open: a menu bar's title. A
            // click while it's open lands on the menu's backdrop, which
            // closes it.
            view = AnyView(
                Button { open(false) } label: { label }
                    .buttonStyle(_BorderlessMenuButtonStyle(isOpen: isOpen, showsIndicator: context.environment.menuIndicatorVisibility == .visible))
            )
        } else {
            view = AnyView(
                Button { open(false) } label: {
                    HStack(spacing: 6) {
                        label
                        if showsIndicator {
                            _ChevronShape()
                                .stroke(Color.secondary, style: StrokeStyle(lineWidth: 1.5, lineCap: .round, lineJoin: .round))
                                .frame(width: 10, height: 10)
                        }
                    }
                }
                .buttonStyle(.bordered)
            )
        }
        var attributes = NodeAttributes()
        if !isInMenu, context.environment.menuStyle == .borderlessButton {
            attributes.opensMenuOnHover = { open(false) }
        }
        return Resolution(children: [ChildView(key: 0, view: view)], attributes: attributes)
    }

    typealias Body = Never
}

/// A menu item that opens a submenu beside it: when the pointer rests on
/// it, when it's clicked, and with the right arrow or Return.
internal struct _SubmenuItem: View {

    let label: AnyView

    let isOpen: Bool

    let open: @MainActor (Bool) -> Void

    var body: some View {
        let open = self.open
        Button { open(false) } label: {
            HStack(spacing: 6) {
                label
                Spacer(minLength: 16)
                _ChevronShape()
                    .stroke(style: StrokeStyle(lineWidth: 1.5, lineCap: .round, lineJoin: .round))
                    .rotationEffect(.degrees(-90))
                    .frame(width: 8, height: 8)
            }
        }
        // It stays open, and its menu with it.
        .environment(\.dismissPopup, nil)
        .environment(\.isSubmenuItem, true)
        .environment(\.isMenuItemOpen, isOpen)
        .environment(\.openSubmenu, { open($0) })
        .onHover { if $0 { open(false) } }
    }
}

private struct IsInMenuKey: EnvironmentKey {
    static let defaultValue = false
}

private struct IsSubmenuItemKey: EnvironmentKey {
    static let defaultValue = false
}

private struct IsMenuItemOpenKey: EnvironmentKey {
    static let defaultValue = false
}

private struct OpenSubmenuKey: EnvironmentKey {
    static let defaultValue: (@MainActor (Bool) -> Void)? = nil
}

extension EnvironmentValues {

    /// Whether the view is in a menu: menus in it are submenus.
    internal var isInMenu: Bool {
        get { self[IsInMenuKey.self] }
        set { self[IsInMenuKey.self] = newValue }
    }

    /// Whether the view is a menu item that opens a submenu.
    internal var isSubmenuItem: Bool {
        get { self[IsSubmenuItemKey.self] }
        set { self[IsSubmenuItemKey.self] = newValue }
    }

    /// Whether the menu item's submenu is open, which highlights it.
    internal var isMenuItemOpen: Bool {
        get { self[IsMenuItemOpenKey.self] }
        set { self[IsMenuItemOpenKey.self] = newValue }
    }

    /// Opens the menu item's submenu, focusing its first item if asked.
    internal var openSubmenu: (@MainActor (Bool) -> Void)? {
        get { self[OpenSubmenuKey.self] }
        set { self[OpenSubmenuKey.self] = newValue }
    }
}

/// A menu item's behavior, whatever its style: it takes focus for the
/// keyboard, which highlights it; Return or Space chooses it (or opens its
/// submenu, as the right arrow does); and the pointer resting on it closes
/// another item's submenu and takes the highlight from the keyboard.
internal struct _MenuItemBehavior: ViewModifier {

    let action: @MainActor () -> Void

    @Environment(\.isSubmenuItem) private var isSubmenuItem

    @Environment(\.openSubmenu) private var openSubmenu

    @Environment(\.dismissPopupsAbove) private var dismissPopupsAbove

    @Environment(\.menuItemHovered) private var menuItemHovered

    func body(content: Content) -> some View {
        let action = self.action
        let openSubmenu = self.openSubmenu
        let isSubmenuItem = self.isSubmenuItem
        let dismissPopupsAbove = self.dismissPopupsAbove
        let menuItemHovered = self.menuItemHovered
        content
            .modifier(_FocusEnvironmentModifier())
            .modifier(_AttributesModifier { attributes in
                var target = FocusTarget()
                target.keyDown = { key, _ in
                    switch key {
                    case .returnKey, .character(" "):
                        if isSubmenuItem, let openSubmenu {
                            openSubmenu(true)
                        } else {
                            action()
                        }
                        return true
                    case .right where isSubmenuItem:
                        openSubmenu?(true)
                        return true
                    default:
                        return false
                    }
                }
                attributes.focus = target
            })
            .onHover { isHovered in
                guard isHovered else { return }
                menuItemHovered?()
                if !isSubmenuItem {
                    dismissPopupsAbove?()
                }
            }
    }
}

/// A popup's list of items, styled as a menu.
internal struct _MenuContent: View {

    let content: AnyView

    @Environment(\.colorScheme) private var colorScheme

    @Environment(\.interfaceLook) private var look

    var body: some View {
        Group {
            if look.value == .desktop {
                _DesktopMenuContent(content: content)
            } else {
                stock
            }
        }
        .environment(\.isInMenu, true)
    }

    /// The menu in the stock look.
    private var stock: some View {
        _MenuItems {
            VStack(alignment: .leading, spacing: 0) {
                content
            }
        }
        .buttonStyle(_MenuItemButtonStyle())
        .padding(4)
        .frame(minWidth: 160, alignment: .leading)
        .background {
            RoundedRectangle(cornerRadius: 8).fill(Color.controlBackground(colorScheme))
        }
        .overlay {
            RoundedRectangle(cornerRadius: 8).strokeBorder(Color.separator, lineWidth: 1)
        }
    }
}

/// A menu's items: as tall as they are, or scrolling when there's less
/// room than that.
internal struct _MenuItems<Content: View>: View {

    let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        _FitsHeightLayout() {
            ScrollView(.vertical) {
                content
            }
        }
    }
}

/// Sizes its one subview, a vertical scroll view, to its content's height,
/// or the height proposed when that's less.
private struct _FitsHeightLayout: Layout {

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        guard let subview = subviews.first else { return .zero }
        let ideal = subview.sizeThatFits(ProposedViewSize(width: proposal.width, height: nil))
        return CGSize(width: ideal.width, height: min(ideal.height, proposal.height ?? .infinity))
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        subviews.first?.place(at: bounds.origin, proposal: ProposedViewSize(bounds.size))
    }
}

/// A menu item: highlighted while pressed, focused, or its submenu is
/// open.
internal struct _MenuItemButtonStyle: ButtonStyle {

    func makeBody(configuration: Configuration) -> some View {
        _MenuItem(configuration: configuration)
    }
}

private struct _MenuItem: View {

    let configuration: ButtonStyleConfiguration

    @Environment(\.isFocused) private var isFocused

    @Environment(\.isMenuItemOpen) private var isOpen

    var body: some View {
        let isHighlighted = configuration.isPressed || isFocused || isOpen
        configuration.label
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .frame(maxWidth: .infinity, alignment: .leading)
            .foregroundStyle(isHighlighted ? Color.white : configuration.role == .destructive ? Color.red : Color.primary)
            .background {
                RoundedRectangle(cornerRadius: 5).fill(isHighlighted ? Color.accentColor : Color.clear)
            }
    }
}

// MARK: - Picker

/// A control for selecting from a set of mutually exclusive values.
///
/// Options are the views in its content, identified by `tag(_:)` or, in a
/// `ForEach`, by their identity.
public struct Picker<Label: View, SelectionValue: Hashable, Content: View>: View {

    internal let selection: Binding<SelectionValue>

    internal let label: Label

    internal let content: Content

    /// Creates a picker that displays a custom label.
    public init(selection: Binding<SelectionValue>, @ViewBuilder content: () -> Content, @ViewBuilder label: () -> Label) {
        self.selection = selection
        self.label = label()
        self.content = content()
    }

    @Environment(\.pickerStyle) private var style

    @Environment(\.labelsHidden) private var labelsHidden

    public var body: some View {
        let options = Cacao.options(in: content)
        let selection = self.selection
        let selected = AnyHashable(selection.wrappedValue)
        let select: (AnyHashable?) -> Void = { tag in
            if let value = tag?.base as? SelectionValue {
                selection.wrappedValue = value
            }
        }
        switch style {
        case .segmented:
            _SegmentedControl(options: options, selected: selected, select: select)
        case .inline:
            VStack(alignment: .leading, spacing: 8) {
                if !labelsHidden {
                    label
                }
                ForEach(options.indices, id: \.self) { index in
                    let option = options[index]
                    Button { select(option.tag) } label: {
                        HStack(spacing: 8) {
                            ZStack {
                                Circle().strokeBorder(Color.gray, lineWidth: 1)
                                if option.tag == selected {
                                    Circle().fill(Color.accentColor).padding(4)
                                }
                            }
                            .frame(width: 16, height: 16)
                            option.label
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
        default:
            HStack {
                if !labelsHidden {
                    label
                    Spacer()
                }
                _PopupButton(
                    label: options.first { $0.tag == selected }?.label ?? AnyView(Text(verbatim: "")),
                    content: AnyView(_MenuContent(content: AnyView(
                        ForEach(options.indices, id: \.self) { index in
                            let option = options[index]
                            Button { select(option.tag) } label: {
                                HStack(spacing: 6) {
                                    _CheckmarkShape()
                                        .stroke(Color.primary, style: StrokeStyle(lineWidth: 1.5, lineCap: .round, lineJoin: .round))
                                        .frame(width: 12, height: 12)
                                        .opacity(option.tag == selected ? 1 : 0)
                                    option.label
                                }
                            }
                        }
                    )))
                )
            }
        }
    }
}

extension Picker where Label == Text {

    /// Creates a picker that generates its label from a localized string key.
    public init(_ titleKey: LocalizedStringKey, selection: Binding<SelectionValue>, @ViewBuilder content: () -> Content) {
        self.init(selection: selection, content: content) { Text(titleKey) }
    }

    /// Creates a picker that generates its label from a string.
    @_disfavoredOverload
    public init<S: StringProtocol>(_ title: S, selection: Binding<SelectionValue>, @ViewBuilder content: () -> Content) {
        self.init(selection: selection, content: content) { Text(title) }
    }
}

/// Options side by side in a rounded track, the selected one raised.
private struct _SegmentedControl: View {

    let options: [Option]

    let selected: AnyHashable

    let select: (AnyHashable?) -> Void

    @Environment(\.colorScheme) private var colorScheme

    @Environment(\.interfaceLook) private var look

    var body: some View {
        if look.value == .desktop {
            _DesktopSegmentedControl(options: options, selected: selected, select: select)
        } else {
            stock
        }
    }

    /// The control in the stock look.
    private var stock: some View {
        HStack(spacing: 0) {
            ForEach(options.indices, id: \.self) { index in
                let option = options[index]
                Button { select(option.tag) } label: {
                    option.label
                        .padding(.horizontal, 12)
                        .padding(.vertical, 4)
                        .frame(maxWidth: .infinity)
                        .background {
                            RoundedRectangle(cornerRadius: 6)
                                .fill(option.tag == selected ? Color.selectedSegment(colorScheme) : Color.clear)
                        }
                }
                .buttonStyle(.plain)
            }
        }
        .padding(2)
        .background { RoundedRectangle(cornerRadius: 8).fill(Color.controlFill) }
    }
}

/// The styles of pickers.
public struct PickerStyleKind: Equatable, Sendable {
    internal let name: String
    static let automatic = PickerStyleKind(name: "automatic")
    static let menu = PickerStyleKind(name: "menu")
    static let segmented = PickerStyleKind(name: "segmented")
    static let inline = PickerStyleKind(name: "inline")
}

/// A picker style.
public protocol PickerStyle {
    var _kind: PickerStyleKind { get }
}

/// The default picker style: a menu.
public struct DefaultPickerStyle: PickerStyle {
    public init() { }
    public var _kind: PickerStyleKind { .automatic }
}

/// A picker style that presents the options as a menu.
public struct MenuPickerStyle: PickerStyle {
    public init() { }
    public var _kind: PickerStyleKind { .menu }
}

/// A picker style that presents the options in a segmented control.
public struct SegmentedPickerStyle: PickerStyle {
    public init() { }
    public var _kind: PickerStyleKind { .segmented }
}

/// A picker style that presents the options inline, as radio buttons.
public struct InlinePickerStyle: PickerStyle {
    public init() { }
    public var _kind: PickerStyleKind { .inline }
}

extension PickerStyle where Self == DefaultPickerStyle {
    public static var automatic: DefaultPickerStyle { DefaultPickerStyle() }
}

extension PickerStyle where Self == MenuPickerStyle {
    public static var menu: MenuPickerStyle { MenuPickerStyle() }
}

extension PickerStyle where Self == SegmentedPickerStyle {
    public static var segmented: SegmentedPickerStyle { SegmentedPickerStyle() }
}

extension PickerStyle where Self == InlinePickerStyle {
    public static var inline: InlinePickerStyle { InlinePickerStyle() }
    public static var radioGroup: InlinePickerStyle { InlinePickerStyle() }
}

private struct PickerStyleKey: EnvironmentKey {
    static let defaultValue = PickerStyleKind.automatic
}

extension EnvironmentValues {

    internal var pickerStyle: PickerStyleKind {
        get { self[PickerStyleKey.self] }
        set { self[PickerStyleKey.self] = newValue }
    }
}

extension View {

    /// Sets the style for pickers within this view.
    public func pickerStyle<S: PickerStyle>(_ style: S) -> some View {
        environment(\.pickerStyle, style._kind)
    }
}
