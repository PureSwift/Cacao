//
//  Focus.swift
//  Cacao
//
//  Created by Alsey Coleman Miller on 11/13/26.
//

import CacaoRender
import Foundation
#if canImport(CoreGraphics)
import CoreGraphics
#endif

// MARK: - Keys

/// A key a host delivers to the focused view.
package enum KeyCode: Hashable, Sendable {
    case left
    case right
    case up
    case down
    case home
    case end
    case pageUp
    case pageDown
    case backspace
    case delete
    case returnKey
    case escape
    case tab
    case space
    /// A key that types a character, delivered with modifiers held; plain
    /// typing arrives as text input instead.
    case character(Character)
}

/// The modifier keys held with a key.
package struct KeyModifiers: OptionSet, Hashable, Sendable {

    package let rawValue: Int

    package init(rawValue: Int) {
        self.rawValue = rawValue
    }

    package static let shift = KeyModifiers(rawValue: 1 << 0)
    package static let control = KeyModifiers(rawValue: 1 << 1)
    package static let option = KeyModifiers(rawValue: 1 << 2)
    package static let command = KeyModifiers(rawValue: 1 << 3)

    /// The modifier that moves the caret by words: option on macOS,
    /// control elsewhere.
    package static var wordMovement: KeyModifiers {
        #if os(macOS)
        return .option
        #else
        return .control
        #endif
    }

    /// The modifier that moves the caret to the ends of lines and text:
    /// command on macOS, none elsewhere (which has home and end keys).
    package static var lineMovement: KeyModifiers {
        #if os(macOS)
        return .command
        #else
        return KeyModifiers(rawValue: 1 << 30)
        #endif
    }

    /// The platform's shortcut modifier: command on macOS, control elsewhere.
    package static var shortcut: KeyModifiers {
        #if os(macOS)
        .command
        #else
        .control
        #endif
    }
}

/// Reads and writes the system clipboard; provided by the host.
package struct Clipboard {

    package var read: () -> String?

    package var write: (String) -> Void

    package init(read: @escaping () -> String?, write: @escaping (String) -> Void) {
        self.read = read
        self.write = write
    }
}

// MARK: - Focus targets

/// What a focusable view does with keyboard input.
internal struct FocusTarget {

    /// Whether the view takes typed text, so the host should start text
    /// input (and an input method).
    var acceptsText = false

    /// Handles a key; returns whether it did.
    var keyDown: @MainActor (KeyCode, KeyModifiers) -> Bool = { _, _ in false }

    /// Inserts typed text.
    var insertText: @MainActor (String) -> Void = { _ in }

    /// Called when the view gains or loses focus.
    var focusChanged: @MainActor (Bool) -> Void = { _ in }
}

/// A binding from `focused(_:)` between a focus state and the focusable
/// view in the node's subtree.
internal struct FocusBinding {

    /// Whether the focus state asks for the view to be focused.
    var isRequested: Bool

    /// Sets the focus state when focus moves into or out of the view.
    var set: (Bool) -> Void
}

/// A drag recognized on a node's views, in the window's coordinate space.
internal struct DragHandler {

    var onChanged: @MainActor (_ start: CGPoint, _ location: CGPoint, _ frame: CGRect) -> Void

    var onEnded: @MainActor (_ start: CGPoint, _ location: CGPoint, _ frame: CGRect) -> Void
}

// MARK: - Graph

extension ViewGraph {

    /// The focused view's node.
    var focusedNode: ViewNode? {
        get { focusedNodeReference.node }
        set { focusedNodeReference.node = newValue }
    }

    /// Whether the focused view takes typed text.
    package var acceptsTextInput: Bool {
        guard let node = focusedNode, node.isAttached else { return false }
        return node.attributes.focus?.acceptsText ?? false
    }

    /// The focused view's frame in the window, for placing an input
    /// method's candidates.
    package var focusedFrame: CGRect? {
        guard let node = focusedNode, node.isAttached else { return nil }
        return node.windowFrame
    }

    /// Moves focus to a node with a focus target, or clears it.
    func focus(_ node: ViewNode?) {
        let previous = focusedNode
        guard previous !== node else { return }
        focusedNode = node
        previous?.attributes.focus?.focusChanged(false)
        node?.attributes.focus?.focusChanged(true)
        // Focusable views' content reads whether they have focus.
        focusEnvironmentNodes = focusEnvironmentNodes.filter { $0.value.node?.isAttached == true }
        for reference in focusEnvironmentNodes.values {
            reference.node?.invalidate()
        }
        syncFocusBindings()
    }

    /// Focusable nodes in tree order.
    func focusableNodes() -> [ViewNode] {
        var nodes: [ViewNode] = []
        root.forEachNode { node in
            if node.attributes.focus != nil {
                nodes.append(node)
            }
        }
        return nodes
    }

