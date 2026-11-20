//
//  ScrollController.swift
//  CacaoSDL
//
//  Created by Alsey Coleman Miller on 11/13/26.
//

import CacaoRender
import Foundation
#if canImport(CoreGraphics)
import CoreGraphics
#endif
import Cacao
import CacaoScrollPhysics

/// Turns wheel and trackpad input into scroll offsets, with physics.
///
/// - Trackpads (precise deltas) move content one to one, past the edges
///   with a rubber band, and spring back when the fingers lift. Where the
///   system doesn't send momentum (Linux), the lift starts a deceleration.
/// - Mouse wheels (whole notches) glide to the next position.
@MainActor
final class ScrollController {

    /// Points per wheel notch.
    static let notch: CGFloat = 40

    /// Points per unit of a precise delta.
    static let preciseScale: CGFloat = 10

    /// Seconds of a gesture's velocity to where it would come to rest.
    static let projection: CGFloat = 0.35

    /// Seconds without precise events before the gesture counts as ended.
    static let gestureEnd = 0.06

    /// Whether to coast after a trackpad gesture ends; macOS sends its own
    /// momentum events.
    #if os(macOS)
    static let synthesizesMomentum = false
    #else
    static let synthesizesMomentum = true
    #endif

    private struct Gesture {
        /// The offset when the gesture began.
        var start: CGPoint
        var raw: CGPoint
        var position: CGPoint
        var tracker = VelocityTracker()
        var lastEvent: Double
        /// Whether a finger on a touch screen is moving the content: the
        /// gesture lasts until the finger lifts, however still it's held.
        var isHeld = false
    }

    private enum Motion {
        case eased(x: EasedScroll, y: EasedScroll)
        case decelerating(Deceleration)
        case springing(x: SpringBack, y: SpringBack)
    }

    private final class Scroller {
        let state: ScrollState
        var gesture: Gesture?
        var motion: Motion?
        init(state: ScrollState) { self.state = state }
    }

    private var scrollers: [ObjectIdentifier: Scroller] = [:]

    private var lastPreciseEvent = -Double.infinity

    /// Whether any scroll view is moving on its own.
    var isAnimating: Bool {
        scrollers.values.contains { $0.motion != nil || $0.gesture != nil }
    }

    /// Handles a wheel event at a point in the window, in points.
    ///
    /// `delta` is SDL's: positive `y` scrolls away from the user.
    func wheel(x: Float, y: Float, at point: CGPoint, graph: ViewGraph, now: Double) {
        let isPrecise = x != x.rounded() || y != y.rounded() || now - lastPreciseEvent < 0.2
        if isPrecise {
            lastPreciseEvent = now
        }
        let scale = isPrecise ? Self.preciseScale : Self.notch
        let delta = CGSize(width: CGFloat(x) * scale, height: CGFloat(-y) * scale)
        guard delta != .zero else { return }
        let state: ScrollState
        if let active = activeScroller(at: point, graph: graph), isPrecise {
            state = active
        } else if let target = graph.scrollState(at: point, delta: delta) {
            state = target
        } else {
            return
        }
        // The user takes over from a programmatic scroll.
        graph.cancelScrollAnimation(of: state)
        let scroller = scrollers[ObjectIdentifier(state)] ?? Scroller(state: state)
        scrollers[ObjectIdentifier(state)] = scroller
        if isPrecise {
            precise(scroller, delta: delta, now: now)
        } else {
            discrete(scroller, delta: delta, now: now)
        }
    }

    /// A finger came down: content coasting or springing back stops where
    /// it is, caught.
    func catchMotion() {
        for (key, scroller) in scrollers where scroller.motion != nil {
            scroller.motion = nil
            if scroller.gesture == nil {
                scrollers[key] = nil
            }
        }
    }

    /// A finger has moved far enough to scroll: the scroll view under it
    /// that can move that way follows it from here on, so the content
    /// doesn't jump by the distance it took to tell a pan from a press.
    /// Returns whether there is such a scroll view.
    @discardableResult
    func beginPan(toward movement: CGSize, at point: CGPoint, graph: ViewGraph, now: Double) -> Bool {
        guard let state = graph.scrollState(at: point, delta: CGSize(width: -movement.width, height: -movement.height)) else {
            return false
        }
        graph.cancelScrollAnimation(of: state)
        let scroller = scrollers[ObjectIdentifier(state)] ?? Scroller(state: state)
        scrollers[ObjectIdentifier(state)] = scroller
        scroller.gesture = nil
        precise(scroller, delta: .zero, now: now)
        scroller.gesture?.isHeld = true
        return true
    }

