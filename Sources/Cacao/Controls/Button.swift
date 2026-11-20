//
//  Button.swift
//  Cacao
//
//  Created by Alsey Coleman Miller on 11/13/26.
//

import CacaoRender
import Foundation
#if canImport(CoreGraphics)
import CoreGraphics
#endif

/// A control that initiates an action.
public struct Button<Label: View>: View {

    internal let role: ButtonRole?

    internal let action: () -> Void

    internal let label: Label

    /// Creates a button that displays a custom label.
    public init(action: @escaping () -> Void, @ViewBuilder label: () -> Label) {
        self.init(role: nil, action: action, label: label)
    }

    /// Creates a button with a specified role that displays a custom label.
    public init(role: ButtonRole?, action: @escaping () -> Void, @ViewBuilder label: () -> Label) {
        self.role = role
        self.action = action
        self.label = label()
    }

    public var body: some View {
        _ButtonBody(role: role, action: action, label: AnyView(label))
    }
}

extension Button where Label == Text {

    /// Creates a button that generates its label from a localized string key.
    public init(_ titleKey: LocalizedStringKey, action: @escaping () -> Void) {
        self.init(role: nil, action: action) { Text(titleKey) }
    }

    /// Creates a button that generates its label from a string.
    @_disfavoredOverload
    public init<S: StringProtocol>(_ title: S, action: @escaping () -> Void) {
        self.init(role: nil, action: action) { Text(title) }
    }

    /// Creates a button with a specified role that generates its label from
    /// a localized string key.
    public init(_ titleKey: LocalizedStringKey, role: ButtonRole?, action: @escaping () -> Void) {
        self.init(role: role, action: action) { Text(titleKey) }
    }

    /// Creates a button with a specified role that generates its label from
    /// a string.
    @_disfavoredOverload
    public init<S: StringProtocol>(_ title: S, role: ButtonRole?, action: @escaping () -> Void) {
        self.init(role: role, action: action) { Text(title) }
    }
}

/// A value that describes the purpose of a button.
public struct ButtonRole: Equatable, Sendable {

    internal let name: String

    /// A role that indicates a destructive button.
    public static let destructive = ButtonRole(name: "destructive")

    /// A role that indicates a button that cancels an operation.
    public static let cancel = ButtonRole(name: "cancel")
}

/// The button's styled label, pressed while a press is on it.
internal struct _ButtonBody: View {

    let role: ButtonRole?

    let action: () -> Void

    let label: AnyView

    @State private var isPressed = false

    @Environment(\.buttonStyle) private var style

    @Environment(\.dismissPopup) private var dismissPopup

    var body: some View {
        let isPressed = $isPressed
        let dismissPopup = self.dismissPopup
        let action = self.action
        style.makeBody(configuration: ButtonStyleConfiguration(
            role: role,
            label: ButtonStyleConfiguration.Label(content: label),
            isPressed: self.isPressed
        ))
        .contentShape(Rectangle())
        .modifier(_TapGestureModifier(handler: TapHandler(
            onPressChanged: { isPressed.wrappedValue = $0 },
            action: {
                action()
                // A button in a popup, like a menu item, closes it.
                dismissPopup?()
            }
        )))
    }
}

// MARK: - ButtonStyle

/// A type that applies standard interaction behavior and a custom appearance
/// to all buttons within a view hierarchy.
@MainActor
@preconcurrency
public protocol ButtonStyle {

    /// A view that represents the body of a button.
    associatedtype Body: View

    /// The properties of a button.
    typealias Configuration = ButtonStyleConfiguration

    /// Creates a view that represents the body of a button.
    @ViewBuilder
    func makeBody(configuration: Self.Configuration) -> Self.Body
}

/// The properties of a button.
public struct ButtonStyleConfiguration {

    /// A type-erased label of a button.
    public struct Label: View, PrimitiveView {

        internal let content: AnyView

        public typealias Body = Never

        func resolve(in context: ResolveContext) -> Resolution {
            Resolution(children: [ChildView(key: 0, view: content)])
        }
    }

    /// An optional semantic role that describes the button's purpose.
    public let role: ButtonRole?

    /// A view that describes the effect of pressing the button.
    public let label: ButtonStyleConfiguration.Label

    /// A Boolean that indicates whether the user is currently pressing the button.
    public let isPressed: Bool
}

/// A type-erased button style.
internal struct AnyButtonStyle {

    let makeBody: @MainActor (ButtonStyleConfiguration) -> AnyView

    @MainActor
    init<S: ButtonStyle>(_ style: S) {
        self.makeBody = { AnyView(style.makeBody(configuration: $0)) }
    }

    @MainActor
    func makeBody(configuration: ButtonStyleConfiguration) -> AnyView {
        makeBody(configuration)
    }
}

private struct ButtonStyleKey: EnvironmentKey {
    static var defaultValue: AnyButtonStyle? { nil }
}

extension EnvironmentValues {

