//
//  GestureRecognizers.swift
//  Cacao
//
//  Created by Alsey Coleman Miller on 11/13/26.
//

import CacaoRender
import Foundation
#if canImport(CoreGraphics)
import CoreGraphics
#endif

// MARK: - Events

/// An input event delivered to the gestures of one interaction.
internal struct GestureEvent {

    enum Kind: Equatable {
        case began
        case moved
        case ended
        case cancelled
        /// Time passed, for gestures that wait.
        case tick
        /// A pinch, by its total scale since it began.
        case magnify(Double)
        case magnifyEnded
        /// A two-finger rotation, by its total angle in radians.
        case rotate(Double)
        case rotateEnded
    }

    var kind: Kind

    /// The pointer's location in the window.
    var location: CGPoint

    var time: Double
}

internal enum RecognizerState {
    /// Not recognized yet, and may still be.
    case possible
    /// Recognized, and still changing.
    case active
    /// Recognized and over.
    case ended
    /// Not recognized, or cancelled.
    case failed

    var isFinished: Bool {
        self == .ended || self == .failed
    }
}

// MARK: - Recognizers

/// Recognizes one gesture during one interaction.
///
/// A recognizer updates its state from events, and queues the callbacks of
/// its gesture's modifiers as actions. The arbiter runs a recognizer's
/// actions only while no gesture with precedence over it could still be
/// recognized, so a gesture waiting on another one reports nothing.
@MainActor
internal class AnyGestureRecognizer {

    var state = RecognizerState.possible

    /// Whether the value changed with the last event.
    var didChange = false

    /// Callbacks waiting to be delivered.
    var actions: [@MainActor () -> Void] = []

    /// Called once when the interaction is over for the recognizer, however
    /// it ended, after its actions.
    var onFinish: (@MainActor () -> Void)?

    private(set) var didFinish = false

    final func receive(_ event: GestureEvent) {
        didChange = false
        guard !state.isFinished else { return }
        handle(event)
    }

    func handle(_ event: GestureEvent) { }

    /// Stops recognizing, as when another gesture is recognized.
    func cancel() {
        if !state.isFinished {
            state = .failed
        }
    }

    final func finish() {
        guard !didFinish else { return }
        didFinish = true
        finishChildren()
        onFinish?()
    }

    func finishChildren() { }

    /// Whether the recognizer needs time to pass, like a long press.
    var needsTicks: Bool { false }

    /// Whether the recognizer is waiting for another press, like a double tap.
    var waitsForMorePresses: Bool { false }

    func takeActions() -> [@MainActor () -> Void] {
        defer { actions.removeAll() }
        return actions
    }
}

/// A recognizer of a gesture with values.
@MainActor
internal class GestureRecognizer<Value>: AnyGestureRecognizer {

    /// The latest value.
    var value: Value?
}

private func distance(_ a: CGPoint, _ b: CGPoint) -> CGFloat {
    let dx = a.x - b.x, dy = a.y - b.y
    return (dx * dx + dy * dy).squareRoot()
}

/// How far a press may move and still be a tap.
private let tapTolerance: CGFloat = 10

/// How long after a tap another may start, to count together.
private let multiTapInterval = 0.35

internal final class TapRecognizer<Value>: GestureRecognizer<Value> {

    let count: Int

    let make: (CGPoint) -> Value

    private var taps = 0

    private var pressLocation: CGPoint?

    private var firstLocation = CGPoint(x: 0, y: 0)

    private var lastRelease = 0.0

    init(count: Int, make: @escaping (CGPoint) -> Value) {
        self.count = max(count, 1)
        self.make = make
    }

