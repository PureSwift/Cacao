//
//  GestureSession.swift
//  Cacao
//
//  Created by Alsey Coleman Miller on 11/13/26.
//

import CacaoRender
import Foundation
#if canImport(CoreGraphics)
import CoreGraphics
#endif

/// The gestures of one interaction, deciding which are recognized.
///
/// Exclusive gestures are ordered by precedence: high priority gestures,
/// outermost first, then the others, innermost first. The first that hasn't
/// failed reports its values; the ones after it wait. When it's recognized,
/// the others are cancelled. Simultaneous gestures always report.
@MainActor
internal final class GestureSession {

    private(set) var exclusive: [AnyGestureRecognizer]

    let simultaneous: [AnyGestureRecognizer]

    private(set) var winner: AnyGestureRecognizer?

    /// Whether a pointer is pressed.
    var isPressed = false

    /// Whether a pinch or a rotation is in progress.
    var isTwoFinger = false

    var lastLocation: CGPoint

    init(exclusive: [AnyGestureRecognizer], simultaneous: [AnyGestureRecognizer], location: CGPoint) {
        self.exclusive = exclusive
        self.simultaneous = simultaneous
        self.lastLocation = location
    }

    private var all: [AnyGestureRecognizer] {
        exclusive + simultaneous
    }

    /// Whether the interaction is over.
    var isFinished: Bool {
        all.allSatisfy(\.didFinish)
    }

    /// Whether a new press continues this interaction, like a double tap's
    /// second tap.
    var acceptsPress: Bool {
        all.contains { !$0.state.isFinished && $0.waitsForMorePresses }
    }

    var needsTicks: Bool {
        all.contains { !$0.state.isFinished && $0.needsTicks }
    }

    func handle(_ event: GestureEvent) {
        lastLocation = event.location
        for recognizer in all where !recognizer.state.isFinished {
            recognizer.receive(event)
        }
        arbitrate()
        // Gestures waiting for the press or pinch that just ended fail,
        // unless they wait for another press.
        if !isPressed, !isTwoFinger {
            for recognizer in all where !recognizer.state.isFinished && !recognizer.waitsForMorePresses {
                recognizer.cancel()
            }
            arbitrate()
        }
    }

    /// Ends the interaction, cancelling what wasn't recognized.
    func cancel() {
        for recognizer in all {
            recognizer.cancel()
            _ = recognizer.takeActions()
            recognizer.finish()
        }
    }

    private func arbitrate() {
        if let winner {
            run(winner)
        } else {
            for recognizer in exclusive {
                if recognizer.state == .failed {
                    _ = recognizer.takeActions()
                    recognizer.finish()
                    continue
                }
                // The front of the line reports; the others wait.
                run(recognizer)
                if recognizer.state == .active || recognizer.state == .ended {
                    winner = recognizer
                    for other in exclusive where other !== recognizer {
                        other.cancel()
                        _ = other.takeActions()
                        other.finish()
                    }
                }
                break
            }
        }
        for recognizer in simultaneous {
            if recognizer.state == .failed {
                _ = recognizer.takeActions()
                recognizer.finish()
            } else {
                run(recognizer)
            }
        }
    }

    private func run(_ recognizer: AnyGestureRecognizer) {
        for action in recognizer.takeActions() {
            action()
        }
        if recognizer.state.isFinished {
            recognizer.finish()
        }
    }
}

// MARK: - Graph

extension ViewGraph {

    /// Delivers a pointer press to the gestures under it.
    package func pointer(_ phase: PointerPhase, at point: CGPoint, time: Double? = nil) {
        let time = time ?? self.time
        switch phase {
        case .began:
            hideTooltip()
            let path = root.hitTest(point) ?? []
            // Focus follows clicks: the innermost focusable view, or none.
            focus(path.last { $0.attributes.focus != nil })
            if let session = gestureSession, session.acceptsPress {
                session.isPressed = true
                deliver(.began, at: point, time: time)
                return
            }
            gestureSession?.cancel()
            gestureSession = makeGestureSession(path: path, location: point)
            gestureSession?.isPressed = true
            deliver(.began, at: point, time: time)
        case .moved:
            deliver(.moved, at: point, time: time)
        case .ended:
            gestureSession?.isPressed = false
            deliver(.ended, at: point, time: time)
        case .cancelled:
            gestureSession?.isPressed = false
            deliver(.cancelled, at: point, time: time)
        }
    }

