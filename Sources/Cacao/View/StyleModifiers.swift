//
//  StyleModifiers.swift
//  Cacao
//
//  Created by Alsey Coleman Miller on 11/13/26.
//

import Foundation
#if canImport(CoreGraphics)
import CoreGraphics
#endif

// MARK: - Tint

private struct TintKey: EnvironmentKey {
    static let defaultValue: Color? = nil
}

extension EnvironmentValues {

    /// The tint of controls, which `Color.accentColor` resolves to.
    internal var tint: Color? {
        get { self[TintKey.self] }
        set { self[TintKey.self] = newValue }
    }
}

extension View {

    /// Sets the tint color within this view.
    public func tint(_ tint: Color?) -> some View {
        environment(\.tint, tint)
    }

    /// Sets the tint within this view, when the style is a color.
    public func tint<S: ShapeStyle>(_ tint: S?) -> some View {
        environment(\.tint, tint as? Color)
    }

    /// Sets the accent color for this view and the views it contains.
    @available(*, deprecated, renamed: "tint(_:)")
    public func accentColor(_ accentColor: Color?) -> some View {
        tint(accentColor)
    }
}

// MARK: - Border

extension View {

    /// Adds a border to this view with the specified style and width.
    public func border<S: ShapeStyle>(_ content: S, width: CGFloat = 1) -> some View {
        overlay(Rectangle().strokeBorder(content, lineWidth: width))
    }
}

// MARK: - Shadow

/// A shadow drawn behind a view's content.
package struct ShadowEffect: Equatable, Sendable {

    package var color: Color.Resolved

    package var radius: CGFloat

    package var offset: CGSize
}

internal struct ShadowBehavior: UnaryLayoutBehavior, AnimatableBehavior {

    let color: Color.Resolved

    let radius: CGFloat

    let offset: CGSize

    var animatableValues: [Double] {
        color.components + [Double(radius), Double(offset.width), Double(offset.height)]
    }

    func applying(_ values: [Double]) -> any NodeBehavior {
        ShadowBehavior(
            color: Color.Resolved(components: Array(values.prefix(4))),
            radius: CGFloat(values[4]),
            offset: CGSize(width: values[5], height: values[6])
        )
    }

    func sizeThatFits(_ proposal: ProposedViewSize, child: LayoutProxy) -> CGSize {
        child.size(in: proposal)
    }

    func placement(of child: LayoutProxy, size: CGSize, proposal: ProposedViewSize) -> (proposal: ProposedViewSize, origin: CGPoint) {
        (proposal, CGPoint(x: 0, y: 0))
    }

    func displayEffect(node: ViewNode) -> DisplayList.Effect? {
        .shadow(ShadowEffect(color: color, radius: max(0, radius), offset: offset))
    }
}

internal struct _ShadowModifier: ViewModifier, PrimitiveViewModifier {

    let color: Color

    let radius: CGFloat

    let offset: CGSize

    func resolve(content: any View, in context: ResolveContext) -> Resolution {
        Resolution(
            behavior: ShadowBehavior(color: color.resolve(in: context.environment), radius: radius, offset: offset),
            children: [ChildView(key: 0, view: content)]
        )
    }

    typealias Body = Never
}

extension View {

    /// Adds a shadow to this view: its silhouette in the color, blurred by
    /// the radius and moved by the offset.
    public func shadow(color: Color = Color.black.opacity(0.33), radius: CGFloat, x: CGFloat = 0, y: CGFloat = 0) -> some View {
        modifier(_ShadowModifier(color: color, radius: radius, offset: CGSize(width: x, height: y)))
    }
}

// MARK: - Hover

/// The current hovering state and value of the pointer.
public enum HoverPhase: Equatable, Sendable {

    /// The pointer's location moved to the specified point within the view.
    case active(CGPoint)

    /// The pointer exited the view.
    case ended
}

/// A node's hover handlers.
internal struct HoverHandler {

    var hover: ((Bool) -> Void)?

    var continuous: ((HoverPhase) -> Void)?
}

extension View {

    /// Adds an action to perform when the user moves the pointer over or
    /// away from the view's frame.
    public func onHover(perform action: @escaping (Bool) -> Void) -> some View {
        modifier(_AttributesModifier { $0.hover = HoverHandler(hover: action) })
    }

    /// Adds an action to perform when the pointer enters, exits, and moves
    /// over the view.
    public func onContinuousHover(
        coordinateSpace: some CoordinateSpaceProtocol = .local,
        perform action: @escaping (HoverPhase) -> Void
    ) -> some View {
        modifier(_AttributesModifier { $0.hover = HoverHandler(continuous: action) })
    }
}

