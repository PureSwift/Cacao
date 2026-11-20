//
//  Animation.swift
//  Cacao
//
//  Created by Alsey Coleman Miller on 11/13/26.
//

import CacaoRender
import Foundation
#if canImport(CoreGraphics)
import CoreGraphics
#endif

// MARK: - Animation

/// The way a view changes over time to create a smooth visual transition
/// from one state to another.
public struct Animation: Equatable, Sendable, CustomStringConvertible {

    internal enum Curve: Equatable, Sendable {
        case linear
        case bezier(CGFloat, CGFloat, CGFloat, CGFloat)
        case spring(response: Double, dampingFraction: Double)
    }

    internal var curve: Curve

    /// Seconds, for timing curves; springs settle on their own.
    internal var duration: Double

    internal var delay: Double = 0

    internal var speed: Double = 1

    internal var repeatCount: Int?

    internal var autoreverses = true

    internal init(curve: Curve, duration: Double) {
        self.curve = curve
        self.duration = duration
    }

    public var description: String {
        "Animation(\(curve), duration: \(duration))"
    }

    // MARK: Timing curves

    /// A default animation: a smooth spring.
    public static let `default` = Animation.spring(response: 0.5, dampingFraction: 1)

    public static func linear(duration: Double) -> Animation {
        Animation(curve: .linear, duration: duration)
    }

    public static var linear: Animation { .linear(duration: 0.35) }

    public static func easeIn(duration: Double) -> Animation {
        Animation(curve: .bezier(0.42, 0, 1, 1), duration: duration)
    }

    public static var easeIn: Animation { .easeIn(duration: 0.35) }

    public static func easeOut(duration: Double) -> Animation {
        Animation(curve: .bezier(0, 0, 0.58, 1), duration: duration)
    }

    public static var easeOut: Animation { .easeOut(duration: 0.35) }

    public static func easeInOut(duration: Double) -> Animation {
        Animation(curve: .bezier(0.42, 0, 0.58, 1), duration: duration)
    }

    public static var easeInOut: Animation { .easeInOut(duration: 0.35) }

    /// An animation created from a cubic Bézier timing curve.
    public static func timingCurve(_ c0x: Double, _ c0y: Double, _ c1x: Double, _ c1y: Double, duration: Double = 0.35) -> Animation {
        Animation(curve: .bezier(CGFloat(c0x), CGFloat(c0y), CGFloat(c1x), CGFloat(c1y)), duration: duration)
    }

    // MARK: Springs

    /// A persistent spring animation.
    public static func spring(response: Double = 0.5, dampingFraction: Double = 0.825, blendDuration: Double = 0) -> Animation {
        Animation(curve: .spring(response: max(response, 0.01), dampingFraction: max(dampingFraction, 0)), duration: response)
    }

    /// A spring animation with a duration and bounce.
    public static func spring(duration: Double = 0.5, bounce: Double = 0, blendDuration: Double = 0) -> Animation {
        spring(response: duration, dampingFraction: 1 - min(max(bounce, 0), 1))
    }

    public static var spring: Animation { .spring(response: 0.5, dampingFraction: 0.825) }

    /// A convenience for a spring with damping fraction 0.86.
    public static func interactiveSpring(response: Double = 0.15, dampingFraction: Double = 0.86, blendDuration: Double = 0.25) -> Animation {
        spring(response: response, dampingFraction: dampingFraction)
    }

    public static var interactiveSpring: Animation { .interactiveSpring(response: 0.15) }

    /// A smooth spring animation with no bounce.
    public static var smooth: Animation { .spring(duration: 0.5, bounce: 0) }

    public static func smooth(duration: Double = 0.5, extraBounce: Double = 0) -> Animation {
        .spring(duration: duration, bounce: extraBounce)
    }

    /// A spring animation with a small amount of bounce.
    public static var snappy: Animation { .spring(duration: 0.5, bounce: 0.15) }