    internal var buttonStyle: AnyButtonStyle {
        get { self[ButtonStyleKey.self] ?? MainActor.assumeIsolated { AnyButtonStyle(DefaultButtonStyle()) } }
        set { self[ButtonStyleKey.self] = newValue }
    }
}

extension View {

    /// Sets the style for buttons within this view to a button style with a
    /// custom appearance and standard interaction behavior.
    public func buttonStyle<S: ButtonStyle>(_ style: S) -> some View {
        environment(\.buttonStyle, AnyButtonStyle(style))
    }
}

// MARK: - Styles

/// The default button style: borderless.
public struct DefaultButtonStyle: ButtonStyle {

    public init() { }

    public func makeBody(configuration: Configuration) -> some View {
        BorderlessButtonStyle().makeBody(configuration: configuration)
    }
}

/// A button style that doesn't style or decorate its content while idle, but
/// may apply a visual effect to indicate the pressed, focused, or enabled
/// state of the button.
public struct PlainButtonStyle: ButtonStyle {

    public init() { }

    public func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .opacity(configuration.isPressed ? 0.6 : 1)
    }
}

/// A button style that doesn't apply a border.
public struct BorderlessButtonStyle: ButtonStyle {

    public init() { }

    public func makeBody(configuration: Configuration) -> some View {
        _BorderlessButton(configuration: configuration)
    }
}

private struct _BorderlessButton: View {

    let configuration: ButtonStyleConfiguration

    @Environment(\.isEnabled) private var isEnabled

    var body: some View {
        configuration.label
            .foregroundStyle(tint)
            .opacity(configuration.isPressed ? 0.4 : 1)
    }

    private var tint: Color {
        guard isEnabled else { return .gray }
        return configuration.role == .destructive ? .red : .accentColor
    }
}

/// A button style that applies standard border artwork based on the button's
/// context.
public struct BorderedButtonStyle: ButtonStyle {

    public init() { }

    public func makeBody(configuration: Configuration) -> some View {
        _BorderedButton(configuration: configuration, isProminent: false)
    }
}

/// A button style that applies standard border prominent artwork based on
/// the button's context.
public struct BorderedProminentButtonStyle: ButtonStyle {

    public init() { }

    public func makeBody(configuration: Configuration) -> some View {
        _BorderedButton(configuration: configuration, isProminent: true)
    }
}

private struct _BorderedButton: View {

    let configuration: ButtonStyleConfiguration

    let isProminent: Bool

    @Environment(\.isEnabled) private var isEnabled

    @Environment(\.controlSize) private var controlSize

    @Environment(\.font) private var font

    var body: some View {
        let metrics = Self.metrics(controlSize)
        configuration.label
            .font(font ?? metrics.font)
            .foregroundStyle(foreground)
            .padding(.horizontal, metrics.horizontal)
            .padding(.vertical, metrics.vertical)
            .background {
                RoundedRectangle(cornerRadius: metrics.radius).fill(background)
            }
    }

    /// The padding, corner radius and font of a button of a size.
    static func metrics(_ size: ControlSize) -> (horizontal: CGFloat, vertical: CGFloat, radius: CGFloat, font: Font?) {
        switch size {
        case .mini: (6, 2, 4, .system(size: 9))
        case .small: (8, 3, 5, .system(size: 11))
        case .regular: (12, 6, 6, nil)
        case .large: (16, 9, 8, nil)
        case .extraLarge: (20, 12, 10, .title3)
        }
    }

    private var tint: Color {
        configuration.role == .destructive ? .red : .accentColor
    }

    private var foreground: Color {
        guard isEnabled else { return .gray }
        return isProminent ? .white : tint
    }

    private var background: Color {
        let pressed = configuration.isPressed
        guard isEnabled else { return Color.gray.opacity(0.15) }
        return isProminent
            ? tint.opacity(pressed ? 0.7 : 1)
            : Color.gray.opacity(pressed ? 0.3 : 0.15)
    }
}

extension ButtonStyle where Self == DefaultButtonStyle {

    /// The default button style, based on the button's context.
    public static var automatic: DefaultButtonStyle { DefaultButtonStyle() }
}

extension ButtonStyle where Self == PlainButtonStyle {

    /// A button style that doesn't style or decorate its content while idle.
    public static var plain: PlainButtonStyle { PlainButtonStyle() }
}

extension ButtonStyle where Self == BorderlessButtonStyle {

    /// A button style that doesn't apply a border.
    public static var borderless: BorderlessButtonStyle { BorderlessButtonStyle() }
}

extension ButtonStyle where Self == BorderedButtonStyle {

    /// A button style that applies standard border artwork.
    public static var bordered: BorderedButtonStyle { BorderedButtonStyle() }
}

extension ButtonStyle where Self == BorderedProminentButtonStyle {

    /// A button style that applies standard border prominent artwork.
    public static var borderedProminent: BorderedProminentButtonStyle { BorderedProminentButtonStyle() }
}
