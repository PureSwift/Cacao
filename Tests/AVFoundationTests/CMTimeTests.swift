import CoreMedia
import Testing

/// CoreMedia's times, as Apple's are written.
@Suite struct CMTimeTests {

    @Test func timesAreMadeAndCompared() {
        let frame = CMTime(value: 1, timescale: 30)
        #expect(frame == CMTimeMake(value: 1, timescale: 30))
        #expect(CMTime(seconds: 0.5, preferredTimescale: 600) == CMTime(value: 300, timescale: 600))
        #expect(CMTimeMakeWithSeconds(2, preferredTimescale: 1).seconds == 2)
        #expect(CMTimeGetSeconds(CMTime(value: 3, timescale: 2)) == 1.5)
        #expect(frame < CMTime(value: 1, timescale: 25))
        #expect(CMTimeCompare(frame, .zero) == 1)
        #expect(CMTimeCompare(.zero, frame) == -1)
        #expect(CMTimeCompare(frame, CMTime(value: 2, timescale: 60)) == 0)
        #expect(CMTime.zero == kCMTimeZero)
        #expect(!CMTime.invalid.isValid)
        #expect(CMTime.indefinite.isIndefinite)
        #expect(!CMTime.positiveInfinity.isNumeric)
    }

    @Test func timesAreAddedAndConverted() {
        let sum = CMTimeAdd(CMTime(value: 1, timescale: 2), CMTime(value: 1, timescale: 4))
        #expect(sum == CMTime(value: 3, timescale: 4))
        #expect(CMTimeSubtract(sum, CMTime(value: 1, timescale: 4)) == CMTime(value: 1, timescale: 2))
        #expect(sum + sum == CMTime(value: 3, timescale: 2))
        let third = CMTime(value: 1, timescale: 3)
        #expect(third.convertScale(10, method: .roundTowardZero).value == 3)
        #expect(third.convertScale(10, method: .roundAwayFromZero).value == 4)
        #expect(CMTimeConvertScale(third, timescale: 1000, method: .default).value == 333)
    }

    @Test func rangesContainTimes() {
        let range = CMTimeRange(start: CMTime(value: 1, timescale: 1), duration: CMTime(value: 2, timescale: 1))
        #expect(range == CMTimeRangeMake(start: CMTime(value: 1, timescale: 1), duration: CMTime(value: 2, timescale: 1)))
        #expect(range.end == CMTime(value: 3, timescale: 1))
        #expect(range.containsTime(CMTime(value: 2, timescale: 1)))
        #expect(!range.containsTime(CMTime(value: 3, timescale: 1)))
        #expect(CMTimeRangeContainsTime(range, time: CMTime(value: 1, timescale: 1)))
        #expect(range.containsTimeRange(CMTimeRange(start: CMTime(value: 2, timescale: 1), end: CMTime(value: 3, timescale: 1))))
    }
}
