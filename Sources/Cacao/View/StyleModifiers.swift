//
//  StyleModifiers.swift
//  Cacao
//
//  Created by Alsey Coleman Miller on 11/13/26.
//

import CacaoRender
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
        pointerStyle = Self.pointerStyle(along: path)
        // Help text shows once the pointer rests on its view.
        let help = path.reversed().lazy.compactMap(\.attributes.help).first
        if help != (tooltip?.text ?? pendingTooltip?.text) {
            hideTooltip()
            if let help, let point {
                pendingTooltip = (help, point, time + Self.tooltipDelay)
            }
        } else if let point, pendingTooltip != nil {
            pendingTooltip?.location = point
        }
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

// MARK: - Tooltips

extension ViewGraph {

    /// How long the pointer rests on a view before its help shows.
    static let tooltipDelay = 1.0

    /// Shows help text whose pointer has rested long enough.
    func showTooltipIfDue() {
        guard let pending = pendingTooltip, time >= pending.time else { return }
        pendingTooltip = nil
        tooltip = (pending.text, pending.location)
        root.invalidate()
    }

    /// Hides the tooltip, as when the pointer moves on or presses.
    func hideTooltip() {
        pendingTooltip = nil
        if tooltip != nil {
            tooltip = nil
            root.invalidate()
        }
    }

    /// Whether a tooltip is showing, and its text.
    package var tooltipText: String? {
        tooltip?.text
    }
}

/// Help text shown in a small box near the pointer.
internal struct _Tooltip: View {

    let text: String

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        Text(text)
            .font(.callout)
            .padding(.horizontal, 6)
            .padding(.vertical, 3)
            .background {
                RoundedRectangle(cornerRadius: 4).fill(Color.controlBackground(colorScheme))
            }
            .overlay {
                RoundedRectangle(cornerRadius: 4).strokeBorder(Color.separator, lineWidth: 1)
            }
            .allowsHitTesting(false)
            .accessibilityHidden(true)
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

    package init(_ modifiers: KeyModifiers) {
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

    /// Sets up an action that triggers in response to the system's exit
    /// command: Escape, while the view or a descendant has focus.
    public func onExitCommand(perform action: (() -> Void)?) -> some View {
        onKeyPress(.escape) {
            guard let action else { return .ignored }
            action()
            return .handled
        }
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
        modifier(_FocusEnvironmentModifier())
            .modifier(_AttributesModifier { attributes in
                if isFocusable, attributes.focus == nil {
                    attributes.focus = FocusTarget()
                }
            })
    }
}

extension View {

    /// Indicates that the view's frame and cohort of focusable descendants
    /// should be used to guide focus movement.
    ///
    /// Cacao moves focus in the order of the views, so this changes nothing.
    public func focusSection() -> some View {
        self
    }
}

private struct IsFocusedKey: EnvironmentKey {
    static let defaultValue = false
}

extension EnvironmentValues {

    /// Returns whether the nearest focusable ancestor has focus.
    public var isFocused: Bool {
        get { self[IsFocusedKey.self] }
        set { self[IsFocusedKey.self] = newValue }
    }
}

/// Tells the views of a focusable view whether it has focus, through the
/// environment, again each time focus moves.
internal struct _FocusEnvironmentModifier: ViewModifier, PrimitiveViewModifier {

    func resolve(content: any View, in context: ResolveContext) -> Resolution {
        let node = context.node
        context.graph.focusEnvironmentNodes[node.id] = WeakNodeReference(node)
        // The focusable view: the nearest node around this one that takes focus.
        var target = node.parent
        while let candidate = target, candidate.attributes.focus == nil {
            target = candidate.parent
        }
        var environment = context.environment
        environment.isFocused = target != nil && target === context.graph.focusedNode
        return Resolution(children: [ChildView(key: 0, view: content, environment: environment)])
    }

    typealias Body = Never
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

extension Text {

