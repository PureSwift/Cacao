//
//  Toggle.swift
//  Cacao
//
//  Created by Alsey Coleman Miller on 11/13/26.
//

import CacaoRender
import Foundation
#if canImport(CoreGraphics)
import CoreGraphics
#endif

/// A control that toggles between on and off states.
public struct Toggle<Label: View>: View {

    internal let isOn: Binding<Bool>

    internal let label: Label

    /// Creates a toggle that displays a custom label.
    public init(isOn: Binding<Bool>, @ViewBuilder label: () -> Label) {
        self.isOn = isOn
        self.label = label()
    }

    public var body: some View {
        _ToggleBody(configuration: ToggleStyleConfiguration(
            label: ToggleStyleConfiguration.Label(content: AnyView(label)),
            isOn: isOn
        ))
    }
}

extension Toggle where Label == Text {

    /// Creates a toggle that generates its label from a localized string key.
    public init(_ titleKey: LocalizedStringKey, isOn: Binding<Bool>) {
        self.init(isOn: isOn) { Text(titleKey) }
    }

    /// Creates a toggle that generates its label from a string.
    @_disfavoredOverload
    public init<S: StringProtocol>(_ title: S, isOn: Binding<Bool>) {
        self.init(isOn: isOn) { Text(title) }
    }
}

private struct _ToggleBody: View {

    let configuration: ToggleStyleConfiguration

    @Environment(\.toggleStyle) private var style

    var body: some View {
        style.makeBody(configuration)
    }
}

// MARK: - ToggleStyle

/// The appearance and behavior of a toggle.
@MainActor
@preconcurrency
public protocol ToggleStyle {

    associatedtype Body: View

    typealias Configuration = ToggleStyleConfiguration

    @ViewBuilder
    func makeBody(configuration: Self.Configuration) -> Self.Body
}

/// The properties of a toggle instance.
public struct ToggleStyleConfiguration {

    /// A type-erased label of a toggle.
    public struct Label: View, PrimitiveView {

        internal let content: AnyView

        public typealias Body = Never

        func resolve(in context: ResolveContext) -> Resolution {
            Resolution(children: [ChildView(key: 0, view: content)])
        }
    }

    /// A view that describes the effect of switching the toggle between states.
    public let label: Label

    /// Whether the toggle is currently on.
    @Binding public var isOn: Bool

    internal init(label: Label, isOn: Binding<Bool>) {
        self.label = label
        self._isOn = isOn
    }
}

internal struct AnyToggleStyle {

    let makeBody: @MainActor (ToggleStyleConfiguration) -> AnyView

    @MainActor
    init<S: ToggleStyle>(_ style: S) {
        self.makeBody = { AnyView(style.makeBody(configuration: $0)) }
    }
}

private struct ToggleStyleKey: EnvironmentKey {
    static var defaultValue: AnyToggleStyle? { nil }
}

extension EnvironmentValues {

    internal var toggleStyle: AnyToggleStyle {
        get { self[ToggleStyleKey.self] ?? MainActor.assumeIsolated { AnyToggleStyle(SwitchToggleStyle()) } }
        set { self[ToggleStyleKey.self] = newValue }
    }
}

extension View {

    /// Sets the style for toggles in a view hierarchy.
    public func toggleStyle<S: ToggleStyle>(_ style: S) -> some View {
        environment(\.toggleStyle, AnyToggleStyle(style))
    }
}

// MARK: - Styles

/// The default toggle style: a switch.
public struct DefaultToggleStyle: ToggleStyle {

    public init() { }

    public func makeBody(configuration: Configuration) -> some View {
        SwitchToggleStyle().makeBody(configuration: configuration)
    }
}

/// A toggle style that displays a leading label and a trailing switch.
public struct SwitchToggleStyle: ToggleStyle {

    public init() { }

    public func makeBody(configuration: Configuration) -> some View {
        _Switch(configuration: configuration)
    }
}

private struct _Switch: View {

    let configuration: ToggleStyleConfiguration

    @Environment(\.isEnabled) private var isEnabled

    @Environment(\.labelsHidden) private var labelsHidden

    /// Where a drag has the knob, from the track's leading end, while it's
    /// being dragged.
    @State private var dragPosition: CGFloat?

    private static let trackSize = CGSize(width: 44, height: 26)

    private static let knobSize: CGFloat = 22

    private static let inset: CGFloat = 2

