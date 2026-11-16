//
//  AccessibilityBridge.swift
//  CacaoSDL
//
//  Created by Alsey Coleman Miller on 11/13/26.
//

#if os(macOS)
import AppKit
import Cacao

/// Shows a window's accessibility tree to macOS assistive technologies,
/// like VoiceOver, as accessibility elements of the window's view.
@MainActor
final class AccessibilityBridge {

    /// The view whose accessibility children are the window's elements.
    let view: NSView

    /// Performs an element's action, by name and window frame.
    let perform: @MainActor (String, CGRect) -> Bool

    /// The tree the elements show, to update them only when it changes.
    private(set) var tree: AccessibilityElement?

    private(set) var elements: [Element] = []

    init(view: NSView, perform: @escaping @MainActor (String, CGRect) -> Bool) {
        self.view = view
        self.perform = perform
        view.setAccessibilityElement(false)
        view.setAccessibilityRole(.group)
    }

    /// Shows a new tree, if it changed.
    func update(_ tree: AccessibilityElement) {
        guard tree != self.tree else { return }
        self.tree = tree
        elements = tree.children.map { makeElement($0, parent: view) }
        view.setAccessibilityChildren(elements)
        NSAccessibility.post(element: view, notification: .layoutChanged)
    }

    private func makeElement(_ element: AccessibilityElement, parent: Any) -> Element {
        let node = Element(bridge: self, frame: element.frame, actions: element.actions)
        node.setAccessibilityParent(parent)
        node.setAccessibilityRole(Self.role(element))
        node.setAccessibilityLabel(element.label)
        if element.role == .staticText {
            node.setAccessibilityValue(element.value ?? element.label)
        } else if let value = element.value {
            node.setAccessibilityValue(value)
        }
        if let hint = element.hint {
            node.setAccessibilityHelp(hint)
        }
        node.setAccessibilitySelected(element.traits.contains(.isSelected))
        node.setAccessibilityChildren(element.children.map { makeElement($0, parent: node) })
        return node
    }

    static func role(_ element: AccessibilityElement) -> NSAccessibility.Role {
        if element.traits.contains(.isLink) { return .link }
        switch element.role {
        case .group: return .group
        case .staticText: return .staticText
        case .button: return .button
        case .image: return .image
        case .textField: return .textField
        case .toggle: return .checkBox
        case .slider: return .slider
        }
    }

    /// The screen rectangle of a rectangle in the window's points, from its
    /// top-leading corner.
    func screenFrame(_ frame: CGRect) -> NSRect {
        let bounds = view.bounds
        let local = view.isFlipped ? frame : NSRect(x: frame.minX, y: bounds.height - frame.maxY, width: frame.width, height: frame.height)
        guard let window = view.window else { return local }
        return window.convertToScreen(view.convert(local, to: nil))
    }

    /// A value handed to the main actor from AppKit's callbacks.
    struct Unchecked<Value>: @unchecked Sendable {
        let value: Value
        init(_ value: Value) { self.value = value }
    }

    /// One element of the window.
    final class Element: NSAccessibilityElement {

        weak var bridge: AccessibilityBridge?

        /// The element's frame in the window, which finds it again.
        let windowFrame: CGRect

        let actions: [String]

        init(bridge: AccessibilityBridge, frame: CGRect, actions: [String]) {
            self.bridge = bridge
            self.windowFrame = frame
            self.actions = actions
            super.init()
        }

        // AppKit asks for these on the main thread.

        override func accessibilityFrame() -> NSRect {
            let context = Unchecked((bridge, windowFrame))
            return MainActor.assumeIsolated {
                context.value.0?.screenFrame(context.value.1) ?? .zero
            }
        }

        override func accessibilityPerformPress() -> Bool {
            guard actions.contains("default") else { return false }
            let context = Unchecked((bridge, windowFrame))
            return MainActor.assumeIsolated {
                context.value.0?.perform("default", context.value.1) ?? false
            }
        }
    }
}
#endif
