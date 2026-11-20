//
//  PhaseKeyframes.swift
//  Cacao
//
//  Created by Alsey Coleman Miller on 11/13/26.
//

import CacaoRender
import Foundation
#if canImport(CoreGraphics)
import CoreGraphics
#endif

// MARK: - Placeholder content

/// A placeholder for the content a phase or keyframe animator modifies.
public struct PlaceholderContentView<Value: View>: View {

    internal let content: Value

    public var body: some View {
        content
    }
}

/// Whether two values of any equatable types are equal.
private func isEqual(_ lhs: Any?, _ rhs: any Equatable) -> Bool {
    func open<T: Equatable>(_ rhs: T) -> Bool {
        (lhs as? T) == rhs
    }
    return open(rhs)
}

extension Animation {

    /// About how long the animation takes to look finished, for moving on
    /// to the next phase.
    internal var logicalDuration: Double {
        let cycle: Double
        switch curve {
        case .linear, .bezier: cycle = duration
        case .spring: cycle = duration
        }
        let count = Double(repeatCount == .max ? 1 : (repeatCount ?? 1))
        return delay + cycle * count / max(speed, 0.0001)
    }
}

// MARK: - Phase animator

/// A container that animates its content by automatically cycling through
/// a collection of phases that you provide, each defining a discrete step
/// within an animation.
public struct PhaseAnimator<Phase: Equatable, Content: View>: View, PrimitiveView {

    internal let phases: [Phase]

    /// The trigger, or nil to cycle continuously.
    internal let trigger: (any Equatable)?

    internal let content: (Phase) -> Content

    internal let animation: (Phase) -> Animation?

    /// Cycles through the phases each time the trigger changes, from the
    /// first phase back to it.
    public init(
        _ phases: some Sequence<Phase>,
        trigger: some Equatable,
        @ViewBuilder content: @escaping (Phase) -> Content,
        animation: @escaping (Phase) -> Animation? = { _ in .default }
    ) {
        self.phases = Array(phases)
        self.trigger = trigger
        self.content = content
        self.animation = animation
    }

    /// Cycles through the phases continuously.
    public init(
        _ phases: some Sequence<Phase>,
        @ViewBuilder content: @escaping (Phase) -> Content,
        animation: @escaping (Phase) -> Animation? = { _ in .default }
    ) {
        self.phases = Array(phases)
        self.trigger = nil
        self.content = content
        self.animation = animation
    }

    public typealias Body = Never

    func resolve(in context: ResolveContext) -> Resolution {
        let node = context.node
        let graph = node.graph
        let state = (node.dynamicStorage["phases"] as? PhaseState) ?? PhaseState()
        let isFirst = node.dynamicStorage["phases"] == nil
        node.dynamicStorage["phases"] = state
        guard !phases.isEmpty else {
            return Resolution()
        }
        state.index = min(state.index, phases.count - 1)
        var transaction: ((inout Transaction) -> Void)?
        func advance() {
            state.index = (state.index + 1) % phases.count
            let animation = self.animation(phases[state.index])
            transaction = { $0.animation = animation }
            if trigger == nil || state.index != 0 {
                state.nextTime = graph.time + (animation?.logicalDuration ?? 0)
                graph.scheduleWakeup(node, after: animation?.logicalDuration ?? 0)
            } else {
                // Back at the first phase: the cycle is done.
                state.nextTime = nil
                graph.scheduleWakeup(node, after: nil)
            }
        }
        if let trigger {
            if isFirst {
                state.trigger = trigger
            } else if !isEqual(state.trigger, trigger) {
                state.trigger = trigger
                // A new trigger starts the cycle over, from the first phase.
                state.index = 0
                advance()
            } else if let next = state.nextTime, graph.time + 0.001 >= next {
                advance()
            }
        } else if isFirst {
            // Shows the first phase, then animates from it next frame.
            state.nextTime = graph.time
            graph.scheduleWakeup(node, after: 0)
        } else if let next = state.nextTime, graph.time + 0.001 >= next {
            advance()
        }
        var resolution = Resolution(children: [ChildView(key: 0, view: content(phases[state.index]))])
        resolution.transaction = transaction
        return resolution
    }
}

private final class PhaseState {

    var index = 0

    var trigger: Any?

    /// When to move to the next phase, while cycling.
    var nextTime: Double?
}

extension View {

