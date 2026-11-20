//
//  ExternalInput.swift
//  Cacao
//
//  Created by Alsey Coleman Miller on 11/19/26.
//

import CacaoRender
import Foundation
#if canImport(CoreGraphics)
import CoreGraphics
#endif

/// Input for content drawn outside Cacao, as an `ExternalSurfaceView`
/// passes it on: what a game, a web view or a video player needs, which is
/// more than a SwiftUI view gets. Locations are in the view's coordinate
/// space, in points.
public enum ExternalInput: Sendable {

    /// A mouse button pressed over the view, dragged (also outside it) and
    /// released.
    case pointer(Phase, button: Button, location: CGPoint)

    /// The pointer moved over the view with no button down, or left it
    /// (`nil`).
    case hover(location: CGPoint?)

    /// A wheel or trackpad scroll over the view. Whole numbers are a
    /// wheel's notches; positive `y` scrolls away from the user.
    case scroll(x: Double, y: Double, location: CGPoint)

    /// A finger on a touch screen, down on the view, moved and lifted.
    case touch(Phase, finger: UInt64, location: CGPoint)

    /// A key pressed or released while the view has focus.
    case key(Key)

    /// Text typed while the view has focus, perhaps through an input
    /// method.
    case text(String)

    /// The view gained or lost keyboard focus.
    case focus(Bool)

    /// The phases of a press or touch.
    public enum Phase: Hashable, Sendable {
        case began
        case moved
        case ended
        case cancelled
    }

    /// The buttons of a mouse.
    public enum Button: Hashable, Sendable {
        case primary
        case secondary
        case middle
    }

    /// A key going down or up.
    public struct Key: Hashable, Sendable {

        /// Whether the key went down, rather than up.
        public var isDown: Bool

        /// Whether the key is repeating as it's held.
        public var isRepeat: Bool

        /// The physical key, whatever the keyboard layout: its usage in the
        /// USB HID keyboard page.
        public var usage: UInt32

        /// What the key means in the keyboard layout: a Unicode scalar for
        /// keys that type a character, and the host's key code otherwise.
        public var keyCode: UInt32

        public var modifiers: EventModifiers

        public init(isDown: Bool, isRepeat: Bool = false, usage: UInt32, keyCode: UInt32, modifiers: EventModifiers = []) {
            self.isDown = isDown
            self.isRepeat = isRepeat
            self.usage = usage
            self.keyCode = keyCode
            self.modifiers = modifiers
        }
    }
}

/// What external content does with input.
internal struct ExternalInputHandler {

    /// Whether typing goes to the content as text, through an input method.
    var acceptsText: Bool

    var handle: @MainActor (ExternalInput) -> Void
}

// MARK: - Graph

extension ViewGraph {

    /// The front-most node at a point, if it shows external content that
    /// takes input.
    private func externalNode(at point: CGPoint) -> ViewNode? {
        guard let node = root.hitTest(point)?.last, node.attributes.externalInput != nil else {
            return nil
        }
        return node
    }

    /// A window location in a node's coordinate space.
    private func local(_ point: CGPoint, in node: ViewNode) -> CGPoint {
        let frame = node.windowFrame
        return CGPoint(x: point.x - frame.minX, y: point.y - frame.minY)
    }

    private func deliver(_ input: ExternalInput, to node: ViewNode) {
        node.attributes.externalInput?.handle(input)
    }

