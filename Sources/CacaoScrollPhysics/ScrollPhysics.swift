//
//  ScrollPhysics.swift
//  CacaoScrollPhysics
//
//  Created by Alsey Coleman Miller on 11/13/26.
//
//  Ported from Perry's PerryScrollPhysics: scrolling as UIScrollView does
//  it. A drag's velocity from its last moments, coasting after it ends,
//  slowing by the deceleration rate each millisecond, a rubber band past the
//  content's edges, and a spring back to them.
//

#if canImport(Glibc)
import Glibc
#elseif canImport(Musl)
import Musl
#elseif canImport(Darwin)
import Darwin
#endif

/// Constants of scrolling.
public enum ScrollPhysics {

    /// The distance a finger moves before a touch becomes a pan, in points.
    public static let panThreshold = 10.0

    /// UIScrollView's normal deceleration rate: the velocity kept each millisecond.
    public static let normalDecelerationRate = 0.998

    /// UIScrollView's fast deceleration rate.
    public static let fastDecelerationRate = 0.99
}

/// Recent positions of a drag, for its velocity when it ends.
public struct VelocityTracker: Sendable {

    /// How far back positions count, in seconds.
    public static let window = 0.1

    private var samples: [(x: Double, y: Double, time: Double)] = []

    public init() { }

    /// Starts over from a drag's first position.
    public mutating func reset(x: Double, y: Double, time: Double) {
        samples = [(x, y, time)]
    }

    /// Adds a position at a time, in seconds.
    public mutating func add(x: Double, y: Double, time: Double) {
        samples.append((x, y, time))
        samples.removeAll { time - $0.time > Self.window }
    }

    /// Points per second along each axis, over the recent positions.
    public var velocity: (x: Double, y: Double) {
        guard let first = samples.first, let last = samples.last, last.time > first.time else {
            return (0, 0)
        }
        let time = last.time - first.time
        return ((last.x - first.x) / time, (last.y - first.y) / time)
    }
}

/// Coasting after a flick: the distance to move each step, slowing until
/// the speed falls below `stopSpeed`.
public struct Deceleration: Sendable {

    /// Below this speed, in points a second, coasting stops.
    public static let stopSpeed = 10.0

    /// Flicks slower than this don't coast.
    public static let startSpeed = 50.0

    public private(set) var velocity: (x: Double, y: Double)

    public let rate: Double

    private var time: Double

    /// Coasting from `velocity` (points a second) at `time`, or `nil` when
    /// the flick is too slow to coast.
    public init?(velocity: (x: Double, y: Double), rate: Double = ScrollPhysics.normalDecelerationRate, time: Double) {
        guard (velocity.x * velocity.x + velocity.y * velocity.y).squareRoot() > Self.startSpeed else {
            return nil
        }
        self.velocity = velocity
        self.rate = rate
        self.time = time
    }

    /// Whether coasting has slowed to a stop.
    public var isFinished: Bool {
        (velocity.x * velocity.x + velocity.y * velocity.y).squareRoot() < Self.stopSpeed
    }

    /// The distance to move since the last step, at `now`, at the speed
    /// coasting had; then the speed slows for the time that passed.
    public mutating func step(at now: Double) -> (x: Double, y: Double) {
        let elapsed = now - time
        guard elapsed > 0 else { return (0, 0) }
        let distance = (velocity.x * elapsed, velocity.y * elapsed)
        let kept = pow(rate, elapsed * 1000)
        velocity = (velocity.x * kept, velocity.y * kept)
        time = now
        return distance
    }

    /// Coasting from `velocity` (points a second, along one axis) in one go:
    /// the distance covered and the seconds it takes, or `nil` when the
    /// flick is too slow to coast.
    public static func glide(velocity: Double, rate: Double = ScrollPhysics.normalDecelerationRate) -> (distance: Double, duration: Double)? {
        let speed = abs(velocity)
        guard speed > startSpeed, rate > 0, rate < 1 else { return nil }
        let perSecond = -1000 * log(rate)
        let duration = log(speed / stopSpeed) / perSecond
        let distance = speed * (1 - exp(-perSecond * duration)) / perSecond
        return (velocity < 0 ? -distance : distance, duration)
    }
}

/// Where content dragged past its edge shows: the overshoot shrinks the
/// further it goes, never reaching `dimension` (the view's length). Within
/// `low` to `high`, `offset` itself.
public func rubberBand(_ offset: Double, low: Double, high: Double, dimension: Double) -> Double {
    guard dimension > 0 else { return min(max(offset, low), high) }
    func stretch(_ overshoot: Double) -> Double {
        (1 - 1 / (overshoot * 0.55 / dimension + 1)) * dimension
    }
    if offset < low { return low - stretch(low - offset) }
    if offset > high { return high + stretch(offset - high) }
    return offset
}

/// Content let go past its edge, going back to `target` on a critically
/// damped spring, settling in about a third of a second.
public struct SpringBack: Sendable {

    /// The spring's angular frequency, per second.
    public static let stiffness = 15.0

    /// A spring animation's response (its period, in seconds) for the same
    /// spring, critically damped.
    public static var response: Double { 2 * Double.pi / stiffness }

    let start: Double

    let target: Double

    let time: Double

    public private(set) var isFinished = false

    public init(from start: Double, to target: Double, time: Double) {
        self.start = start
        self.target = target
        self.time = time
        self.isFinished = abs(start - target) < 0.5
    }

    /// The position at `now`; finished once within half a point.
    public mutating func step(at now: Double) -> Double {
        let t = max(0, now - time)
        let x0 = start - target
        let x = x0 * (1 + Self.stiffness * t) * exp(-Self.stiffness * t)
        if abs(x) < 0.5 {
            isFinished = true
            return target
        }
        return target + x
    }
}

/// An eased move to a target, for discrete scroll steps like mouse wheel
/// notches, so a notch glides instead of jumping.
public struct EasedScroll: Sendable {

    /// How long a move takes, in seconds.
    public static let duration = 0.12

    public let from: Double

    public private(set) var to: Double

    private var startTime: Double

    public init(from: Double, to: Double, time: Double) {
        self.from = from
        self.to = to
        self.startTime = time
    }

    /// The position at `now`, easing out of the move.
    public func position(at now: Double) -> Double {
        let t = min(max((now - startTime) / Self.duration, 0), 1)
        let eased = 1 - pow(1 - t, 3)
        return from + (to - from) * eased
    }

    public func isFinished(at now: Double) -> Bool {
        now - startTime >= Self.duration
    }
}