    public static func snappy(duration: Double = 0.5, extraBounce: Double = 0) -> Animation {
        .spring(duration: duration, bounce: 0.15 + extraBounce)
    }

    /// A spring animation with a visible bounce.
    public static var bouncy: Animation { .spring(duration: 0.5, bounce: 0.3) }

    public static func bouncy(duration: Double = 0.5, extraBounce: Double = 0) -> Animation {
        .spring(duration: duration, bounce: 0.3 + extraBounce)
    }

    // MARK: Modifiers

    /// Delays the start of the animation by the specified number of seconds.
    public func delay(_ delay: Double) -> Animation {
        var animation = self
        animation.delay += delay
        return animation
    }

    /// Changes the duration of an animation by adjusting its speed.
    public func speed(_ speed: Double) -> Animation {
        var animation = self
        animation.speed *= max(speed, 0.0001)
        return animation
    }

    /// Repeats the animation for a specific number of times.
    public func repeatCount(_ repeatCount: Int, autoreverses: Bool = true) -> Animation {
        var animation = self
        animation.repeatCount = max(repeatCount, 1)
        animation.autoreverses = autoreverses
        return animation
    }

    /// Repeats the animation for the lifespan of the view.
    public func repeatForever(autoreverses: Bool = true) -> Animation {
        var animation = self
        animation.repeatCount = .max
        animation.autoreverses = autoreverses
        return animation
    }

    // MARK: Evaluation

    /// The length of one run of the animation, in seconds of its own time.
    internal var cycleDuration: Double {
        switch curve {
        case .linear, .bezier:
            return duration
        case let .spring(response, damping):
            // The time to settle within a thousandth of the target.
            let omega = 2 * Double.pi / response
            let decay = max(damping, 0.05) * omega
            return min(max(log(1000) / decay, response), 10)
        }
    }

    /// How far the animation is from start (0) to end (1) after `elapsed`
    /// seconds, and whether it has finished. Springs may overshoot.
    internal func progress(at elapsed: Double) -> (value: Double, isFinished: Bool) {
        let time = (elapsed - delay) * speed
        guard time > 0 else { return (0, false) }
        let cycle = cycleDuration
        guard cycle > 0 else { return (1, true) }
        let count = repeatCount ?? 1
        let total = count == .max ? Double.infinity : cycle * Double(count)
        if time >= total {
            // Autoreversing an even number of times ends at the start.
            if count != .max, autoreverses, count % 2 == 0 {
                return (0, true)
            }
            return (1, true)
        }
        let run = Int(time / cycle)
        var local = time - Double(run) * cycle
        if autoreverses, run % 2 == 1, repeatCount != nil {
            local = cycle - local
        }
        return (value(atCycleTime: local), false)
    }

    private func value(atCycleTime time: Double) -> Double {
        switch curve {
        case .linear:
            return min(max(time / duration, 0), 1)
        case let .bezier(x1, y1, x2, y2):
            return Double(Self.bezier(x: CGFloat(min(max(time / duration, 0), 1)), x1, y1, x2, y2))
        case let .spring(response, damping):
            let omega = 2 * Double.pi / response
            if damping >= 1 {
                return 1 - exp(-omega * time) * (1 + omega * time)
            }
            let damped = omega * (1 - damping * damping).squareRoot()
            let envelope = exp(-damping * omega * time)
            return 1 - envelope * (cos(damped * time) + damping * omega / damped * sin(damped * time))
        }
    }

    /// The y of a cubic Bézier timing curve at x, solving for its parameter.
    private static func bezier(x: CGFloat, _ x1: CGFloat, _ y1: CGFloat, _ x2: CGFloat, _ y2: CGFloat) -> CGFloat {
        func sample(_ t: CGFloat, _ a: CGFloat, _ b: CGFloat) -> CGFloat {
            let u = 1 - t
            return 3 * u * u * t * a + 3 * u * t * t * b + t * t * t
        }
        var low: CGFloat = 0
        var high: CGFloat = 1
        var t = x
        for _ in 0..<24 {
            t = (low + high) / 2
            if sample(t, x1, x2) < x { low = t } else { high = t }
        }
        return sample(t, y1, y2)
    }
}