extension ViewGraph {

    /// Moves the pointer without pressing: views under it start or keep
    /// hovering, and the others stop. `nil` when the pointer leaves the window.
    package func hover(at point: CGPoint?) {
        let path = point.flatMap { root.hitTest($0) } ?? []
        let hovering = path.filter { $0.attributes.hover != nil }
        let ids = Set(hovering.map(\.id))
        for (id, reference) in hoveredNodes where !ids.contains(id) {
            hoveredNodes[id] = nil
            guard let node = reference.node, node.isAttached, let handler = node.attributes.hover else { continue }
            handler.hover?(false)
            handler.continuous?(.ended)
        }
        for node in hovering {
            guard let handler = node.attributes.hover, let point else { continue }
            if hoveredNodes[node.id] == nil {
                hoveredNodes[node.id] = WeakNodeReference(node)
                handler.hover?(true)
            }
            let frame = node.windowFrame
            handler.continuous?(.active(CGPoint(x: point.x - frame.minX, y: point.y - frame.minY)))
        }
    }
}

// MARK: - Keys

/// Key equivalents consist of a letter, punctuation, or function key that
/// can be combined with an optional set of modifier keys to specify a
/// keyboard shortcut.
public struct KeyEquivalent: Hashable, Sendable, ExpressibleByExtendedGraphemeClusterLiteral {

    /// The character value that the key equivalent represents.
    public var character: Character

    public init(_ character: Character) {
        self.character = character
    }

    public init(extendedGraphemeClusterLiteral: Character) {
        self.init(extendedGraphemeClusterLiteral)
    }

    public static let upArrow = KeyEquivalent("\u{F700}")
    public static let downArrow = KeyEquivalent("\u{F701}")
    public static let leftArrow = KeyEquivalent("\u{F702}")
    public static let rightArrow = KeyEquivalent("\u{F703}")
    public static let escape = KeyEquivalent("\u{1B}")
    public static let delete = KeyEquivalent("\u{8}")
    public static let deleteForward = KeyEquivalent("\u{F728}")
    public static let home = KeyEquivalent("\u{F729}")
    public static let end = KeyEquivalent("\u{F72B}")
    public static let pageUp = KeyEquivalent("\u{F72C}")
    public static let pageDown = KeyEquivalent("\u{F72D}")
    public static let clear = KeyEquivalent("\u{F739}")
    public static let tab = KeyEquivalent("\t")
    public static let space = KeyEquivalent(" ")
    public static let `return` = KeyEquivalent("\r")

    /// The key equivalent of a key a host delivered.
    init(_ key: KeyCode) {
        switch key {
        case .left: self = .leftArrow
        case .right: self = .rightArrow
        case .up: self = .upArrow
        case .down: self = .downArrow
        case .home: self = .home
        case .end: self = .end
        case .pageUp: self = .pageUp
        case .pageDown: self = .pageDown
        case .backspace: self = .delete
        case .delete: self = .deleteForward
        case .returnKey: self = .return
        case .escape: self = .escape
        case .tab: self = .tab
        case .space: self = .space
        case let .character(character): self.init(Character(character.lowercased()))
        }
    }
}

/// A set of key modifiers that you can add to a gesture.
public struct EventModifiers: OptionSet, Hashable, Sendable {

    public let rawValue: Int

    public init(rawValue: Int) {
        self.rawValue = rawValue
    }

    public static let capsLock = EventModifiers(rawValue: 1 << 0)
    public static let shift = EventModifiers(rawValue: 1 << 1)
    public static let control = EventModifiers(rawValue: 1 << 2)
    public static let option = EventModifiers(rawValue: 1 << 3)
    public static let command = EventModifiers(rawValue: 1 << 4)
    public static let numericPad = EventModifiers(rawValue: 1 << 5)
    public static let all: EventModifiers = [.capsLock, .shift, .control, .option, .command, .numericPad]

    init(_ modifiers: KeyModifiers) {
        var result: EventModifiers = []
        if modifiers.contains(.shift) { result.insert(.shift) }
        if modifiers.contains(.control) { result.insert(.control) }
        if modifiers.contains(.option) { result.insert(.option) }
        if modifiers.contains(.command) { result.insert(.command) }
        self = result
    }
}

/// Keyboard shortcuts describe combinations of keys on a keyboard that the
/// user can press in order to activate a button or toggle.
public struct KeyboardShortcut: Hashable, Sendable {

    /// The key equivalent that the user presses in conjunction with any
    /// specified modifier keys to activate the shortcut.
    public var key: KeyEquivalent