    /// Moves the scroll view under a finger with it, by how far the finger
    /// moved: content follows the finger one to one, past the edges on a
    /// rubber band. Returns whether a scroll view took the movement.
    @discardableResult
    func pan(by movement: CGSize, at point: CGPoint, graph: ViewGraph, now: Double) -> Bool {
        // Content moves with the finger, so the offset goes the other way.
        let delta = CGSize(width: -movement.width, height: -movement.height)
        let state: ScrollState
        if let held = scrollers.values.first(where: { $0.gesture?.isHeld == true })?.state {
            state = held
        } else if let target = graph.scrollState(at: point, delta: delta) {
            state = target
        } else {
            return false
        }
        graph.cancelScrollAnimation(of: state)
        let scroller = scrollers[ObjectIdentifier(state)] ?? Scroller(state: state)
        scrollers[ObjectIdentifier(state)] = scroller
        precise(scroller, delta: delta, now: now)
        scroller.gesture?.isHeld = true
        return true
    }

    /// Whether to print what scrolling does with input, from the
    /// `CACAO_LOG_INPUT` environment variable.
    static let logsInput = ProcessInfo.processInfo.environment["CACAO_LOG_INPUT"] != nil

    /// The finger lifted: the content coasts on from its speed, or springs
    /// back inside its bounds.
    func endPan(now: Double) {
        if Self.logsInput, !scrollers.values.contains(where: { $0.gesture?.isHeld == true }) {
            print("Cacao: pan ended with no scroll view held")
        }
        for scroller in scrollers.values {
            guard let gesture = scroller.gesture, gesture.isHeld else { continue }
            if Self.logsInput {
                let velocity = gesture.tracker.velocity
                print(String(
                    format: "Cacao: pan ended, velocity %.0f, %.0f pt/s, %.0f ms after the last move, offset %.0f of %.0f",
                    velocity.x, velocity.y, (now - gesture.lastEvent) * 1000,
                    Double(scroller.state.offset.y), Double(scroller.state.maxOffset.y)
                ))
            }
            scroller.gesture = nil
            // A finger held still before it lifts leaves the content where
            // it is.
            endGesture(scroller, gesture: gesture, now: now, coasts: now - gesture.lastEvent <= VelocityTracker.window)
        }
    }

    /// A scroll view already in a trackpad gesture under the point.
    private func activeScroller(at point: CGPoint, graph: ViewGraph) -> ScrollState? {
        scrollers.values.first { $0.gesture != nil }?.state
    }

    private func precise(_ scroller: Scroller, delta: CGSize, now: Double) {
        let state = scroller.state
        var gesture = scroller.gesture ?? Gesture(start: state.offset, raw: state.offset, position: .zero, lastEvent: now)
        if scroller.gesture == nil {
            gesture.tracker.reset(x: 0, y: 0, time: now)
        }
        scroller.motion = nil
        gesture.raw.x += delta.width
        gesture.raw.y += delta.height
        gesture.position.x += delta.width
        gesture.position.y += delta.height
        gesture.tracker.add(x: gesture.position.x, y: gesture.position.y, time: now)
        gesture.lastEvent = now
        // Paging scroll views move at most a page per gesture.
        if let limit = state.gestureLimit {
            gesture.raw.x = min(max(gesture.raw.x, gesture.start.x - limit.width), gesture.start.x + limit.width)
            gesture.raw.y = min(max(gesture.raw.y, gesture.start.y - limit.height), gesture.start.y + limit.height)
        }
        scroller.gesture = gesture
        state.offset = banded(gesture.raw, state: state)
    }