    override func handle(_ event: GestureEvent) {
        switch event.kind {
        case .began:
            if taps > 0 {
                guard event.time - lastRelease <= multiTapInterval,
                      distance(event.location, firstLocation) <= tapTolerance * 2 else {
                    state = .failed
                    return
                }
            } else {
                firstLocation = event.location
            }
            pressLocation = event.location
        case .moved:
            if let press = pressLocation, distance(event.location, press) > tapTolerance {
                state = .failed
            }
        case .ended:
            guard pressLocation != nil else { return }
            pressLocation = nil
            taps += 1
            lastRelease = event.time
            if taps >= count {
                value = make(event.location)
                state = .ended
                didChange = true
            }
        case .cancelled:
            state = .failed
        case .tick:
            if taps > 0, pressLocation == nil, event.time - lastRelease > multiTapInterval {
                state = .failed
            }
        default:
            break
        }
    }

    override var needsTicks: Bool {
        state == .possible && taps > 0
    }

    override var waitsForMorePresses: Bool {
        state == .possible && taps > 0 && pressLocation == nil
    }
}

internal final class LongPressRecognizer: GestureRecognizer<Bool> {

    let minimumDuration: Double

    let maximumDistance: CGFloat

    private var start: (time: Double, location: CGPoint)?

    init(minimumDuration: Double, maximumDistance: CGFloat) {
        self.minimumDuration = minimumDuration
        self.maximumDistance = maximumDistance
    }

    override func handle(_ event: GestureEvent) {
        switch event.kind {
        case .began:
            start = (event.time, event.location)
            value = true
            didChange = true
            checkDuration(at: event.time)
        case .moved:
            if let start, distance(event.location, start.location) > maximumDistance {
                state = .failed
            }
        case .tick:
            checkDuration(at: event.time)
        case .ended:
            checkDuration(at: event.time)
            if state == .possible {
                state = .failed
            }
        case .cancelled:
            state = .failed
        default:
            break
        }
    }

    private func checkDuration(at time: Double) {
        guard let start, state == .possible, time - start.time >= minimumDuration else { return }
        value = true
        state = .ended
        didChange = true
    }

    override var needsTicks: Bool {
        state == .possible && start != nil
    }
}

internal final class DragRecognizer<Value>: GestureRecognizer<Value> {

    let minimumDistance: CGFloat

    /// The value from the start location, location and velocity.
    let make: (CGPoint, CGPoint, CGSize) -> Value

    private var start: CGPoint?

    private var samples: [(time: Double, location: CGPoint)] = []

    init(minimumDistance: CGFloat, make: @escaping (CGPoint, CGPoint, CGSize) -> Value) {
        self.minimumDistance = minimumDistance
        self.make = make
    }

    override func handle(_ event: GestureEvent) {
        switch event.kind {
        case .began:
            start = event.location
            samples = [(event.time, event.location)]
            if minimumDistance <= 0 {
                state = .active
                update(event.location)
            }
        case .moved:
            guard let start else { return }
            record(event)
            if state == .possible, distance(event.location, start) >= minimumDistance {
                state = .active
            }
            if state == .active {
                update(event.location)
            }
        case .ended:
            guard state == .active else {
                state = .failed
                return
            }
            record(event)
            update(event.location)
            state = .ended
        case .cancelled:
            state = .failed
        default:
            break
        }
    }

    private func record(_ event: GestureEvent) {
        samples.append((event.time, event.location))
        // Velocity over the last tenth of a second.
        let latest = event.time
        samples.removeAll { latest - $0.time > 0.1 && $0.time != latest }
    }

    private var velocity: CGSize {
        guard let first = samples.first, let last = samples.last, last.time - first.time > 0.001 else {
            return .zero
        }
        let dt = CGFloat(last.time - first.time)
        return CGSize(width: (last.location.x - first.location.x) / dt, height: (last.location.y - first.location.y) / dt)
    }

    private func update(_ location: CGPoint) {
        guard let start else { return }
        value = make(start, location, velocity)
        didChange = true
    }
}

/// Recognizes a pinch or a rotation.
internal final class TwoFingerRecognizer<Value>: GestureRecognizer<Value> {

    enum Kind {
        case magnify
        case rotate
    }

    let kind: Kind

    let threshold: Double

    /// The value from the amount, its velocity and the start location.
    let make: (Double, Double, CGPoint) -> Value