    /// The modifier keys that the user presses in conjunction with a key
    /// equivalent to activate the shortcut.
    public var modifiers: EventModifiers

    public init(_ key: KeyEquivalent, modifiers: EventModifiers = .command) {
        self.key = key
        self.modifiers = modifiers
    }

    /// The standard keyboard shortcut for the default button, consisting of
    /// the Return key and no modifiers.
    public static let defaultAction = KeyboardShortcut(.return, modifiers: [])

    /// The standard keyboard shortcut for cancelling the in-progress action
    /// or dismissing a prompt, consisting of the Escape key and no modifiers.
    public static let cancelAction = KeyboardShortcut(.escape, modifiers: [])
}

/// The platform's command modifier is control off macOS.
private func matches(_ shortcut: KeyboardShortcut, key: KeyEquivalent, modifiers: EventModifiers) -> Bool {
    var expected = shortcut.modifiers
    #if !os(macOS)
    if expected.contains(.command) {
        expected.remove(.command)
        expected.insert(.control)
    }
    #endif
    return shortcut.key == key && expected == modifiers.subtracting([.capsLock, .numericPad])
}

/// The press of a key while a view has focus.
public struct KeyPress: Sendable {

    /// The phase of the key-press event.
    public let phase: Phases

    /// The key equivalent value for the pressed key.
    public let key: KeyEquivalent

    /// The characters generated by the pressed key as if no modifier keys
    /// applied.
    public let characters: String

    /// The set of modifier keys the user held in addition to the pressed key.
    public let modifiers: EventModifiers

    /// Options for matching different phases of a key-press event.
    public struct Phases: OptionSet, Hashable, Sendable {
        public let rawValue: Int
        public init(rawValue: Int) { self.rawValue = rawValue }
        public static let down = Phases(rawValue: 1 << 0)
        public static let `repeat` = Phases(rawValue: 1 << 1)
        public static let up = Phases(rawValue: 1 << 2)
        public static let all: Phases = [.down, .repeat, .up]
    }

    /// A result value returned from a key-press action that indicates
    /// whether the action consumed the event.
    public enum Result: Sendable {
        case handled
        case ignored
    }
}

/// A node's key-press handler.
internal struct KeyPressHandler {

    let keys: Set<KeyEquivalent>?

    let phases: KeyPress.Phases

    let action: (KeyPress) -> KeyPress.Result
}

extension View {

    /// Assigns a keyboard shortcut to the modified control.
    public func keyboardShortcut(_ key: KeyEquivalent, modifiers: EventModifiers = .command) -> some View {
        keyboardShortcut(KeyboardShortcut(key, modifiers: modifiers))
    }

    /// Assigns a keyboard shortcut to the modified control.
    public func keyboardShortcut(_ shortcut: KeyboardShortcut) -> some View {
        modifier(_AttributesModifier { $0.keyboardShortcut = shortcut })
    }

    /// Assigns an optional keyboard shortcut to the modified control.
    public func keyboardShortcut(_ shortcut: KeyboardShortcut?) -> some View {
        modifier(_AttributesModifier { $0.keyboardShortcut = shortcut })
    }

    /// Performs an action if the user presses a key on a hardware keyboard
    /// while the view has focus.
    public func onKeyPress(_ key: KeyEquivalent, action: @escaping () -> KeyPress.Result) -> some View {
        onKeyPress(keys: [key], phases: .down) { _ in action() }
    }

    /// Performs an action if the user presses a key while the view has focus.
    public func onKeyPress(_ key: KeyEquivalent, phases: KeyPress.Phases, action: @escaping (KeyPress) -> KeyPress.Result) -> some View {
        onKeyPress(keys: [key], phases: phases, action: action)
    }

    /// Performs an action if the user presses one or more keys while the
    /// view has focus.
    public func onKeyPress(keys: Set<KeyEquivalent>, phases: KeyPress.Phases = [.down, .repeat], action: @escaping (KeyPress) -> KeyPress.Result) -> some View {
        modifier(_AttributesModifier { $0.keyPress.append(KeyPressHandler(keys: keys, phases: phases, action: action)) })
    }

    /// Performs an action if the user presses any key while the view has focus.
    public func onKeyPress(phases: KeyPress.Phases = [.down, .repeat], action: @escaping (KeyPress) -> KeyPress.Result) -> some View {
        modifier(_AttributesModifier { $0.keyPress.append(KeyPressHandler(keys: nil, phases: phases, action: action)) })
    }