// MARK: - Transaction

/// The context of the current state-processing update.
public struct Transaction: Sendable {

    /// The animation, if any, associated with the current state change.
    public var animation: Animation?

    /// A Boolean value that indicates whether views should disable animations.
    public var disablesAnimations = false

    /// Creates a transaction.
    public init() { }

    /// Creates a transaction and assigns its animation property.
    public init(animation: Animation?) {
        self.animation = animation
    }

    /// The transaction state changes are made in, set by `withAnimation`.
    nonisolated(unsafe) internal static var current: Transaction?
}

/// Returns the result of recomputing the view's body with the provided
/// animation.
@MainActor
@discardableResult
public func withAnimation<Result>(_ animation: Animation? = .default, _ body: () throws -> Result) rethrows -> Result {
    try withTransaction(Transaction(animation: animation), body)
}

/// Executes a closure with the specified transaction and returns the result.
@MainActor
@discardableResult
public func withTransaction<Result>(_ transaction: Transaction, _ body: () throws -> Result) rethrows -> Result {
    let previous = Transaction.current
    Transaction.current = transaction
    defer { Transaction.current = previous }
    return try body()
}

extension Binding {

    /// Specifies an animation to perform when the binding value changes.
    public func animation(_ animation: Animation? = .default) -> Binding<Value> {
        transaction(Transaction(animation: animation))
    }

    /// Specifies a transaction for the binding.
    public func transaction(_ transaction: Transaction) -> Binding<Value> {
        let get = getValue
        let set = setValue
        return Binding(get: get, set: { value in
            let previous = Transaction.current
            Transaction.current = transaction
            defer { Transaction.current = previous }
            set(value)
        })
    }
}

// MARK: - Modifiers

/// Animates changes in its subtree with an animation when a value changes.
internal struct _AnimationModifier<Value: Equatable>: ViewModifier, PrimitiveViewModifier {

    let animation: Animation?

    let value: Value

    func resolve(content: any View, in context: ResolveContext) -> Resolution {
        let node = context.node
        var resolution = Resolution(children: [ChildView(key: 0, view: content)])
        if let last = node.dynamicStorage["animationValue"] as? ValueBox<Value> {
            if last.value != value {
                last.value = value
                resolution.transaction = { $0.animation = animation }
            }
        } else {
            node.dynamicStorage["animationValue"] = ValueBox(value)
        }
        return resolution
    }

    typealias Body = Never
}

/// Transforms the transaction of changes in its subtree.
internal struct _TransactionModifier: ViewModifier, PrimitiveViewModifier {

    let transform: (inout Transaction) -> Void

    func resolve(content: any View, in context: ResolveContext) -> Resolution {
        var resolution = Resolution(children: [ChildView(key: 0, view: content)])
        resolution.transaction = transform
        return resolution
    }

    typealias Body = Never
}

extension View {

    /// Applies the given animation to this view when the specified value changes.
    public func animation<V: Equatable>(_ animation: Animation?, value: V) -> some View {
        modifier(_AnimationModifier(animation: animation, value: value))
    }

    /// Applies the given animation to all animatable values within this view.
    @available(*, deprecated, message: "Use animation(_:value:) instead.")
    public func animation(_ animation: Animation?) -> some View {
        transaction { $0.animation = animation }
    }

    /// Applies the given transaction mutation function to all animations
    /// used within the view.
    public func transaction(_ transform: @escaping (inout Transaction) -> Void) -> some View {
        modifier(_TransactionModifier(transform: transform))
    }
}

extension Transaction {

    /// Adds an animation where the change has none and doesn't disable
    /// them, as for navigation and presentations, which animate by default.
    mutating func animateByDefault(_ animation: Animation = .smooth(duration: 0.3)) {
        if self.animation == nil, !disablesAnimations {
            self.animation = animation
        }
    }
}