    /// How far the knob moves between off and on.
    private static var travel: CGFloat {
        trackSize.width - knobSize - inset * 2
    }

    private static let animation = Animation.easeOut(duration: 0.18)

    var body: some View {
        let isOn = configuration.$isOn
        let position = dragPosition ?? (isOn.wrappedValue ? Self.travel : 0)
        // Dragged past the middle, the track shows what letting go does.
        let showsOn = position > Self.travel / 2
        HStack {
            if !labelsHidden {
                configuration.label
                Spacer()
            }
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(showsOn ? Color.green : Color.controlFill)
                // A circle takes all the space it's offered, so without a
                // size of its own it would fill the track and sit in its
                // middle.
                Circle()
                    .fill(.white)
                    .frame(width: Self.knobSize, height: Self.knobSize)
                    .padding(Self.inset)
                    .offset(x: position)
            }
            .frame(width: Self.trackSize.width, height: Self.trackSize.height)
            .opacity(isEnabled ? 1 : 0.5)
            // The knob follows a drag, and stays at the end it's let go
            // nearer to: dragged right, the switch is on; left, off.
            .gesture(
                DragGesture(minimumDistance: 6)
                    .onChanged { value in
                        let start: CGFloat = isOn.wrappedValue ? Self.travel : 0
                        dragPosition = min(max(start + value.translation.width, 0), Self.travel)
                    }
                    .onEnded { value in
                        let start: CGFloat = isOn.wrappedValue ? Self.travel : 0
                        let end = min(max(start + value.translation.width, 0), Self.travel)
                        withAnimation(Self.animation) {
                            dragPosition = nil
                            isOn.wrappedValue = end > Self.travel / 2
                        }
                    }
            )
        }
        .contentShape(Rectangle())
        .onTapGesture {
            withAnimation(Self.animation) {
                isOn.wrappedValue.toggle()
            }
        }
    }
}

/// A toggle style that displays a checkbox followed by its label.
public struct CheckboxToggleStyle: ToggleStyle {

    public init() { }

    public func makeBody(configuration: Configuration) -> some View {
        _Checkbox(configuration: configuration)
    }
}

private struct _Checkbox: View {

    let configuration: ToggleStyleConfiguration

    @Environment(\.isEnabled) private var isEnabled

    @Environment(\.labelsHidden) private var labelsHidden

    @Environment(\.interfaceLook) private var look

    var body: some View {
        if look.value == .desktop {
            _DesktopCheckbox(configuration: configuration)
        } else {
            stock
        }
    }

    /// The checkbox in the stock look.
    private var stock: some View {
        let isOn = configuration.$isOn
        return HStack(spacing: 6) {
            ZStack {
                if isOn.wrappedValue {
                    RoundedRectangle(cornerRadius: 4).fill(Color.accentColor)
                    _CheckmarkShape().stroke(Color.white, style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round))
                } else {
                    RoundedRectangle(cornerRadius: 4).strokeBorder(Color.gray, lineWidth: 1)
                }
            }
            .frame(width: 16, height: 16)
            if !labelsHidden {
                configuration.label
            }
        }
        .opacity(isEnabled ? 1 : 0.5)
        .contentShape(Rectangle())
        .onTapGesture { isOn.wrappedValue.toggle() }
    }
}

/// A toggle style that displays as a button with its label as a title.
public struct ButtonToggleStyle: ToggleStyle {

    public init() { }

    public func makeBody(configuration: Configuration) -> some View {
        let isOn = configuration.$isOn
        if isOn.wrappedValue {
            Button { isOn.wrappedValue.toggle() } label: { configuration.label }
                .buttonStyle(.borderedProminent)
        } else {
            Button { isOn.wrappedValue.toggle() } label: { configuration.label }
                .buttonStyle(.bordered)
        }
    }
}

extension ToggleStyle where Self == DefaultToggleStyle {
    public static var automatic: DefaultToggleStyle { DefaultToggleStyle() }
}

extension ToggleStyle where Self == SwitchToggleStyle {
    public static var `switch`: SwitchToggleStyle { SwitchToggleStyle() }
}

extension ToggleStyle where Self == CheckboxToggleStyle {
    public static var checkbox: CheckboxToggleStyle { CheckboxToggleStyle() }
}

extension ToggleStyle where Self == ButtonToggleStyle {
    public static var button: ButtonToggleStyle { ButtonToggleStyle() }
}