    /// Specifies if the view is focusable.
    public func focusable(_ isFocusable: Bool = true) -> some View {
        modifier(_AttributesModifier { attributes in
            if isFocusable, attributes.focus == nil {
                attributes.focus = FocusTarget()
            }
        })
    }
}

extension ViewGraph {

    /// Delivers a key to key-press handlers around the focused view, then to
    /// keyboard shortcuts. Returns whether one handled it.
    func handleKeyPress(_ key: KeyCode, modifiers: KeyModifiers) -> Bool {
        let equivalent = KeyEquivalent(key)
        let eventModifiers = EventModifiers(modifiers)
        let characters: String
        if case let .character(character) = key {
            characters = String(character)
        } else {
            characters = String(equivalent.character)
        }
        let press = KeyPress(phase: .down, key: equivalent, characters: characters, modifiers: eventModifiers)
        var node = focusedNode?.isAttached == true ? focusedNode : nil
        while let current = node {
            for handler in current.attributes.keyPress where handler.phases.contains(.down) {
                if handler.keys.map({ $0.contains(equivalent) }) ?? true, handler.action(press) == .handled {
                    return true
                }
            }
            node = current.parent
        }
        // A shortcut presses the first control it's on.
        var target: ViewNode?
        root.forEachDisplayedNode { node in
            guard target == nil, let shortcut = node.attributes.keyboardShortcut,
                  matches(shortcut, key: equivalent, modifiers: eventModifiers) else { return }
            target = node.firstNode { $0.attributes.tap != nil }
        }
        if let action = target?.attributes.tap?.action {
            action()
            return true
        }
        return false
    }
}

// MARK: - Color scheme

private struct PreferredColorSchemeKey: PreferenceKey {

    static let defaultValue: ColorScheme? = nil

    static func reduce(value: inout ColorScheme?, nextValue: () -> ColorScheme?) {
        value = value ?? nextValue()
    }
}

extension View {

    /// Sets the preferred color scheme for this presentation.
    public func preferredColorScheme(_ colorScheme: ColorScheme?) -> some View {
        preference(key: PreferredColorSchemeKey.self, value: colorScheme)
    }
}

extension ViewGraph {

    /// The color scheme the window's views prefer, if any.
    package var preferredColorScheme: ColorScheme? {
        PreferenceKeyInfo(PreferredColorSchemeKey.self).value([root]) as? ColorScheme
    }
}

// MARK: - Text

/// A scheme for transforming the capitalization of characters within text.
public enum TextCase: Hashable, Sendable {
    case uppercase
    case lowercase
}

/// The type of truncation to apply to a line of text when it's too long to
/// fit in the available space.
public enum TruncationMode: Hashable, Sendable {
    case head
    case tail
    case middle
}

extension Text {

    /// The type of truncation to apply to a line of text when it's too long
    /// to fit in the available space.
    public typealias TruncationMode = Cacao.TruncationMode
}

private struct TruncationModeKey: EnvironmentKey {
    static let defaultValue = TruncationMode.tail
}

private struct MinimumScaleFactorKey: EnvironmentKey {
    static let defaultValue: CGFloat = 1
}

extension EnvironmentValues {

    /// A value that indicates how the layout truncates the last line of
    /// text to fit into the available space.
    public var truncationMode: TruncationMode {
        get { self[TruncationModeKey.self] }
        set { self[TruncationModeKey.self] = newValue }
    }

    /// The minimum permissible proportion to shrink the font size to fit
    /// the text into the available space.
    public var minimumScaleFactor: CGFloat {
        get { self[MinimumScaleFactorKey.self] }
        set { self[MinimumScaleFactorKey.self] = newValue }
    }
}

private struct TextCaseKey: EnvironmentKey {
    static let defaultValue: TextCase? = nil
}

extension EnvironmentValues {

    /// A stylistic override to transform the case of strings.
    public var textCase: TextCase? {
        get { self[TextCaseKey.self] }
        set { self[TextCaseKey.self] = newValue }
    }
}

extension View {

    /// Sets a transform for the case of the text contained in this view
    /// when displayed.
    public func textCase(_ textCase: TextCase?) -> some View {
        environment(\.textCase, textCase)
    }

    /// Sets the truncation mode for lines of text that are too long to fit
    /// in the available space.
    public func truncationMode(_ mode: TruncationMode) -> some View {
        environment(\.truncationMode, mode)
    }

    /// Sets the minimum amount that text in this view scales down to fit in
    /// the available space.
    public func minimumScaleFactor(_ factor: CGFloat) -> some View {
        environment(\.minimumScaleFactor, min(max(factor, 0.01), 1))
    }