    /// Delivers a key: first to the focused view, then Tab moves focus and
    /// Escape dismisses popups or clears focus.
    @discardableResult
    package func keyDown(_ key: KeyCode, modifiers: KeyModifiers = []) -> Bool {
        if let node = focusedNode, node.isAttached, let target = node.attributes.focus,
           target.keyDown(key, modifiers) {
            return true
        }
        if handleKeyPress(key, modifiers: modifiers) {
            return true
        }
        switch key {
        case .tab:
            let nodes = focusableNodes()
            guard !nodes.isEmpty else { return false }
            let current = focusedNode.flatMap { node in nodes.firstIndex { $0 === node } }
            let next: Int
            if modifiers.contains(.shift) {
                next = ((current ?? 0) - 1 + nodes.count) % nodes.count
            } else {
                next = current.map { ($0 + 1) % nodes.count } ?? 0
            }
            focus(nodes[next])
            return true
        case .left, .right, .up, .down:
            // In a menu, from item to item.
            if moveInTopPopup(key) {
                return true
            }
            return moveFocus(key)
        case .escape:
            if isPresenting {
                dismissTopPresentation()
                return true
            }
            if focusedNode != nil {
                focus(nil)
                return true
            }
            return false
        default:
            return false
        }
    }

    /// Moves focus from the focused view to the nearest focusable view in
    /// the direction of an arrow key: one in line with it, or else one in a
    /// focus section that's in line with it. Returns whether focus moved.
    func moveFocus(_ direction: KeyCode) -> Bool {
        guard let current = focusedNode, current.isAttached else { return false }
        let from = current.windowFrame
        guard !from.isNull else { return false }
        let isHorizontal = direction == .left || direction == .right
        /// Whether a frame lies past the focused view, that way.
        func isBeyond(_ frame: CGRect) -> Bool {
            switch direction {
            case .left: frame.maxX <= from.minX + 1
            case .right: frame.minX >= from.maxX - 1
            case .up: frame.maxY <= from.minY + 1
            default: frame.minY >= from.maxY - 1
            }
        }
        /// Whether a frame is in line with the focused view.
        func isInLine(_ frame: CGRect) -> Bool {
            isHorizontal
                ? frame.minY < from.maxY && frame.maxY > from.minY
                : frame.minX < from.maxX && frame.maxX > from.minX
        }
        func distance(_ frame: CGRect) -> CGFloat {
            hypot(frame.midX - from.midX, frame.midY - from.midY)
        }
        // Views that show: not those of a tab or a screen that's hidden.
        let candidates = focusableNodes().compactMap { node -> (node: ViewNode, frame: CGRect)? in
            guard node !== current else { return nil }
            let frame = node.windowFrame
            guard !frame.isNull, frame.width > 0, frame.height > 0,
                  root.hitTest(CGPoint(x: frame.midX, y: frame.midY))?.contains(where: { $0 === node }) == true else {
                return nil
            }
            return (node, frame)
        }
        if let next = candidates.filter({ isBeyond($0.frame) && isInLine($0.frame) }).min(by: { distance($0.frame) < distance($1.frame) }) {
            focus(next.node)
            return true
        }
        // A focus section that way takes focus for the views in it.
        var sections: [(node: ViewNode, frame: CGRect)] = []
        root.forEachNode { node in
            guard node.attributes.isFocusSection else { return }
            let frame = node.windowFrame
            if !frame.isNull, isBeyond(frame), isInLine(frame) {
                sections.append((node, frame))
            }
        }
        for section in sections.sorted(by: { distance($0.frame) < distance($1.frame) }) {
            let inside = candidates.filter { candidate in
                var ancestor = candidate.node.parent
                while let node = ancestor {
                    if node === section.node { return true }
                    ancestor = node.parent
                }
                return false
            }
            if let next = inside.min(by: { distance($0.frame) < distance($1.frame) }) {
                focus(next.node)
                return true
            }
        }
        return false
    }

    /// Delivers typed text to the focused view.
    package func insertText(_ text: String) {
        guard let node = focusedNode, node.isAttached, let target = node.attributes.focus, target.acceptsText else {
            // Without a text view, typed characters are key presses.
            for character in text {
                _ = handleKeyPress(.character(character), modifiers: [])
            }
            return
        }
        target.insertText(text)
    }

    /// Focuses views whose focus state asks for it, after an update.
    func applyFocusRequests() {
        root.forEachNode { node in
            guard let binding = node.attributes.focusBinding,
                  let target = node.firstFocusable else {
                return
            }
            let isFocused = focusedNode === target
            if binding.isRequested, !isFocused {
                focus(target)
            } else if !binding.isRequested, isFocused {
                focus(nil)
            }
        }
    }