    /// The type of truncation to apply to a line of text when it's too long
    /// to fit in the available space.
    public typealias TruncationMode = CacaoRender.TruncationMode
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
        public typealias Pattern = TextLinePattern

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

/// An effect applied when the pointer hovers over a view.
public struct HoverEffect: Sendable {

    private let name: String

    /// An effect that attempts to determine the effect automatically.
    public static let automatic = HoverEffect(name: "automatic")

    /// An effect that morphs the pointer into a platter behind the view.
    public static let highlight = HoverEffect(name: "highlight")

    /// An effect that slides the pointer under the view and scales it up.
    public static let lift = HoverEffect(name: "lift")
}

/// The visibility of scroll indicators of a UI element.
public struct ScrollIndicatorVisibility: Equatable, Sendable {

    internal enum Kind: Sendable {
        case automatic
        case visible
        case hidden
    }

    internal let kind: Kind

    /// Whether the indicators ever show.
    internal var isVisible: Bool { kind != .hidden }

    /// Scroll indicators show while scrolling, and fade out after.
    public static var automatic: ScrollIndicatorVisibility { ScrollIndicatorVisibility(kind: .automatic) }

    /// Scroll indicators stay visible.
    public static var visible: ScrollIndicatorVisibility { ScrollIndicatorVisibility(kind: .visible) }

    /// Scroll indicators are hidden.
    public static var hidden: ScrollIndicatorVisibility { ScrollIndicatorVisibility(kind: .hidden) }

    /// Scroll indicators are never shown.
    public static var never: ScrollIndicatorVisibility { ScrollIndicatorVisibility(kind: .hidden) }
}

private struct ScrollIndicatorsKey: EnvironmentKey {
    static let defaultValue = ScrollIndicatorVisibility.automatic
}

private struct ScrollDisabledKey: EnvironmentKey {
    static let defaultValue = false
}

private struct ScrollClipDisabledKey: EnvironmentKey {
    static let defaultValue = false
}

extension EnvironmentValues {

    /// How scroll views in the environment show their indicators.
    internal var scrollIndicatorVisibility: ScrollIndicatorVisibility {
        get { self[ScrollIndicatorsKey.self] }
        set { self[ScrollIndicatorsKey.self] = newValue }
    }

    /// Whether scroll views in the environment draw content outside their
    /// bounds.
    internal var isScrollClipDisabled: Bool {
        get { self[ScrollClipDisabledKey.self] }
        set { self[ScrollClipDisabledKey.self] = newValue }
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
        environment(\.scrollIndicatorVisibility, visibility)
    }

    /// Sets whether a scroll view clips its content to its bounds.
    public func scrollClipDisabled(_ disabled: Bool = true) -> some View {
        environment(\.isScrollClipDisabled, disabled)
    }

    /// Applies a hover effect to this view.
    ///
    /// Cacao has no system hover effects, so this draws nothing.
    public func hoverEffect(_ effect: HoverEffect = .automatic, isEnabled: Bool = true) -> some View {
        self
    }

    /// Disables or enables scrolling in scrollable views.
    public func scrollDisabled(_ disabled: Bool) -> some View {
        environment(\.isScrollEnabled, !disabled)
    }
}

// MARK: - Platform styling

/// A protocol that describes the behavior and appearance of a list.
public protocol ListStyle { }

/// A list style that says which of Cacao's list styles it is.
internal protocol _ListStyleKindProviding {
    var kind: ListStyleKind { get }
}

public struct DefaultListStyle: ListStyle, _ListStyleKindProviding { public init() { }; var kind: ListStyleKind { .automatic } }
public struct PlainListStyle: ListStyle, _ListStyleKindProviding { public init() { }; var kind: ListStyleKind { .plain } }
public struct InsetListStyle: ListStyle, _ListStyleKindProviding { public init() { }; var kind: ListStyleKind { .inset } }
public struct GroupedListStyle: ListStyle, _ListStyleKindProviding { public init() { }; var kind: ListStyleKind { .grouped } }
public struct InsetGroupedListStyle: ListStyle, _ListStyleKindProviding { public init() { }; var kind: ListStyleKind { .insetGrouped } }
public struct SidebarListStyle: ListStyle, _ListStyleKindProviding { public init() { }; var kind: ListStyleKind { .sidebar } }

private struct ListStyleKindKey: EnvironmentKey {
    static let defaultValue = ListStyleKind.automatic
}

private struct ScrollContentBackgroundKey: EnvironmentKey {
    static let defaultValue = Visibility.automatic
}

extension EnvironmentValues {