    /// Sets the amount of space between lines of text in this view.
    public func lineSpacing(_ lineSpacing: CGFloat) -> some View {
        environment(\.lineSpacing, lineSpacing)
    }

    /// Sets whether text in this view can compress the space between
    /// characters when necessary to fit text in a line.
    public func allowsTightening(_ flag: Bool) -> some View { self }
}

extension View {

    /// Sets the font weight of the text in this view.
    public func fontWeight(_ weight: Font.Weight?) -> some View {
        transformEnvironment(\.font) { font in
            if let weight {
                font = (font ?? .body).weight(weight)
            }
        }
    }

    /// Applies a bold font weight to the text in this view.
    public func bold(_ isActive: Bool = true) -> some View {
        fontWeight(isActive ? .bold : nil)
    }

    /// Applies italics to the text in this view.
    public func italic(_ isActive: Bool = true) -> some View {
        transformEnvironment(\.font) { font in
            if isActive {
                font = (font ?? .body).italic()
            }
        }
    }
}

extension Text {

    /// A line style for underlines and strikethroughs.
    public struct LineStyle: Hashable, Sendable {

        /// The pattern of a line.
        public enum Pattern: Hashable, Sendable {
            case solid
            case dot
            case dash
            case dashDot
            case dashDotDot
        }

        internal let pattern: Pattern

        internal let color: Color?

        public init(pattern: Pattern = .solid, color: Color? = nil) {
            self.pattern = pattern
            self.color = color
        }

        public static let single = LineStyle()
    }

    private func modifyingRuns(_ body: (inout Run) -> Void) -> Text {
        var text = self
        for index in text.runs.indices {
            body(&text.runs[index])
        }
        return text
    }

    /// Applies an underline to the text.
    public func underline(_ isActive: Bool = true, pattern: LineStyle.Pattern = .solid, color: Color? = nil) -> Text {
        modifyingRuns { $0.underline = $0.underline ?? Decoration(isActive: isActive, pattern: pattern, color: color) }
    }

    /// Applies a strikethrough to the text.
    public func strikethrough(_ isActive: Bool = true, pattern: LineStyle.Pattern = .solid, color: Color? = nil) -> Text {
        modifyingRuns { $0.strikethrough = $0.strikethrough ?? Decoration(isActive: isActive, pattern: pattern, color: color) }
    }

    /// Sets the spacing, or kerning, between characters.
    public func kerning(_ kerning: CGFloat) -> Text {
        modifyingRuns { $0.kerning = $0.kerning ?? kerning }
    }

    /// Sets the tracking for the text.
    public func tracking(_ tracking: CGFloat) -> Text {
        modifyingRuns { $0.tracking = $0.tracking ?? tracking }
    }

    /// Sets the vertical offset for the text relative to its baseline.
    public func baselineOffset(_ baselineOffset: CGFloat) -> Text {
        modifyingRuns { $0.baselineOffset = $0.baselineOffset ?? baselineOffset }
    }
}

/// Text attributes set on views, for the text inside them.
internal struct TextAttributes: Hashable, Sendable {
    var underline: Text.Decoration?
    var strikethrough: Text.Decoration?
    var kerning: CGFloat?
    var tracking: CGFloat?
    var baselineOffset: CGFloat?
}

private struct TextAttributesKey: EnvironmentKey {
    static let defaultValue = TextAttributes()
}

private struct LineSpacingKey: EnvironmentKey {
    static let defaultValue: CGFloat = 0
}

extension EnvironmentValues {

    internal var textAttributes: TextAttributes {
        get { self[TextAttributesKey.self] }
        set { self[TextAttributesKey.self] = newValue }
    }

    /// The distance in points between the bottom of one line fragment and
    /// the top of the next.
    public var lineSpacing: CGFloat {
        get { self[LineSpacingKey.self] }
        set { self[LineSpacingKey.self] = newValue }
    }
}

extension View {

    /// Applies an underline to the text in this view.
    public func underline(_ isActive: Bool = true, pattern: Text.LineStyle.Pattern = .solid, color: Color? = nil) -> some View {
        transformEnvironment(\.textAttributes) { $0.underline = Text.Decoration(isActive: isActive, pattern: pattern, color: color) }
    }

    /// Applies a strikethrough to the text in this view.
    public func strikethrough(_ isActive: Bool = true, pattern: Text.LineStyle.Pattern = .solid, color: Color? = nil) -> some View {
        transformEnvironment(\.textAttributes) { $0.strikethrough = Text.Decoration(isActive: isActive, pattern: pattern, color: color) }
    }

