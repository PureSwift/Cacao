//
//  WindowDrag.swift
//  Cacao
//
//  Created by Alsey Coleman Miller on 11/24/26.
//

import Foundation
#if canImport(CoreGraphics)
import CoreGraphics
#endif

/// A gesture that moves the window when its view is dragged, as a title
/// bar does: for windows that draw their own.
///
/// The system moves the window, so the gesture has no value and its
/// modifiers aren't called. Controls inside the view still take their
/// presses; only presses that land on nothing else move the window.
///
/// ```swift
/// MyTitleBar()
///     .gesture(WindowDragGesture())
/// ```
public struct WindowDragGesture: Gesture, PrimitiveGesture {

    public init() { }

    public typealias Value = Void

    public typealias Body = Never

    func makeRecognizer(in context: GestureContext) -> AnyGestureRecognizer {
        // Where the system moves windows, it takes the press before views
        // see it; elsewhere a press here is no gesture.
        _WindowDragRecognizer()
    }
}

/// Never recognizes anything: the system moves the window instead.
private final class _WindowDragRecognizer: GestureRecognizer<Void> {

    override func handle(_ event: GestureEvent) {
        state = .failed
    }
}

extension ViewGraph {

    /// Whether a press at `point` moves the window: it lands in a view with
    /// a `WindowDragGesture` and on nothing inside it that takes presses,
    /// like a button, a text field or another gesture.
    package func movesWindow(at point: CGPoint) -> Bool {
        guard let path = root.hitTest(point),
              let area = path.lastIndex(where: \.attributes.isWindowDragArea) else {
            return false
        }
        return !path[(area + 1)...].contains(where: \.takesPresses)
    }
}

extension ViewNode {

    /// Whether the node does something with a press, so a press on it
    /// doesn't move the window.
    fileprivate var takesPresses: Bool {
        let attributes = self.attributes
        return attributes.tap != nil
            || attributes.disabledTap != nil
            || attributes.drag != nil
            || attributes.focus != nil
            || attributes.externalInput != nil
            || !attributes.gestures.isEmpty
    }
}
