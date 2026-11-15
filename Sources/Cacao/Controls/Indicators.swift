//
//  Indicators.swift
//  Cacao
//
//  Created by Alsey Coleman Miller on 11/13/26.
//

import Foundation
#if canImport(CoreGraphics)
import CoreGraphics
#endif

// MARK: - ProgressView

/// A view that shows the progress toward completion of a task.
public struct ProgressView<Label: View, CurrentValueLabel: View>: View {

    /// The completed fraction, or `nil` when indeterminate.
    internal let fraction: Double?

    internal let label: Label?

    internal let currentValueLabel: CurrentValueLabel?

    @Environment(\.progressViewStyle) private var style

    public var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            if let label {
                label
            }
            if fraction == nil || style == .circular {
                _Spinner(fraction: fraction)
            } else {
                _FractionLayout(fraction: fraction ?? 0, trackHeight: 4, thumbSize: 0, idealWidth: 160) {
                    Capsule().fill(Color.controlFill)
                    Capsule().fill(Color.accentColor)
                }
            }
            if let currentValueLabel {
                currentValueLabel
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

extension ProgressView where Label == EmptyView, CurrentValueLabel == EmptyView {

    /// Creates a progress view for showing indeterminate progress.
    public init() {
        self.fraction = nil
        self.label = nil
        self.currentValueLabel = nil
    }

    /// Creates a progress view for showing determinate progress.
    public init<V: BinaryFloatingPoint>(value: V?, total: V = 1.0) {
        self.fraction = value.map { total > 0 ? min(max(Double($0 / total), 0), 1) : 0 }
        self.label = nil
        self.currentValueLabel = nil
    }
}

extension ProgressView where CurrentValueLabel == EmptyView {

    /// Creates a progress view for showing indeterminate progress that
    /// displays a custom label.
    public init(@ViewBuilder label: () -> Label) {
        self.fraction = nil
        self.label = label()
        self.currentValueLabel = nil
    }

    /// Creates a progress view for showing determinate progress, with a label.
    public init<V: BinaryFloatingPoint>(value: V?, total: V = 1.0, @ViewBuilder label: () -> Label) {
        self.fraction = value.map { total > 0 ? min(max(Double($0 / total), 0), 1) : 0 }
        self.label = label()
        self.currentValueLabel = nil
    }
}

extension ProgressView where Label == Text, CurrentValueLabel == EmptyView {

    /// Creates a progress view for showing indeterminate progress that
    /// generates its label from a localized string.
    public init(_ titleKey: LocalizedStringKey) {
        self.init { Text(titleKey) }
    }

    /// Creates a progress view for showing determinate progress that
    /// generates its label from a localized string.
    public init<V: BinaryFloatingPoint>(_ titleKey: LocalizedStringKey, value: V?, total: V = 1.0) {
        self.init(value: value, total: total) { Text(titleKey) }
    }
}

/// A ring, partly drawn: the completed fraction, or a spinning arc when
/// indeterminate.
private struct _Spinner: View {

    let fraction: Double?

    var body: some View {
        if let fraction {
            ring(fraction)
        } else {
            ring(0.3)
                .keyframeAnimator(initialValue: 0.0) { content, turn in
                    content.rotationEffect(.degrees(turn))
                } keyframes: { _ in
                    KeyframeTrack {
                        LinearKeyframe(360.0, duration: 1)
                    }
                }
        }
    }

    private func ring(_ end: Double) -> some View {
        ZStack {
            Circle().stroke(Color.controlFill, lineWidth: 3)
            _ArcShape(start: 0, end: end)
                .stroke(Color.accentColor, style: StrokeStyle(lineWidth: 3, lineCap: .round))
        }
        .frame(width: 20, height: 20)
    }
}

/// The styles of progress views.
public struct ProgressViewStyleKind: Equatable, Sendable {
    internal let name: String
}

/// A progress view style: linear or circular.
public protocol ProgressViewStyle {
    var _kind: ProgressViewStyleKind { get }
}

/// A progress view that visually indicates its progress using a horizontal bar.
public struct LinearProgressViewStyle: ProgressViewStyle {
    public init() { }
    public var _kind: ProgressViewStyleKind { .linear }
}

/// A progress view that uses a circular gauge to indicate progress.
public struct CircularProgressViewStyle: ProgressViewStyle {
    public init() { }
    public var _kind: ProgressViewStyleKind { .circular }
}

extension ProgressViewStyleKind {
    static let linear = ProgressViewStyleKind(name: "linear")
    static let circular = ProgressViewStyleKind(name: "circular")
}

extension ProgressViewStyle where Self == LinearProgressViewStyle {
    public static var linear: LinearProgressViewStyle { LinearProgressViewStyle() }
}

extension ProgressViewStyle where Self == CircularProgressViewStyle {
    public static var circular: CircularProgressViewStyle { CircularProgressViewStyle() }
}

private struct ProgressViewStyleKey: EnvironmentKey {
    static let defaultValue = ProgressViewStyleKind.linear
}

extension EnvironmentValues {

    internal var progressViewStyle: ProgressViewStyleKind {
        get { self[ProgressViewStyleKey.self] }
        set { self[ProgressViewStyleKey.self] = newValue }
    }
}

extension View {

    /// Sets the style for progress views in this view.
    public func progressViewStyle<S: ProgressViewStyle>(_ style: S) -> some View {
        environment(\.progressViewStyle, style._kind)
    }
}

// MARK: - Label

/// A standard label for user interface items, consisting of an icon with a
/// title.
public struct Label<Title: View, Icon: View>: View {

    internal let title: Title

    internal let icon: Icon

    /// Creates a label with a custom title and icon.
    public init(@ViewBuilder title: () -> Title, @ViewBuilder icon: () -> Icon) {
        self.title = title()
        self.icon = icon()
    }

    @Environment(\.labelStyle) private var style

    public var body: some View {
        switch style {
        case .titleOnly:
            title
        case .iconOnly:
            icon
        default:
            HStack(spacing: 8) {
                icon
                title
            }
        }
    }
}

extension Label where Title == Text, Icon == Image {

    /// Creates a label with a system icon image and a title generated from a
    /// localized string.
    public init(_ titleKey: LocalizedStringKey, systemImage name: String) {
        self.init(title: { Text(titleKey) }, icon: { Image(systemName: name) })
    }

    /// Creates a label with an icon image and a title generated from a
    /// localized string.
    public init(_ titleKey: LocalizedStringKey, image name: String) {
        self.init(title: { Text(titleKey) }, icon: { Image(name) })
    }
}

/// The styles of labels.
public struct LabelStyleKind: Equatable, Sendable {
    internal let name: String
    static let titleAndIcon = LabelStyleKind(name: "titleAndIcon")
    static let titleOnly = LabelStyleKind(name: "titleOnly")
    static let iconOnly = LabelStyleKind(name: "iconOnly")
}

/// A label style.
public protocol LabelStyle {
    var _kind: LabelStyleKind { get }
}

/// A label style that shows both the title and icon of the label.
public struct TitleAndIconLabelStyle: LabelStyle {
    public init() { }
    public var _kind: LabelStyleKind { .titleAndIcon }
}

/// A label style that only displays the title of the label.
public struct TitleOnlyLabelStyle: LabelStyle {
    public init() { }
    public var _kind: LabelStyleKind { .titleOnly }
}

/// A label style that only displays the icon of the label.
public struct IconOnlyLabelStyle: LabelStyle {
    public init() { }
    public var _kind: LabelStyleKind { .iconOnly }
}

extension LabelStyle where Self == TitleAndIconLabelStyle {
    public static var titleAndIcon: TitleAndIconLabelStyle { TitleAndIconLabelStyle() }
}

extension LabelStyle where Self == TitleOnlyLabelStyle {
    public static var titleOnly: TitleOnlyLabelStyle { TitleOnlyLabelStyle() }
}

extension LabelStyle where Self == IconOnlyLabelStyle {
    public static var iconOnly: IconOnlyLabelStyle { IconOnlyLabelStyle() }
}

private struct LabelStyleKey: EnvironmentKey {
    static let defaultValue = LabelStyleKind.titleAndIcon
}

extension EnvironmentValues {

    internal var labelStyle: LabelStyleKind {
        get { self[LabelStyleKey.self] }
        set { self[LabelStyleKey.self] = newValue }
    }
}

extension View {

    /// Sets the style for labels within this view.
    public func labelStyle<S: LabelStyle>(_ style: S) -> some View {
        environment(\.labelStyle, style._kind)
    }
}

// MARK: - Link

/// An action that opens a URL.
public struct OpenURLAction: Sendable {

    internal let handler: @MainActor @Sendable (URL) -> Void

    /// Creates an action that opens a URL.
    public init(handler: @escaping @MainActor @Sendable (URL) -> Void) {
        self.handler = handler
    }

    /// Opens a URL.
    @MainActor
    public func callAsFunction(_ url: URL) {
        handler(url)
    }
}

private struct OpenURLKey: EnvironmentKey {
    static let defaultValue = OpenURLAction { _ in }
}

extension EnvironmentValues {

    /// Opens a URL; the host opens it with the system's browser.
    public var openURL: OpenURLAction {
        get { self[OpenURLKey.self] }
        set { self[OpenURLKey.self] = newValue }
    }
}

/// A control for navigating to a URL.
public struct Link<Label: View>: View {

    internal let destination: URL

    internal let label: Label

    @Environment(\.openURL) private var openURL

    /// Creates a control, consisting of a URL and a label, used to navigate
    /// to the given URL.
    public init(destination: URL, @ViewBuilder label: () -> Label) {
        self.destination = destination
        self.label = label()
    }

    public var body: some View {
        let openURL = self.openURL
        let destination = self.destination
        Button { openURL(destination) } label: { label }
            .buttonStyle(.borderless)
            .pointerStyle(.link)
    }
}

extension Link where Label == Text {

    /// Creates a control, consisting of a URL and a title key, used to
    /// navigate to a URL.
    public init(_ titleKey: LocalizedStringKey, destination: URL) {
        self.init(destination: destination) { Text(titleKey) }
    }

    /// Creates a control, consisting of a URL and a title string, used to
    /// navigate to a URL.
    @_disfavoredOverload
    public init<S: StringProtocol>(_ title: S, destination: URL) {
        self.init(destination: destination) { Text(title) }
    }
}

// MARK: - DisclosureGroup

/// A view that shows or hides another content view, based on the state of
/// a disclosure control.
public struct DisclosureGroup<Label: View, Content: View>: View {

    internal let label: Label

    internal let content: Content

    internal let isExpandedBinding: Binding<Bool>?

    @State private var isExpandedState = false

    /// Creates a disclosure group with the given label and content views.
    public init(@ViewBuilder content: () -> Content, @ViewBuilder label: () -> Label) {
        self.label = label()
        self.content = content()
        self.isExpandedBinding = nil
    }

    /// Creates a disclosure group with the given label and content views,
    /// and a binding to the expansion state.
    public init(isExpanded: Binding<Bool>, @ViewBuilder content: () -> Content, @ViewBuilder label: () -> Label) {
        self.label = label()
        self.content = content()
        self.isExpandedBinding = isExpanded
    }

    public var body: some View {
        let isExpanded = isExpandedBinding ?? $isExpandedState
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                _ChevronShape(pointsDown: isExpanded.wrappedValue)
                    .stroke(Color.secondary, style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round))
                    .frame(width: 12, height: 12)
                label
                Spacer(minLength: 0)
            }
            .contentShape(Rectangle())
            .onTapGesture { isExpanded.wrappedValue.toggle() }
            if isExpanded.wrappedValue {
                content
                    .padding(.leading, 18)
            }
        }
    }
}

extension DisclosureGroup where Label == Text {

    /// Creates a disclosure group, using a provided localized string key to
    /// create a text view for the label.
    public init(_ titleKey: LocalizedStringKey, @ViewBuilder content: () -> Content) {
        self.init(content: content) { Text(titleKey) }
    }

    /// Creates a disclosure group with a title and a binding to the
    /// expansion state.
    public init(_ titleKey: LocalizedStringKey, isExpanded: Binding<Bool>, @ViewBuilder content: () -> Content) {
        self.init(isExpanded: isExpanded, content: content) { Text(titleKey) }
    }
}