    /// Sets the spacing, or kerning, between characters for the text in this view.
    public func kerning(_ kerning: CGFloat) -> some View {
        transformEnvironment(\.textAttributes) { $0.kerning = kerning }
    }

    /// Sets the tracking for the text in this view.
    public func tracking(_ tracking: CGFloat) -> some View {
        transformEnvironment(\.textAttributes) { $0.tracking = tracking }
    }

    /// Sets the vertical offset for the text relative to its baseline in this view.
    public func baselineOffset(_ baselineOffset: CGFloat) -> some View {
        transformEnvironment(\.textAttributes) { $0.baselineOffset = baselineOffset }
    }
}

// MARK: - Scrolling

/// The visibility of scroll indicators of a UI element.
public struct ScrollIndicatorVisibility: Equatable, Sendable {

    let isVisible: Bool

    public static var automatic: ScrollIndicatorVisibility { ScrollIndicatorVisibility(isVisible: true) }
    public static var visible: ScrollIndicatorVisibility { ScrollIndicatorVisibility(isVisible: true) }
    public static var hidden: ScrollIndicatorVisibility { ScrollIndicatorVisibility(isVisible: false) }
    public static var never: ScrollIndicatorVisibility { ScrollIndicatorVisibility(isVisible: false) }
}

private struct ScrollIndicatorsKey: EnvironmentKey {
    static let defaultValue = true
}

private struct ScrollDisabledKey: EnvironmentKey {
    static let defaultValue = false
}

extension EnvironmentValues {

    /// Whether scroll views in the environment show their indicators.
    internal var showsScrollIndicators: Bool {
        get { self[ScrollIndicatorsKey.self] }
        set { self[ScrollIndicatorsKey.self] = newValue }
    }

    /// A Boolean value that indicates whether any scroll views associated
    /// with this environment allow scrolling to occur.
    public var isScrollEnabled: Bool {
        get { !self[ScrollDisabledKey.self] }
        set { self[ScrollDisabledKey.self] = !newValue }
    }
}

extension View {

    /// Sets the visibility of scroll indicators within this view.
    public func scrollIndicators(_ visibility: ScrollIndicatorVisibility, axes: Axis.Set = [.vertical, .horizontal]) -> some View {
        environment(\.showsScrollIndicators, visibility.isVisible)
    }

    /// Disables or enables scrolling in scrollable views.
    public func scrollDisabled(_ disabled: Bool) -> some View {
        environment(\.isScrollEnabled, !disabled)
    }
}

// MARK: - Platform styling

/// A protocol that describes the behavior and appearance of a list.
public protocol ListStyle { }

public struct DefaultListStyle: ListStyle { public init() { } }
public struct PlainListStyle: ListStyle { public init() { } }
public struct InsetListStyle: ListStyle { public init() { } }
public struct GroupedListStyle: ListStyle { public init() { } }
public struct InsetGroupedListStyle: ListStyle { public init() { } }
public struct SidebarListStyle: ListStyle { public init() { } }

extension ListStyle where Self == DefaultListStyle { public static var automatic: DefaultListStyle { .init() } }
extension ListStyle where Self == PlainListStyle { public static var plain: PlainListStyle { .init() } }
extension ListStyle where Self == InsetListStyle { public static var inset: InsetListStyle { .init() } }
extension ListStyle where Self == GroupedListStyle { public static var grouped: GroupedListStyle { .init() } }
extension ListStyle where Self == InsetGroupedListStyle { public static var insetGrouped: InsetGroupedListStyle { .init() } }
extension ListStyle where Self == SidebarListStyle { public static var sidebar: SidebarListStyle { .init() } }

/// The size classes, like regular or small, that you can apply to controls.
public enum ControlSize: CaseIterable, Hashable, Sendable {
    case mini, small, regular, large, extraLarge
}

/// The kinds of redaction that you can apply to views.
public struct RedactionReasons: OptionSet, Sendable {
    public let rawValue: Int
    public init(rawValue: Int) { self.rawValue = rawValue }
    public static let placeholder = RedactionReasons(rawValue: 1 << 0)
    public static let privacy = RedactionReasons(rawValue: 1 << 1)
    public static let invalidated = RedactionReasons(rawValue: 1 << 2)
}

/// A type indicating the prominence of a view hierarchy.
public enum Prominence: Hashable, Sendable {
    case standard
    case increased
}

/// A type that represents a height where a sheet naturally rests.
public struct PresentationDetent: Hashable, Sendable {
    let id: String
    public static let medium = PresentationDetent(id: "medium")
    public static let large = PresentationDetent(id: "large")
    public static func fraction(_ fraction: CGFloat) -> PresentationDetent { PresentationDetent(id: "fraction \(fraction)") }
    public static func height(_ height: CGFloat) -> PresentationDetent { PresentationDetent(id: "height \(height)") }
}