    /// Tells each focus binding whether focus is in its subtree.
    func syncFocusBindings() {
        root.forEachNode { node in
            guard let binding = node.attributes.focusBinding,
                  let target = node.firstFocusable else {
                return
            }
            let isFocused = focusedNode === target
            if binding.isRequested != isFocused {
                binding.set(isFocused)
            }
        }
    }
}

/// A weak reference to the focused node.
internal final class WeakNodeReference {
    weak var node: ViewNode?
}

extension ViewNode {

    /// The first focusable node in this subtree.
    var firstFocusable: ViewNode? {
        if attributes.focus != nil {
            return self
        }
        for child in children {
            if let node = child.firstFocusable {
                return node
            }
        }
        return nil
    }
}

// MARK: - FocusState

/// A property wrapper type that can read and write a value that SwiftUI
/// updates as the placement of focus within the scene changes.
@propertyWrapper
public struct FocusState<Value: Hashable>: DynamicProperty {

    // Stored as variables so the wrapper's default initializer applies in
    // memberwise initializers.
    internal var box: StateBox<Value>

    internal var reset: Value

    /// The current state value, taking into account whatever bindings might
    /// be in effect due to the current location of focus.
    public var wrappedValue: Value {
        get { box.value }
        nonmutating set { box.value = newValue }
    }

    /// Creates a focus state that binds to a Boolean.
    public init() where Value == Bool {
        self.box = StateBox(false)
        self.reset = false
    }

    /// Creates a focus state that binds to an optional type.
    public init() where Value: ExpressibleByNilLiteral {
        self.box = StateBox(nil)
        self.reset = nil
    }

    /// A projection of the focus state value that returns a binding.
    public var projectedValue: Binding {
        Binding(box: box, reset: reset)
    }

    /// A property wrapper type that can read and write a value that indicates
    /// the current focus location.
    @propertyWrapper
    public struct Binding {

        internal let box: StateBox<Value>

        internal let reset: Value

        public var wrappedValue: Value {
            get { box.value }
            nonmutating set { box.value = newValue }
        }

        public var projectedValue: Binding {
            self
        }
    }
}



extension FocusState: DynamicPropertyInstaller {

    func install(in node: ViewNode, label: String) {
        box.install(in: node, label: label)
    }
}

internal struct _FocusedModifier: ViewModifier, PrimitiveViewModifier {

    let binding: FocusBinding

    func resolve(content: any View, in context: ResolveContext) -> Resolution {
        var attributes = NodeAttributes()
        attributes.focusBinding = binding
        return Resolution(children: [ChildView(key: 0, view: content)], attributes: attributes)
    }

    typealias Body = Never
}

extension View {

    /// Modifies this view by binding its focus state to the given Boolean
    /// state value.
    public func focused(_ condition: FocusState<Bool>.Binding) -> some View {
        modifier(_FocusedModifier(binding: FocusBinding(
            isRequested: condition.wrappedValue,
            set: { condition.wrappedValue = $0 }
        )))
    }

    /// Modifies this view by binding its focus state to the given state value.
    public func focused<Value: Hashable>(_ binding: FocusState<Value>.Binding, equals value: Value) -> some View {
        modifier(_FocusedModifier(binding: FocusBinding(
            isRequested: binding.wrappedValue == value,
            set: { isFocused in
                if isFocused {
                    binding.wrappedValue = value
                } else if binding.wrappedValue == value {
                    binding.wrappedValue = binding.reset
                }
            }
        )))
    }
}

// MARK: - Submit

/// An action run when the user submits a value, such as pressing Return in
/// a text field.
internal struct SubmitAction {

    let action: () -> Void
}

private struct SubmitActionKey: EnvironmentKey {
    static var defaultValue: SubmitAction? { nil }
}

extension EnvironmentValues {

    internal var onSubmit: SubmitAction? {
        get { self[SubmitActionKey.self] }
        set { self[SubmitActionKey.self] = newValue }
    }
}

extension View {

    /// Adds an action to perform when the user submits a value to this view.
    public func onSubmit(of triggers: SubmitTriggers = .text, _ action: @escaping () -> Void) -> some View {
        transformEnvironment(\.onSubmit) { existing in
            let previous = existing
            existing = SubmitAction {
                previous?.action()
                action()
            }
        }
    }
}

/// A type that defines various triggers that result in the firing of a
/// submission action.
public struct SubmitTriggers: OptionSet, Sendable {

    public let rawValue: Int

    public init(rawValue: Int) {
        self.rawValue = rawValue
    }

    /// Defines triggers originating from text input controls.
    public static let text = SubmitTriggers(rawValue: 1 << 0)

    /// Defines triggers originating from search fields.
    public static let search = SubmitTriggers(rawValue: 1 << 1)
}
