//
//  Menu.swift
//  Cacao
//
//  Created by Alsey Coleman Miller on 11/13/26.
//

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
            label: AnyView(
                HStack(spacing: 6) {
                    label
                    _ChevronShape()
                        .stroke(Color.secondary, style: StrokeStyle(lineWidth: 1.5, lineCap: .round, lineJoin: .round))
                        .frame(width: 10, height: 10)
                }
            ),
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

/// A bordered button that opens a popup below itself.
internal struct _PopupButton: View, PrimitiveView {

    let label: AnyView

    let content: AnyView

    func resolve(in context: ResolveContext) -> Resolution {
        let node = context.node
        let content = self.content
        let button = Button {
            [weak node] in
            guard let node else { return }
            node.graph.presentPopup(anchor: node.windowFrame, content: content)
        } label: {
            label
        }
        .buttonStyle(.bordered)
        return Resolution(children: [ChildView(key: 0, view: button)])
    }

    typealias Body = Never
}

/// A popup's list of items, styled as a menu.
internal struct _MenuContent: View {

    let content: AnyView

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            content
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

/// A menu item: highlighted while pressed.
internal struct _MenuItemButtonStyle: ButtonStyle {

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .frame(maxWidth: .infinity, alignment: .leading)
            .foregroundStyle(configuration.isPressed ? Color.white : configuration.role == .destructive ? Color.red : Color.primary)
            .background {
                RoundedRectangle(cornerRadius: 5).fill(configuration.isPressed ? Color.accentColor : Color.clear)
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
                    label: AnyView(HStack(spacing: 6) {
                        options.first { $0.tag == selected }?.label ?? AnyView(Text(verbatim: ""))
                        _ChevronShape()
                            .stroke(Color.secondary, style: StrokeStyle(lineWidth: 1.5, lineCap: .round, lineJoin: .round))
                            .frame(width: 10, height: 10)
                    }),
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

    var body: some View {
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