    /// Cycles through the given phases when the trigger value changes,
    /// updating the view using the modifiers you apply in `content`.
    public func phaseAnimator<Phase: Equatable>(
        _ phases: some Sequence<Phase>,
        trigger: some Equatable,
        @ViewBuilder content: @escaping (PlaceholderContentView<Self>, Phase) -> some View,
        animation: @escaping (Phase) -> Animation? = { _ in .default }
    ) -> some View {
        let placeholder = PlaceholderContentView(content: self)
        return PhaseAnimator(phases, trigger: trigger, content: { content(placeholder, $0) }, animation: animation)
    }

    /// Cycles through the given phases continuously, updating the content
    /// using the view modifiers you apply in `content`.
    public func phaseAnimator<Phase: Equatable>(
        _ phases: some Sequence<Phase>,
        @ViewBuilder content: @escaping (PlaceholderContentView<Self>, Phase) -> some View,
        animation: @escaping (Phase) -> Animation? = { _ in .default }
    ) -> some View {
        let placeholder = PlaceholderContentView(content: self)
        return PhaseAnimator(phases, content: { content(placeholder, $0) }, animation: animation)
    }
}

// MARK: - Curves and springs

/// A function defined by a two-dimensional curve that maps an input
/// progress in the range [0,1] to an output progress.
public struct UnitCurve: Equatable, Sendable {

    internal let animation: Animation

    /// Creates a new curve using bezier control points.
    public static func bezier(startControlPoint: UnitPoint, endControlPoint: UnitPoint) -> UnitCurve {
        UnitCurve(animation: .timingCurve(startControlPoint.x, startControlPoint.y, endControlPoint.x, endControlPoint.y, duration: 1))
    }

    public static let linear = UnitCurve(animation: .linear(duration: 1))

    public static let easeIn = UnitCurve(animation: .easeIn(duration: 1))

    public static let easeOut = UnitCurve(animation: .easeOut(duration: 1))

    public static let easeInOut = UnitCurve(animation: .easeInOut(duration: 1))

    /// The output progress for an input progress.
    public func value(at progress: Double) -> Double {
        guard progress > 0 else { return 0 }
        guard progress < 1 else { return 1 }
        return animation.progress(at: progress).value
    }
}

/// A representation of a spring's motion.
public struct Spring: Equatable, Sendable {

    /// The perceptual duration, which defines the pace of the spring.
    public var duration: TimeInterval

    /// How bouncy the spring is, from 0 (none) to 1.
    public var bounce: Double

    public init(duration: TimeInterval = 0.5, bounce: Double = 0) {
        self.duration = duration
        self.bounce = bounce
    }

    public static let smooth = Spring(duration: 0.5, bounce: 0)

    public static let snappy = Spring(duration: 0.5, bounce: 0.15)

    public static let bouncy = Spring(duration: 0.5, bounce: 0.3)

    internal var animation: Animation {
        .spring(duration: duration, bounce: bounce)
    }
}

// MARK: - Keyframes

/// One step of a keyframe track: how a value moves to the next keyframe.
public struct _KeyframeSegment<Value: Animatable> {

    enum Kind {
        case linear(UnitCurve)
        case spring(Spring)
        case cubic(startVelocity: Value?, endVelocity: Value?)
        case move
    }

    let value: Value

    let duration: TimeInterval

    let kind: Kind
}

/// A type that defines changes to an animatable value along a keyframe track.
public protocol KeyframeTrackContent<Value> {

    associatedtype Value: Animatable

    var _segments: [_KeyframeSegment<Value>] { get }
}

/// A keyframe that uses simple linear interpolation.
public struct LinearKeyframe<Value: Animatable>: KeyframeTrackContent {

    public let _segments: [_KeyframeSegment<Value>]

    public init(_ to: Value, duration: TimeInterval, timingCurve: UnitCurve = .linear) {
        _segments = [_KeyframeSegment(value: to, duration: duration, kind: .linear(timingCurve))]
    }
}

/// A keyframe that uses a spring function to interpolate to the given value.
public struct SpringKeyframe<Value: Animatable>: KeyframeTrackContent {

    public let _segments: [_KeyframeSegment<Value>]

    public init(_ to: Value, duration: TimeInterval? = nil, spring: Spring = Spring(), startVelocity: Value? = nil) {
        _segments = [_KeyframeSegment(value: to, duration: duration ?? spring.duration, kind: .spring(spring))]
    }
}

/// A keyframe that uses a cubic curve to smoothly interpolate between values.
public struct CubicKeyframe<Value: Animatable>: KeyframeTrackContent {

    public let _segments: [_KeyframeSegment<Value>]