    private var start: CGPoint?

    private var last: (time: Double, amount: Double)?

    private var velocity = 0.0

    init(kind: Kind, threshold: Double, make: @escaping (Double, Double, CGPoint) -> Value) {
        self.kind = kind
        self.threshold = threshold
        self.make = make
    }

    override func handle(_ event: GestureEvent) {
        let amount: Double
        switch (kind, event.kind) {
        case let (.magnify, .magnify(scale)):
            amount = scale
        case let (.rotate, .rotate(angle)):
            amount = angle
        case (.magnify, .magnifyEnded), (.rotate, .rotateEnded):
            state = state == .active ? .ended : .failed
            if state == .ended {
                didChange = true
            }
            return
        case (_, .cancelled):
            state = .failed
            return
        default:
            return
        }
        let start = self.start ?? event.location
        self.start = start
        if let last, event.time > last.time {
            velocity = (amount - last.amount) / (event.time - last.time)
        }
        last = (event.time, amount)
        let identity = kind == .magnify ? 1.0 : 0.0
        if state == .possible, abs(amount - identity) >= threshold {
            state = .active
        }
        if state == .active {
            value = make(amount, velocity, start)
            didChange = true
        }
    }
}

// MARK: - Composing recognizers

/// Wraps another recognizer, mapping its value and queueing callbacks.
internal final class CallbackRecognizer<Input, Output>: GestureRecognizer<Output> {

    let content: GestureRecognizer<Input>

    let transform: (Input) -> Output

    let handler: (CallbackRecognizer<Input, Output>, GestureRecognizer<Input>) -> Void

    /// The last value reported to an `onChanged` action.
    var lastReported: Any?

    /// Whether `onLongPressGesture` reported a press.
    var isPressing = false

    init(
        content: GestureRecognizer<Input>,
        transform: @escaping (Input) -> Output,
        handler: @escaping (CallbackRecognizer<Input, Output>, GestureRecognizer<Input>) -> Void
    ) {
        self.content = content
        self.transform = transform
        self.handler = handler
    }

    override func handle(_ event: GestureEvent) {
        content.receive(event)
        state = content.state
        didChange = content.didChange
        if let value = content.value {
            self.value = transform(value)
        }
        actions += content.takeActions()
        handler(self, content)
    }

    override func cancel() {
        content.cancel()
        super.cancel()
    }

    override func finishChildren() {
        content.finish()
    }

    override var needsTicks: Bool { content.needsTicks }

    override var waitsForMorePresses: Bool { content.waitsForMorePresses }
}

extension CallbackRecognizer where Input == Output {

    convenience init(
        content: GestureRecognizer<Input>,
        handler: @escaping (CallbackRecognizer<Input, Output>, GestureRecognizer<Input>) -> Void
    ) {
        self.init(content: content, transform: { $0 }, handler: handler)
    }
}

internal final class SimultaneousRecognizer<First, Second, Value>: GestureRecognizer<Value> {

    let first: GestureRecognizer<First>

    let second: GestureRecognizer<Second>

    let make: (First?, Second?) -> Value

    init(first: GestureRecognizer<First>, second: GestureRecognizer<Second>, make: @escaping (First?, Second?) -> Value) {
        self.first = first
        self.second = second
        self.make = make
    }

    override func handle(_ event: GestureEvent) {
        first.receive(event)
        second.receive(event)
        actions += first.takeActions() + second.takeActions()
        if first.state == .active || second.state == .active {
            state = .active
        } else if first.state.isFinished, second.state.isFinished {
            state = first.state == .ended || second.state == .ended ? .ended : .failed
        }
        if first.didChange || second.didChange {
            value = make(
                first.state == .failed ? nil : first.value,
                second.state == .failed ? nil : second.value
            )
            didChange = true
        }
    }

    override func cancel() {
        first.cancel()
        second.cancel()
        super.cancel()
    }

    override func finishChildren() {
        first.finish()
        second.finish()
    }

    override var needsTicks: Bool { first.needsTicks || second.needsTicks }