    /// Delivers a mouse button to external content: a press that starts on
    /// it, and that press's drag and release wherever they go. Returns
    /// whether external content took it.
    ///
    /// A press a host made up from a finger (`isFromTouch`) is taken the
    /// same way, so it reaches nothing else, but isn't delivered: the
    /// content gets the finger itself, as a touch.
    @discardableResult
    package func externalPointer(
        _ phase: ExternalInput.Phase,
        button: ExternalInput.Button,
        at point: CGPoint,
        isFromTouch: Bool = false
    ) -> Bool {
        func deliver(_ input: ExternalInput, to node: ViewNode) {
            if !isFromTouch {
                node.attributes.externalInput?.handle(input)
            }
        }
        switch phase {
        case .began:
            guard externalPress == nil, let node = externalNode(at: point) else {
                // A second button, during a press on external content.
                if let press = externalPress, let node = press.node.node, node.isAttached {
                    deliver(.pointer(.began, button: button, location: local(point, in: node)), to: node)
                    return true
                }
                return false
            }
            hideTooltip()
            // Focus follows clicks.
            focus(node)
            let reference = WeakNodeReference()
            reference.node = node
            externalPress = (reference, button)
            deliver(.pointer(.began, button: button, location: local(point, in: node)), to: node)
            return true
        case .moved, .ended, .cancelled:
            guard let press = externalPress else { return false }
            guard let node = press.node.node, node.isAttached else {
                externalPress = nil
                return false
            }
            deliver(.pointer(phase, button: button, location: local(point, in: node)), to: node)
            if phase != .moved, button == press.button {
                externalPress = nil
            }
            return true
        }
    }

    /// Delivers the pointer's movement with no button down to the external
    /// content under it, telling the content it left when it has.
    package func externalHover(at point: CGPoint?) {
        let node = point.flatMap { externalNode(at: $0) }
        if let previous = externalHovered.node, previous !== node {
            if previous.isAttached {
                deliver(.hover(location: nil), to: previous)
            }
            externalHovered.node = nil
        }
        if let node, let point {
            externalHovered.node = node
            deliver(.hover(location: local(point, in: node)), to: node)
        }
    }

    /// Delivers a scroll to external content under the pointer. Returns
    /// whether there was any.
    @discardableResult
    package func externalScroll(x: Double, y: Double, at point: CGPoint) -> Bool {
        guard let node = externalNode(at: point) else { return false }
        deliver(.scroll(x: x, y: y, location: local(point, in: node)), to: node)
        return true
    }

    /// Delivers a finger to external content: one that comes down on it,
    /// until it lifts. Returns whether external content took it.
    @discardableResult
    package func externalTouch(_ phase: ExternalInput.Phase, finger: UInt64, at point: CGPoint) -> Bool {
        if phase == .began {
            guard let node = externalNode(at: point) else { return false }
            let reference = WeakNodeReference()
            reference.node = node
            externalTouches[finger] = reference
            deliver(.touch(.began, finger: finger, location: local(point, in: node)), to: node)
            return true
        }
        guard let reference = externalTouches[finger] else { return false }
        if phase != .moved {
            externalTouches[finger] = nil
        }
        guard let node = reference.node, node.isAttached else { return false }
        deliver(.touch(phase, finger: finger, location: local(point, in: node)), to: node)
        return true
    }

    /// Delivers a key to external content that has focus. Returns whether
    /// it does.
    @discardableResult
    package func externalKey(_ key: ExternalInput.Key) -> Bool {
        guard let node = focusedNode, node.isAttached, node.attributes.externalInput != nil else {
            return false
        }
        deliver(.key(key), to: node)
        return true
    }
}

// MARK: - View

extension ExternalSurfaceView {

    /// Passes input on to what draws the surface: mouse buttons, scrolls
    /// and touches over the view, and keys and text while it has focus,
    /// which a click gives it.
    ///
    /// With a handler, the view takes this input instead of SwiftUI's
    /// gestures, scroll views and key presses around it.
    ///
    /// - Parameter acceptsText: Whether typing arrives as text, through an
    ///   input method, as well as keys.
    public func onInput(acceptsText: Bool = false, _ handler: @escaping @MainActor (ExternalInput) -> Void) -> ExternalSurfaceView {
        var view = self
        view.input = ExternalInputHandler(acceptsText: acceptsText, handle: handler)
        return view
    }
}