    public init(_ to: Value, duration: TimeInterval, startVelocity: Value? = nil, endVelocity: Value? = nil) {
        _segments = [_KeyframeSegment(value: to, duration: duration, kind: .cubic(startVelocity: startVelocity, endVelocity: endVelocity))]
    }
}

/// A keyframe that immediately moves to the given value without interpolating.
public struct MoveKeyframe<Value: Animatable>: KeyframeTrackContent {

    public let _segments: [_KeyframeSegment<Value>]

    public init(_ to: Value) {
        _segments = [_KeyframeSegment(value: to, duration: 0, kind: .move)]
    }
}

/// Keyframes built by a track's builder.
public struct _KeyframeTrackSegments<Value: Animatable>: KeyframeTrackContent {

    public let _segments: [_KeyframeSegment<Value>]
}

/// The builder that creates keyframe track content from the keyframes
/// that you define within a closure.
@resultBuilder
public enum KeyframeTrackContentBuilder<Value: Animatable> {

    public static func buildExpression<K: KeyframeTrackContent>(_ keyframe: K) -> [_KeyframeSegment<Value>] where K.Value == Value {
        keyframe._segments
    }

    public static func buildBlock(_ components: [_KeyframeSegment<Value>]...) -> [_KeyframeSegment<Value>] {
        components.flatMap { $0 }
    }

    public static func buildArray(_ components: [[_KeyframeSegment<Value>]]) -> [_KeyframeSegment<Value>] {
        components.flatMap { $0 }
    }

    public static func buildOptional(_ component: [_KeyframeSegment<Value>]?) -> [_KeyframeSegment<Value>] {
        component ?? []
    }

    public static func buildEither(first component: [_KeyframeSegment<Value>]) -> [_KeyframeSegment<Value>] {
        component
    }

    public static func buildEither(second component: [_KeyframeSegment<Value>]) -> [_KeyframeSegment<Value>] {
        component
    }

    public static func buildFinalResult(_ component: [_KeyframeSegment<Value>]) -> _KeyframeTrackSegments<Value> {
        _KeyframeTrackSegments(_segments: component)
    }
}

/// A track of keyframes for one property of a value.
public struct _KeyframeTrackValues<Root> {

    let duration: TimeInterval

    /// The root with the track's property at a time, starting from a root.
    let apply: (inout Root, TimeInterval) -> Void
}

/// A type that defines a set of keyframe-driven animations.
public protocol Keyframes<Value> {

    associatedtype Value

    var _tracks: [_KeyframeTrackValues<Value>] { get }
}

/// A sequence of keyframes animating a single property of a root type.
public struct KeyframeTrack<Root, Value: Animatable, Content: KeyframeTrackContent>: Keyframes where Content.Value == Value {

    public let _tracks: [_KeyframeTrackValues<Root>]

    /// Creates an instance that animates the property at the key path.
    public init(_ keyPath: WritableKeyPath<Root, Value>, @KeyframeTrackContentBuilder<Value> content: () -> Content) {
        let segments = content()._segments
        _tracks = [_KeyframeTrackValues(
            duration: segments.reduce(0) { $0 + $1.duration },
            apply: { root, time in
                root[keyPath: keyPath] = KeyframeMath.value(from: root[keyPath: keyPath], segments: segments, at: time)
            }
        )]
    }
}

extension KeyframeTrack where Root == Value {

    /// Creates an instance that animates the entire value from the root.
    public init(@KeyframeTrackContentBuilder<Value> content: () -> Content) {
        self.init(\.self, content: content)
    }
}

/// Keyframes built by a keyframes builder.
public struct _KeyframeTracks<Value>: Keyframes {

    public let _tracks: [_KeyframeTrackValues<Value>]
}

/// A builder that combines keyframe content values into a single value.
@resultBuilder
public enum KeyframesBuilder<Value> {

    public static func buildExpression<K: Keyframes>(_ keyframes: K) -> [_KeyframeTrackValues<Value>] where K.Value == Value {
        keyframes._tracks
    }

    public static func buildBlock(_ components: [_KeyframeTrackValues<Value>]...) -> [_KeyframeTrackValues<Value>] {
        components.flatMap { $0 }
    }

    public static func buildArray(_ components: [[_KeyframeTrackValues<Value>]]) -> [_KeyframeTrackValues<Value>] {
        components.flatMap { $0 }
    }

    public static func buildOptional(_ component: [_KeyframeTrackValues<Value>]?) -> [_KeyframeTrackValues<Value>] {
        component ?? []
    }