    /// The style of lists in this environment.
    internal var listStyleKind: ListStyleKind {
        get { self[ListStyleKindKey.self] }
        set { self[ListStyleKindKey.self] = newValue }
    }

    /// Whether scrollable views like grouped lists draw their background.
    internal var scrollContentBackgroundVisibility: Visibility {
        get { self[ScrollContentBackgroundKey.self] }
        set { self[ScrollContentBackgroundKey.self] = newValue }
    }
}

extension View {

    /// Sets the style for lists within this view.
    public func listStyle<S: ListStyle>(_ style: S) -> some View {
        environment(\.listStyleKind, (style as? any _ListStyleKindProviding)?.kind ?? .automatic)
    }

    /// Specifies the visibility of the background for scrollable views
    /// within this view: a grouped list's background.
    public func scrollContentBackground(_ visibility: Visibility) -> some View {
        environment(\.scrollContentBackgroundVisibility, visibility)
    }

    /// Places a custom background view behind a list row item.
    public func listRowBackground<V: View>(_ view: V?) -> some View {
        var traits = ListRowTraits()
        if let view {
            traits.background = AnyView(view)
            traits.backgroundIdentity = (view as? any Hashable).map { AnyHashable($0) } ?? AnyHashable(ObjectIdentifier(V.self))
        }
        return transformPreference(ListRowTraitsKey.self) { $0 = traits.merging($0) }
    }

    /// Applies an inset to the rows in a list; `nil` for the default.
    public func listRowInsets(_ insets: EdgeInsets?) -> some View {
        var traits = ListRowTraits()
        traits.insets = insets
        return transformPreference(ListRowTraitsKey.self) { $0 = traits.merging($0) }
    }

    /// Sets the display mode for the separator associated with this list row.
    public func listRowSeparator(_ visibility: Visibility, edges: VerticalEdge.Set = .all) -> some View {
        var traits = ListRowTraits()
        traits.hiddenSeparators = visibility == .hidden ? edges : []
        return transformPreference(ListRowTraitsKey.self) { $0 = traits.merging($0) }
    }

    /// Sets the tint color associated with a row's separator.
    public func listRowSeparatorTint(_ color: Color?, edges: VerticalEdge.Set = .all) -> some View {
        var traits = ListRowTraits()
        traits.separatorTint = color
        return transformPreference(ListRowTraitsKey.self) { $0 = traits.merging($0) }
    }
}

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

private struct ControlSizeKey: EnvironmentKey {
    static let defaultValue = ControlSize.regular
}

private struct RedactionReasonsKey: EnvironmentKey {
    static let defaultValue: RedactionReasons = []
}

extension EnvironmentValues {

    /// The size to apply to controls within a view.
    public var controlSize: ControlSize {
        get { self[ControlSizeKey.self] }
        set { self[ControlSizeKey.self] = newValue }
    }

    /// The current redaction reasons applied to the view hierarchy.
    public var redactionReasons: RedactionReasons {
        get { self[RedactionReasonsKey.self] }
        set { self[RedactionReasonsKey.self] = newValue }
    }
}

extension View {

    /// Sets the size for controls within this view.
    public func controlSize(_ controlSize: ControlSize) -> some View {
        environment(\.controlSize, controlSize)
    }

    /// Adds a reason to apply a redaction to this view hierarchy: with
    /// `placeholder`, text and images show as placeholder shapes.
    public func redacted(reason: RedactionReasons) -> some View {
        transformEnvironment(\.redactionReasons) { $0.formUnion(reason) }
    }

