//
//  CMTime.swift
//  CoreMedia
//
//  Created by Alsey Coleman Miller on 11/23/26.
//

// On Linux, `import CoreMedia` resolves to this module, so sources written
// against Apple's compile unchanged: its times are PureSwift/Media's. This
// target exists only on Linux; see the manifest. MediaCore comes with it, as
// sources that name a `CMTime` in their own declarations need its type.

@_exported import MediaCore

/// A time as a whole number of units of `1 / timescale` seconds.
public typealias CMTime = MediaTime

/// A span of time: a start and a duration.
public typealias CMTimeRange = MediaTimeRange

public typealias CMTimeValue = Int64

public typealias CMTimeScale = Int32

/// How a time is rounded to another timescale.
public enum CMTimeRoundingMethod: UInt32, Hashable, Sendable {
    case roundHalfAwayFromZero = 1
    case roundTowardZero = 2
    case roundAwayFromZero = 3
    case quickTime = 4
    case roundTowardPositiveInfinity = 5
    case roundTowardNegativeInfinity = 6

    public static let `default` = CMTimeRoundingMethod.roundHalfAwayFromZero

    /// QuickTime's rounds toward zero, but never a time that isn't zero
    /// to zero, which this doesn't keep.
    fileprivate var rounding: MediaTime.Rounding {
        switch self {
        case .roundHalfAwayFromZero: .halfAwayFromZero
        case .roundTowardZero, .quickTime: .towardZero
        case .roundAwayFromZero: .awayFromZero
        case .roundTowardPositiveInfinity: .towardPositiveInfinity
        case .roundTowardNegativeInfinity: .towardNegativeInfinity
        }
    }
}

extension MediaTime {

    /// The time nearest `seconds` that `preferredTimescale` can hold.
    public init(seconds: Double, preferredTimescale: CMTimeScale) {
        self.init(seconds: seconds, timescale: preferredTimescale)
    }

    /// The time in another timescale, rounded.
    public func convertScale(_ newTimescale: CMTimeScale, method: CMTimeRoundingMethod) -> CMTime {
        converted(to: newTimescale, rounding: method.rounding)
    }
}

extension MediaTimeRange {

    public func containsTime(_ time: CMTime) -> Bool {
        contains(time)
    }

    public func containsTimeRange(_ range: CMTimeRange) -> Bool {
        contains(range)
    }
}

// MARK: - Functions

public let kCMTimeZero = CMTime.zero

public let kCMTimeInvalid = CMTime.invalid

public let kCMTimeIndefinite = CMTime.indefinite

public let kCMTimePositiveInfinity = CMTime.positiveInfinity

public let kCMTimeNegativeInfinity = CMTime.negativeInfinity

public func CMTimeMake(value: CMTimeValue, timescale: CMTimeScale) -> CMTime {
    CMTime(value: value, timescale: timescale)
}

public func CMTimeMakeWithSeconds(_ seconds: Double, preferredTimescale: CMTimeScale) -> CMTime {
    CMTime(seconds: seconds, preferredTimescale: preferredTimescale)
}

public func CMTimeGetSeconds(_ time: CMTime) -> Double {
    time.seconds
}

public func CMTimeAdd(_ lhs: CMTime, _ rhs: CMTime) -> CMTime {
    lhs + rhs
}

public func CMTimeSubtract(_ lhs: CMTime, _ rhs: CMTime) -> CMTime {
    lhs - rhs
}

/// -1, 0 or 1, as `lhs` is before, the same as, or after `rhs`.
public func CMTimeCompare(_ lhs: CMTime, _ rhs: CMTime) -> Int32 {
    lhs < rhs ? -1 : (lhs == rhs ? 0 : 1)
}

public func CMTimeConvertScale(_ time: CMTime, timescale: CMTimeScale, method: CMTimeRoundingMethod) -> CMTime {
    time.convertScale(timescale, method: method)
}

public func CMTimeRangeMake(start: CMTime, duration: CMTime) -> CMTimeRange {
    CMTimeRange(start: start, duration: duration)
}

public func CMTimeRangeContainsTime(_ range: CMTimeRange, time: CMTime) -> Bool {
    range.contains(time)
}