    public static func buildEither(first component: [_KeyframeTrackValues<Value>]) -> [_KeyframeTrackValues<Value>] {
        component
    }

    public static func buildEither(second component: [_KeyframeTrackValues<Value>]) -> [_KeyframeTrackValues<Value>] {
        component
    }

    public static func buildFinalResult(_ component: [_KeyframeTrackValues<Value>]) -> _KeyframeTracks<Value> {
        _KeyframeTracks(_tracks: component)
    }
}

/// A description of how a value changes over time, modeled using keyframes.
public struct KeyframeTimeline<Value> {

    internal let initialValue: Value

    internal let tracks: [_KeyframeTrackValues<Value>]

    /// Creates a new instance using the initial value and content that you provide.
    public init(initialValue: Value, @KeyframesBuilder<Value> content: () -> some Keyframes<Value>) {
        self.initialValue = initialValue
        self.tracks = content()._tracks
    }

    internal init(initialValue: Value, tracks: [_KeyframeTrackValues<Value>]) {
        self.initialValue = initialValue
        self.tracks = tracks
    }

    /// The duration of the content in seconds.
    public var duration: TimeInterval {
        tracks.map(\.duration).max() ?? 0
    }

    /// Returns the interpolated value at the given time.
    public func value(time: Double) -> Value {
        var value = initialValue
        for track in tracks {
            track.apply(&value, max(0, time))
        }
        return value
    }

    /// Returns the interpolated value at the given progress in the range zero to one.
    public func value(progress: Double) -> Value {
        value(time: progress * duration)
    }
}

/// Interpolation of animatable values along keyframes.
internal enum KeyframeMath {

    static func value<Value: Animatable>(from start: Value, segments: [_KeyframeSegment<Value>], at time: TimeInterval) -> Value {
        var previous = start
        var elapsed: TimeInterval = 0
        for (index, segment) in segments.enumerated() {
            let end = elapsed + segment.duration
            if time < end, segment.duration > 0 {
                let t = (time - elapsed) / segment.duration
                switch segment.kind {
                case .move:
                    return segment.value
                case let .linear(curve):
                    return interpolate(previous, segment.value, curve.value(at: t))
                case let .spring(spring):
                    return interpolate(previous, segment.value, spring.animation.progress(at: time - elapsed).value)
                case let .cubic(startVelocity, endVelocity):
                    let before = index > 0 ? segments[index - 1] : nil
                    let after = index + 1 < segments.count ? segments[index + 1] : nil
                    let beforeValue = index > 1 ? segments[index - 2].value : start
                    let v0 = startVelocity?.animatableData ?? tangent(
                        from: before.map { _ in beforeValue }, through: previous, to: segment.value,
                        durations: (before?.duration ?? 0, segment.duration)
                    )
                    let v1 = endVelocity?.animatableData ?? tangent(
                        from: previous, through: segment.value, to: after?.value,
                        durations: (segment.duration, after?.duration ?? 0)
                    )
                    return hermite(previous, v0, segment.value, v1, t: t, duration: segment.duration)
                }
            }
            previous = segment.value
            elapsed = end
        }
        return previous
    }

    static func interpolate<Value: Animatable>(_ from: Value, _ to: Value, _ amount: Double) -> Value {
        var result = from
        var delta = to.animatableData - from.animatableData
        delta.scale(by: amount)
        result.animatableData = from.animatableData + delta
        return result
    }

    /// The velocity through a keyframe, from its neighbors (Catmull-Rom),
    /// or zero at an end.
    static func tangent<Value: Animatable>(
        from previous: Value?,
        through value: Value,
        to next: Value?,
        durations: (TimeInterval, TimeInterval)
    ) -> Value.AnimatableData {
        guard let previous, let next, durations.0 + durations.1 > 0 else {
            return .zero
        }
        var slope = next.animatableData - previous.animatableData
        slope.scale(by: 1 / (durations.0 + durations.1))
        return slope
    }

    static func hermite<Value: Animatable>(
        _ p0: Value, _ v0: Value.AnimatableData,
        _ p1: Value, _ v1: Value.AnimatableData,
        t: Double, duration: TimeInterval
    ) -> Value {
        let t2 = t * t, t3 = t2 * t
        var a = p0.animatableData
        a.scale(by: 2 * t3 - 3 * t2 + 1)
        var b = v0
        b.scale(by: (t3 - 2 * t2 + t) * duration)
        var c = p1.animatableData
        c.scale(by: -2 * t3 + 3 * t2)
        var d = v1
        d.scale(by: (t3 - t2) * duration)
        var result = p0
        result.animatableData = a + b + c + d
        return result
    }
}