    /// Delivers a pinch, by its total scale since it began, to the gestures
    /// under the pointer.
    package func magnify(_ phase: PointerPhase, scale: Double, at point: CGPoint, time: Double? = nil) {
        twoFinger(phase, event: .magnify(scale), ended: .magnifyEnded, at: point, time: time)
    }

    /// Delivers a two-finger rotation, by its total angle in radians since it
    /// began, to the gestures under the pointer.
    package func rotate(_ phase: PointerPhase, angle: Double, at point: CGPoint, time: Double? = nil) {
        twoFinger(phase, event: .rotate(angle), ended: .rotateEnded, at: point, time: time)
    }

    private func twoFinger(_ phase: PointerPhase, event: GestureEvent.Kind, ended: GestureEvent.Kind, at point: CGPoint, time: Double?) {
        let time = time ?? self.time
        switch phase {
        case .began:
            if gestureSession == nil || gestureSession?.isPressed == false {
                gestureSession?.cancel()
                gestureSession = makeGestureSession(path: root.hitTest(point) ?? [], location: point)
            }
            gestureSession?.isTwoFinger = true
            deliver(event, at: point, time: time)
        case .moved:
            deliver(event, at: point, time: time)
        case .ended, .cancelled:
            gestureSession?.isTwoFinger = false
            deliver(ended, at: point, time: time)
        }
    }

    private func deliver(_ kind: GestureEvent.Kind, at point: CGPoint, time: Double) {
        guard let session = gestureSession else { return }
        session.handle(GestureEvent(kind: kind, location: point, time: time))
        if session.isFinished, gestureSession === session {
            gestureSession = nil
        }
    }

    /// Lets gestures that wait on time, like long presses, see it pass.
    func tickGestures() {
        guard let session = gestureSession, session.needsTicks else { return }
        deliver(.tick, at: session.lastLocation, time: time)
    }

    /// Whether a gesture waits on time to pass.
    var gesturesNeedTicks: Bool {
        gestureSession?.needsTicks ?? false
    }

    /// The gestures of the views at a hit-test path, in precedence order.
    private func makeGestureSession(path: [ViewNode], location: CGPoint) -> GestureSession? {
        // Named coordinate spaces around the views.
        var namedSpaces: [AnyHashable: CGPoint] = [:]
        // The innermost control tap or drag handles a press, as one gesture.
        let controlIndex = path.lastIndex { $0.attributes.drag != nil || $0.attributes.tap != nil }
        var high: [AnyGestureRecognizer] = []
        var normal: [AnyGestureRecognizer] = []
        var simultaneous: [AnyGestureRecognizer] = []
        var controlTap: ControlTapRecognizer?
        for (index, node) in path.enumerated() {
            if let name = node.attributes.coordinateSpaceName {
                namedSpaces[name] = node.windowFrame.origin
            }
            if index == controlIndex {
                if let drag = node.attributes.drag {
                    normal.append(ControlDragRecognizer(handler: drag, frame: node.windowFrame))
                } else if let tap = node.attributes.tap {
                    let recognizer = ControlTapRecognizer(handler: tap) { [weak self, weak node] point in
                        guard let self, let node, node.isAttached else { return false }
                        return self.root.hitTest(point)?.contains { $0 === node } ?? false
                    }
                    controlTap = recognizer
                    normal.append(recognizer)
                }
            }
            var blocksSubviews = false
            for attachment in node.attributes.gestures {
                if attachment.mask.contains(.gesture) {
                    let context = GestureContext(frame: node.windowFrame, namedSpaces: namedSpaces)
                    let recognizer = attachment.make(context)
                    switch attachment.priority {
                    case .high: high.append(recognizer)
                    case .normal: normal.append(recognizer)
                    case .simultaneous: simultaneous.append(recognizer)
                    }
                }
                if !attachment.mask.contains(.subviews) {
                    blocksSubviews = true
                }
            }
            if blocksSubviews {
                break
            }
        }
        let exclusive = high + normal.reversed()
        guard !exclusive.isEmpty || !simultaneous.isEmpty else { return nil }
        controlTap?.yieldsOnMove = exclusive.count > 1
        return GestureSession(exclusive: exclusive, simultaneous: simultaneous, location: location)
    }
}