/// A label for the submit action of text fields.
public struct SubmitLabel: Sendable {
    let id: String
    public static var done: SubmitLabel { SubmitLabel(id: "done") }
    public static var go: SubmitLabel { SubmitLabel(id: "go") }
    public static var send: SubmitLabel { SubmitLabel(id: "send") }
    public static var join: SubmitLabel { SubmitLabel(id: "join") }
    public static var route: SubmitLabel { SubmitLabel(id: "route") }
    public static var search: SubmitLabel { SubmitLabel(id: "search") }
    public static var `return`: SubmitLabel { SubmitLabel(id: "return") }
    public static var next: SubmitLabel { SubmitLabel(id: "next") }
    public static var `continue`: SubmitLabel { SubmitLabel(id: "continue") }
}

/// An action that initiates a refresh operation.
public struct RefreshAction: Sendable {

    let action: @Sendable () async -> Void

    /// Initiates a refresh action.
    public func callAsFunction() async {
        await action()
    }
}

private struct RefreshKey: EnvironmentKey {
    static let defaultValue: RefreshAction? = nil
}

extension EnvironmentValues {

    /// A refresh action stored in a view's environment.
    public var refresh: RefreshAction? {
        get { self[RefreshKey.self] }
        set { self[RefreshKey.self] = newValue }
    }
}

/// The ways that the system can scale an image.
extension Image {

    public enum Scale: Hashable, Sendable {
        case small, medium, large
    }
}

private struct ImageScaleKey: EnvironmentKey {
    static let defaultValue = Image.Scale.medium
}

extension EnvironmentValues {

    /// The image scale for this environment.
    public var imageScale: Image.Scale {
        get { self[ImageScaleKey.self] }
        set { self[ImageScaleKey.self] = newValue }
    }
}

/// A symbol rendering mode.
public struct SymbolRenderingMode: Sendable, Equatable {
    let id: Int
    public static let monochrome = SymbolRenderingMode(id: 0)
    public static let multicolor = SymbolRenderingMode(id: 1)
    public static let hierarchical = SymbolRenderingMode(id: 2)
    public static let palette = SymbolRenderingMode(id: 3)
}

/// An opaque type that describes how a view's content changes.
public struct ContentTransition: Equatable, Sendable {
    let id: Int
    public static let identity = ContentTransition(id: 0)
    public static let opacity = ContentTransition(id: 1)
    public static let interpolate = ContentTransition(id: 2)
    public static func numericText(countsDown: Bool = false) -> ContentTransition { ContentTransition(id: 3) }
}

extension View {

    /// Sets the style for lists within this view. Cacao draws one list style.
    public func listStyle<S: ListStyle>(_ style: S) -> some View { self }

    /// Sets the size for controls within this view. Cacao has one size.
    public func controlSize(_ controlSize: ControlSize) -> some View { self }

    /// Adds a condition that controls whether users can interact with this
    /// view; shows a tooltip on platforms that have them.
    public func help(_ text: String) -> some View { self }

    /// Generates a badge for the view. Cacao doesn't draw badges yet.
    public func badge(_ count: Int) -> some View { self }

    /// Generates a badge for the view. Cacao doesn't draw badges yet.
    public func badge(_ label: Text?) -> some View { self }

    /// Adds a reason to apply a redaction to this view hierarchy.
    public func redacted(reason: RedactionReasons) -> some View { self }

    /// Removes any reason to apply a redaction to this view hierarchy.
    public func unredacted() -> some View { self }

    /// Sets the header prominence for this view.
    public func headerProminence(_ prominence: Prominence) -> some View { self }

    /// Sets the available detents for the enclosing sheet.
    public func presentationDetents(_ detents: Set<PresentationDetent>) -> some View { self }

    /// Sets the visibility of the drag indicator on top of a sheet.
    public func presentationDragIndicator(_ visibility: Visibility) -> some View { self }

    /// Conditionally prevents interactive dismissal of presentations.
    public func interactiveDismissDisabled(_ isDisabled: Bool = true) -> some View { self }

    /// Sets the submit label for this view.
    public func submitLabel(_ submitLabel: SubmitLabel) -> some View { self }

    /// Sets whether to disable autocorrection for this view.
    public func autocorrectionDisabled(_ disable: Bool = true) -> some View { self }