    override var waitsForMorePresses: Bool { first.waitsForMorePresses || second.waitsForMorePresses }
}

internal final class SequenceRecognizer<First, Second, Value>: GestureRecognizer<Value> {

    let first: GestureRecognizer<First>

    let makeSecond: () -> GestureRecognizer<Second>

    let firstValue: (First) -> Value

    let secondValue: (First, Second?) -> Value

    private var second: GestureRecognizer<Second>?

    private var isPressed = false

    private var lastLocation = CGPoint(x: 0, y: 0)

    private var firstEnded = 0.0

    init(
        first: GestureRecognizer<First>,
        makeSecond: @escaping () -> GestureRecognizer<Second>,
        first firstValue: @escaping (First) -> Value,
        second secondValue: @escaping (First, Second?) -> Value
    ) {
        self.first = first
        self.makeSecond = makeSecond
        self.firstValue = firstValue
        self.secondValue = secondValue
    }

    override func handle(_ event: GestureEvent) {
        switch event.kind {
        case .began:
            isPressed = true
            lastLocation = event.location
        case .moved:
            lastLocation = event.location
        case .ended, .cancelled:
            isPressed = false
        default:
            break
        }
        if let second {
            // Waiting too long for the second gesture to start fails both.
            if event.kind == .tick, !isPressed, second.state == .possible, event.time - firstEnded > multiTapInterval {
                state = .failed
                return
            }
            deliver(event, to: second)
            return
        }
        first.receive(event)
        actions += first.takeActions()
        switch first.state {
        case .failed:
            state = .failed
        case .ended:
            guard let firstValue = first.value else {
                state = .failed
                return
            }
            let second = makeSecond()
            self.second = second
            firstEnded = event.time
            state = .active
            value = secondValue(firstValue, nil)
            didChange = true
            // Still pressed: the second gesture starts where the press is.
            if isPressed {
                deliver(GestureEvent(kind: .began, location: lastLocation, time: event.time), to: second)
                didChange = true
            }
        case .possible, .active:
            if first.didChange, let value = first.value {
                self.value = firstValue(value)
                didChange = true
            }
        }
    }

    private func deliver(_ event: GestureEvent, to second: GestureRecognizer<Second>) {
        second.receive(event)
        actions += second.takeActions()
        if second.didChange, let firstValue = first.value {
            value = secondValue(firstValue, second.value)
            didChange = true
        }
        switch second.state {
        case .ended:
            state = .ended
        case .failed:
            state = .failed
        case .possible, .active:
            state = .active
        }
    }

    override func cancel() {
        first.cancel()
        second?.cancel()
        super.cancel()
    }

    override func finishChildren() {
        first.finish()
        second?.finish()
    }

    override var needsTicks: Bool {
        if let second {
            return second.needsTicks || (second.state == .possible && !isPressed)
        }
        return first.needsTicks
    }

    override var waitsForMorePresses: Bool {
        if let second {
            return second.state == .possible && !isPressed || second.waitsForMorePresses
        }
        return first.waitsForMorePresses
    }
}

internal final class ExclusiveRecognizer<First, Second, Value>: GestureRecognizer<Value> {

    let first: GestureRecognizer<First>

    let second: GestureRecognizer<Second>

    let firstValue: (First) -> Value

    let secondValue: (Second) -> Value

    /// The second gesture's callbacks, held until the first fails.
    private var heldActions: [@MainActor () -> Void] = []

    private var usesSecond = false

    init(
        first: GestureRecognizer<First>,
        second: GestureRecognizer<Second>,
        first firstValue: @escaping (First) -> Value,
        second secondValue: @escaping (Second) -> Value
    ) {
        self.first = first
        self.second = second
        self.firstValue = firstValue
        self.secondValue = secondValue
    }