    /// Removes any reason to apply a redaction to this view hierarchy.
    public func unredacted() -> some View {
        environment(\.redactionReasons, [])
    }

    /// Adds help text to a view: a tooltip shown when the pointer rests on
    /// it, and the view's accessibility hint.
    @_disfavoredOverload
    public func help<S: StringProtocol>(_ text: S) -> some View {
        let text = String(text)
        return modifier(_AttributesModifier { attributes in
            attributes.help = text
            var accessibility = attributes.accessibility ?? AccessibilityAttributes()
            if accessibility.hint == nil {
                accessibility.hint = text
            }
            attributes.accessibility = accessibility
        })
    }

    /// Adds help text to a view using a localized string key.
    public func help(_ textKey: LocalizedStringKey) -> some View {
        help(textKey.key)
    }

    /// Adds help text to a view using a text view.
    public func help(_ text: Text) -> some View {
        help(text.plainString)
    }
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
///
/// Text whose string changes in an animated update fades from the old
/// string to the new; numeric text also rolls up, or down when counting
/// down. Interpolation fades too.
public struct ContentTransition: Equatable, Sendable {
    let id: Int
    public static let identity = ContentTransition(id: 0)
    public static let opacity = ContentTransition(id: 1)
    public static let interpolate = ContentTransition(id: 2)
    public static func numericText(countsDown: Bool = false) -> ContentTransition { ContentTransition(id: countsDown ? 4 : 3) }

    /// How the old content leaves and the new arrives.
    var transition: AnyTransition {
        switch id {
        case 3: .asymmetric(insertion: AnyTransition.offset(y: 8).combined(with: .opacity), removal: AnyTransition.offset(y: -8).combined(with: .opacity))
        case 4: .asymmetric(insertion: AnyTransition.offset(y: -8).combined(with: .opacity), removal: AnyTransition.offset(y: 8).combined(with: .opacity))
        default: .opacity
        }
    }
}

private struct ContentTransitionKey: EnvironmentKey {
    static let defaultValue = ContentTransition.identity
}

/// A badge shown on a list row or tab.
internal enum BadgeKey: LayoutValueKey {
    static var defaultValue: Text? { nil }
}

extension EnvironmentValues {

    /// The current method of animating the contents of views.
    public var contentTransition: ContentTransition {
        get { self[ContentTransitionKey.self] }
        set { self[ContentTransitionKey.self] = newValue }
    }
}

extension View {

    /// Modifies the view to use a given transition as its method of
    /// animating changes to the contents of its views.
    public func contentTransition(_ transition: ContentTransition) -> some View {
        environment(\.contentTransition, transition)
    }

    /// Generates a badge for the view from an integer value; zero shows none.
    public func badge(_ count: Int) -> some View {
        badge(count == 0 ? nil : Text("\(count)"))
    }

    /// Generates a badge for the view from a string.
    @_disfavoredOverload
    public func badge<S: StringProtocol>(_ label: S?) -> some View {
        badge(label.map { Text($0) })
    }

    /// Generates a badge for the view from a localized string key.
    public func badge(_ key: LocalizedStringKey?) -> some View {
        badge(key.map { Text($0) })
    }

    /// Generates a badge for the view from a text view: on a list row, at
    /// its trailing edge, and on a tab, beside its label.
    public func badge(_ label: Text?) -> some View {
        var traits = LayoutTraits()
        traits[BadgeKey.self] = label
        var rowTraits = ListRowTraits()
        rowTraits.badge = label
        return modifier(_TraitWritingModifier(traits: traits))
            .transformPreference(ListRowTraitsKey.self) { $0 = rowTraits.merging($0) }
    }
}

extension View {






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


    /// Scales images within the view according to one of the relative sizes
    /// available including small, medium, and large images sizes.
    public func imageScale(_ scale: Image.Scale) -> some View {
        environment(\.imageScale, scale)
    }

    /// Sets the rendering mode for symbol images within this view.
    public func symbolRenderingMode(_ mode: SymbolRenderingMode?) -> some View { self }


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