    private func discrete(_ scroller: Scroller, delta: CGSize, now: Double) {
        let state = scroller.state
        var target = state.offset
        if case let .eased(x, y) = scroller.motion {
            target = CGPoint(x: x.to, y: y.to)
        }
        target = state.clamped(CGPoint(x: target.x + delta.width, y: target.y + delta.height))
        // A notch moves snapping scroll views to their next target.
        if let snapped = state.snappedOffset(
            projected: target,
            from: state.offset,
            velocity: CGSize(width: delta.width * 100, height: delta.height * 100)
        ) {
            target = snapped
        }
        scroller.gesture = nil
        scroller.motion = .eased(
            x: EasedScroll(from: state.offset.x, to: target.x, time: now),
            y: EasedScroll(from: state.offset.y, to: target.y, time: now)
        )
    }

    /// The offset shown for a raw offset: within bounds, or past them on a
    /// rubber band.
    private func banded(_ raw: CGPoint, state: ScrollState) -> CGPoint {
        let max = state.maxOffset
        let viewport = state.viewportSize
        return CGPoint(
            x: state.axes.contains(.horizontal) ? rubberBand(raw.x, low: 0, high: max.x, dimension: viewport.width) : 0,
            y: state.axes.contains(.vertical) ? rubberBand(raw.y, low: 0, high: max.y, dimension: viewport.height) : 0
        )
    }

    /// Advances every moving scroll view to `now`.
    func step(now: Double) {
        for (key, scroller) in scrollers {
            let state = scroller.state
            if let gesture = scroller.gesture, !gesture.isHeld, now - gesture.lastEvent > Self.gestureEnd {
                scroller.gesture = nil
                endGesture(scroller, gesture: gesture, now: now)
            }
            switch scroller.motion {
            case let .eased(x, y):
                state.offset = CGPoint(x: x.position(at: now), y: y.position(at: now))
                if x.isFinished(at: now) && y.isFinished(at: now) {
                    scroller.motion = nil
                }
            case var .decelerating(deceleration):
                let distance = deceleration.step(at: now)
                let next = CGPoint(x: state.offset.x + distance.x, y: state.offset.y + distance.y)
                let clamped = state.clamped(next)
                state.offset = clamped
                scroller.motion = deceleration.isFinished || clamped != next ? nil : .decelerating(deceleration)
            case var .springing(x, y):
                state.offset = CGPoint(x: x.step(at: now), y: y.step(at: now))
                scroller.motion = x.isFinished && y.isFinished ? nil : .springing(x: x, y: y)
            case nil:
                break
            }
            if scroller.motion == nil, scroller.gesture == nil {
                scrollers[key] = nil
            }
        }
    }

    /// - Parameter coasts: Whether the content keeps moving from the
    ///   gesture's speed even where the system sends momentum for trackpads:
    ///   it sends none for fingers.
    private func endGesture(_ scroller: Scroller, gesture: Gesture, now: Double, coasts: Bool = false) {
        let state = scroller.state
        let clamped = state.clamped(state.offset)
        // Snapping scroll views settle where their behavior says, from where
        // the gesture would have come to rest.
        let velocity = gesture.tracker.velocity
        let projected = CGPoint(
            x: state.offset.x + CGFloat(velocity.x) * Self.projection,
            y: state.offset.y + CGFloat(velocity.y) * Self.projection
        )
        if let target = state.snappedOffset(
            projected: projected,
            from: gesture.start,
            velocity: CGSize(width: velocity.x, height: velocity.y)
        ), target != state.offset {
            scroller.motion = .springing(
                x: SpringBack(from: state.offset.x, to: target.x, time: now),
                y: SpringBack(from: state.offset.y, to: target.y, time: now)
            )
            return
        }
        if clamped != state.offset {
            scroller.motion = .springing(
                x: SpringBack(from: state.offset.x, to: clamped.x, time: now),
                y: SpringBack(from: state.offset.y, to: clamped.y, time: now)
            )
        } else if Self.synthesizesMomentum || coasts,
                  let deceleration = Deceleration(velocity: gesture.tracker.velocity, time: now) {
            scroller.motion = .decelerating(deceleration)
        }
        if Self.logsInput {
            let what = switch scroller.motion {
            case .decelerating: "coasting"
            case .springing: "springing"
            case .eased: "easing"
            case nil: "stopped"
            }
            print("Cacao: scroll gesture ended: \(what)")
        }
    }
}