    override func handle(_ event: GestureEvent) {
        first.receive(event)
        second.receive(event)
        if usesSecond {
            actions += second.takeActions()
            mirrorSecond(changed: second.didChange)
            return
        }
        actions += first.takeActions()
        heldActions += second.takeActions()
        switch first.state {
        case .failed:
            usesSecond = true
            actions += heldActions
            heldActions.removeAll()
            mirrorSecond(changed: second.value != nil)
        case .active, .ended:
            second.cancel()
            heldActions.removeAll()
            state = first.state
            if first.didChange, let value = first.value {
                self.value = firstValue(value)
                didChange = true
            }
        case .possible:
            if first.didChange, let value = first.value {
                self.value = firstValue(value)
                didChange = true
            }
        }
    }

    private func mirrorSecond(changed: Bool) {
        state = second.state
        if changed, let value = second.value {
            self.value = secondValue(value)
            didChange = true
        }
    }

    override func cancel() {
        first.cancel()
        second.cancel()
        super.cancel()
    }

    override func finishChildren() {
        first.finish()
        second.finish()
    }

    override var needsTicks: Bool { first.needsTicks || second.needsTicks }

    override var waitsForMorePresses: Bool { first.waitsForMorePresses || second.waitsForMorePresses }
}

// MARK: - Controls

/// A control's tap, with its pressed highlight, as a recognizer.
internal final class ControlTapRecognizer: GestureRecognizer<Void> {

    let handler: TapHandler

    /// Whether a point is on the control.
    let contains: (CGPoint) -> Bool

    /// Whether moving away gives way to other gestures, like a drag around
    /// the control.
    var yieldsOnMove = false

    private var start = CGPoint(x: 0, y: 0)

    private var isInside = false

    private var isHighlighted = false

    init(handler: TapHandler, contains: @escaping (CGPoint) -> Bool) {
        self.handler = handler
        self.contains = contains
    }

    override func handle(_ event: GestureEvent) {
        switch event.kind {
        case .began:
            start = event.location
            setInside(true)
        case .moved:
            if yieldsOnMove, distance(event.location, start) > tapTolerance {
                state = .failed
                return
            }
            let inside = contains(event.location)
            if inside != isInside {
                setInside(inside)
            }
        case .ended:
            let inside = contains(event.location)
            state = inside ? .ended : .failed
            guard inside else { return }
            didChange = true
            let action = handler.action
            actions.append { [unowned self] in
                unhighlight()
                action()
            }
        case .cancelled:
            state = .failed
        default:
            break
        }
    }

    private func setInside(_ inside: Bool) {
        isInside = inside
        guard let pressChanged = handler.onPressChanged else { return }
        actions.append { [unowned self] in
            isHighlighted = inside
            pressChanged(inside)
        }
    }

    private func unhighlight() {
        guard isHighlighted else { return }
        isHighlighted = false
        handler.onPressChanged?(false)
    }

    override func finishChildren() {
        unhighlight()
    }
}

/// A control's drag, like a slider's, as a recognizer.
internal final class ControlDragRecognizer: GestureRecognizer<Void> {

    let handler: DragHandler

    /// The control's frame in the window.
    let frame: CGRect

    private var start = CGPoint(x: 0, y: 0)

    private var didReport = false

    private var didEnd = false

    init(handler: DragHandler, frame: CGRect) {
        self.handler = handler
        self.frame = frame
    }

    override func handle(_ event: GestureEvent) {
        let handler = self.handler, frame = self.frame
        switch event.kind {
        case .began:
            start = event.location
            state = .active
            report { [start] in handler.onChanged(start, event.location, frame) }
        case .moved:
            report { [start] in handler.onChanged(start, event.location, frame) }
        case .ended:
            state = .ended
            didEnd = true
            report { [start] in handler.onEnded(start, event.location, frame) }
        case .cancelled:
            state = .failed
        default:
            break
        }
    }

    private func report(_ action: @escaping @MainActor () -> Void) {
        didChange = true
        actions.append { [unowned self] in
            didReport = true
            action()
        }
    }

    override func finishChildren() {
        // A cancelled drag ends where it started.
        if didReport, !didEnd {
            handler.onEnded(start, start, frame)
        }
    }
}