    /// Places a custom background view behind a list row item.
    public func listRowBackground<V: View>(_ view: V?) -> some View { self }

    /// Applies an inset to the rows in a list.
    public func listRowInsets(_ insets: EdgeInsets?) -> some View { self }

    /// Sets the display mode for the separator associated with this list row.
    public func listRowSeparator(_ visibility: Visibility, edges: VerticalEdge.Set = .all) -> some View { self }

    /// Specifies the visibility of the background for scrollable views
    /// within this view.
    public func scrollContentBackground(_ visibility: Visibility) -> some View { self }

    /// Scales images within the view according to one of the relative sizes
    /// available including small, medium, and large images sizes.
    public func imageScale(_ scale: Image.Scale) -> some View {
        environment(\.imageScale, scale)
    }

    /// Sets the rendering mode for symbol images within this view.
    public func symbolRenderingMode(_ mode: SymbolRenderingMode?) -> some View { self }

    /// Modifies the view to use a given transition as its method of
    /// animating changes to the contents of its views.
    public func contentTransition(_ transition: ContentTransition) -> some View { self }

    /// Marks this view as refreshable.
    public func refreshable(action: @escaping @Sendable () async -> Void) -> some View {
        environment(\.refresh, RefreshAction(action: action))
    }
}

extension VerticalEdge {

    /// An efficient set of vertical edges.
    public struct Set: OptionSet, Sendable {
        public let rawValue: Int8
        public init(rawValue: Int8) { self.rawValue = rawValue }
        public static let top = Set(rawValue: 1)
        public static let bottom = Set(rawValue: 2)
        public static let all: Set = [.top, .bottom]
    }
}

// MARK: - LabeledContent

/// A container for attaching a label to a value-bearing view.
public struct LabeledContent<Label: View, Content: View>: View {

    let label: Label

    let content: Content

    /// Creates a standard labeled element, with a view that conveys the value
    /// of the element and a label.
    public init(@ViewBuilder content: () -> Content, @ViewBuilder label: () -> Label) {
        self.content = content()
        self.label = label()
    }

    public var body: some View {
        HStack(alignment: .firstTextBaseline) {
            label
            Spacer(minLength: 8)
            content.foregroundStyle(.secondary)
        }
    }
}

extension LabeledContent where Label == Text {

    /// Creates a labeled view that generates its label from a string.
    public init<S: StringProtocol>(_ title: S, @ViewBuilder content: () -> Content) {
        self.init(content: content) { Text(String(title)) }
    }
}

extension LabeledContent where Label == Text, Content == Text {

    /// Creates a labeled informational view.
    public init<S1: StringProtocol, S2: StringProtocol>(_ title: S1, value: S2) {
        self.init(content: { Text(String(value)) }, label: { Text(String(title)) })
    }
}

// MARK: - ContentUnavailableView

/// An interface, consisting of a label and additional content, that you
/// display when the content of your app is unavailable to users.
public struct ContentUnavailableView<Label: View, Description: View, Actions: View>: View {

    let label: Label

    let description: Description

    let actions: Actions

    /// Creates an interface, consisting of a label and additional content,
    /// that you display when the content of your app is unavailable to users.
    public init(
        @ViewBuilder label: () -> Label,
        @ViewBuilder description: () -> Description = { EmptyView() },
        @ViewBuilder actions: () -> Actions = { EmptyView() }
    ) {
        self.label = label()
        self.description = description()
        self.actions = actions()
    }

    public var body: some View {
        VStack(spacing: 12) {
            label
                .font(.title2)
                .fontWeight(.bold)
            description
                .font(.callout)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            actions
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

extension ContentUnavailableView where Label == Cacao.Label<Text, Image>, Description == Text?, Actions == EmptyView {

    /// Creates an interface with a title, a system image and a description.
    public init<S: StringProtocol>(_ title: S, systemImage name: String, description: Text? = nil) {
        self.label = Cacao.Label(LocalizedStringKey(String(title)), systemImage: name)
        self.description = description
        self.actions = EmptyView()
    }

    /// Creates an interface for a search with no results.
    public static var search: ContentUnavailableView<Cacao.Label<Text, Image>, Text?, EmptyView> {
        ContentUnavailableView("No Results", systemImage: "magnifyingglass", description: Text("Check the spelling or try a new search."))
    }

    /// Creates an interface for a search with no results for a query.
    public static func search(text: String) -> ContentUnavailableView<Cacao.Label<Text, Image>, Text?, EmptyView> {
        ContentUnavailableView("No Results for \"\(text)\"", systemImage: "magnifyingglass", description: Text("Check the spelling or try a new search."))
    }
}