// MARK: - Keyframe animator

/// A container that animates its content with keyframes.
public struct KeyframeAnimator<Value, KeyframePath: Keyframes, Content: View>: View, PrimitiveView where KeyframePath.Value == Value {

    internal let initialValue: Value

    /// The trigger, or nil to repeat (or play once) on appear.
    internal let trigger: (any Equatable)?

    internal let repeating: Bool

    internal let content: (Value) -> Content

    internal let keyframes: (Value) -> KeyframePath

    /// Plays the keyframes each time the trigger changes.
    public init(
        initialValue: Value,
        trigger: some Equatable,
        @ViewBuilder content: @escaping (Value) -> Content,
        @KeyframesBuilder<Value> keyframes: @escaping (Value) -> KeyframePath
    ) {
        self.initialValue = initialValue
        self.trigger = trigger
        self.repeating = false
        self.content = content
        self.keyframes = keyframes
    }

    /// Plays the keyframes when the view appears, repeating them if
    /// `repeating` is true.
    public init(
        initialValue: Value,
        repeating: Bool = true,
        @ViewBuilder content: @escaping (Value) -> Content,
        @KeyframesBuilder<Value> keyframes: @escaping (Value) -> KeyframePath
    ) {
        self.initialValue = initialValue
        self.trigger = nil
        self.repeating = repeating
        self.content = content
        self.keyframes = keyframes
    }

    public typealias Body = Never

    func resolve(in context: ResolveContext) -> Resolution {
        let node = context.node
        let graph = node.graph
        let isFirst = node.dynamicStorage["keyframes"] == nil
        let state = (node.dynamicStorage["keyframes"] as? KeyframeState) ?? KeyframeState()
        node.dynamicStorage["keyframes"] = state
        if let trigger {
            if isFirst {
                state.trigger = trigger
            } else if !isEqual(state.trigger, trigger) {
                state.trigger = trigger
                state.start = graph.time
            }
        } else if isFirst {
            state.start = graph.time
        }
        var value = (state.lastValue as? Value) ?? initialValue
        if let start = state.start {
            let timeline = KeyframeTimeline(initialValue: initialValue, tracks: keyframes(initialValue)._tracks)
            var elapsed = graph.time - start
            let duration = timeline.duration
            if repeating, duration > 0, elapsed >= duration {
                elapsed = elapsed.truncatingRemainder(dividingBy: duration)
            }
            value = timeline.value(time: elapsed)
            if repeating || elapsed < duration {
                // Updates every frame while playing.
                graph.scheduleWakeup(node, after: 0)
            } else {
                state.start = nil
                graph.scheduleWakeup(node, after: nil)
            }
            state.lastValue = value
        }
        return Resolution(children: [ChildView(key: 0, view: content(value))])
    }
}

private final class KeyframeState {

    var trigger: Any?

    /// When the keyframes started playing, while they play.
    var start: Double?

    /// The value last shown, kept when the keyframes end.
    var lastValue: Any?
}

extension View {

    /// Loops the given keyframes continuously, updating the view using the
    /// modifiers you apply in `content`.
    public func keyframeAnimator<Value>(
        initialValue: Value,
        repeating: Bool = true,
        @ViewBuilder content: @escaping (PlaceholderContentView<Self>, Value) -> some View,
        @KeyframesBuilder<Value> keyframes: @escaping (Value) -> some Keyframes<Value>
    ) -> some View {
        let placeholder = PlaceholderContentView(content: self)
        return KeyframeAnimator(initialValue: initialValue, repeating: repeating, content: { content(placeholder, $0) }, keyframes: keyframes)
    }

    /// Plays the given keyframes when the given trigger value changes,
    /// updating the view using the modifiers you apply in `content`.
    public func keyframeAnimator<Value>(
        initialValue: Value,
        trigger: some Equatable,
        @ViewBuilder content: @escaping (PlaceholderContentView<Self>, Value) -> some View,
        @KeyframesBuilder<Value> keyframes: @escaping (Value) -> some Keyframes<Value>
    ) -> some View {
        let placeholder = PlaceholderContentView(content: self)
        return KeyframeAnimator(initialValue: initialValue, trigger: trigger, content: { content(placeholder, $0) }, keyframes: keyframes)
    }
}
