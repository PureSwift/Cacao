import Testing
@testable import CacaoScrollPhysics

@Suite struct ScrollPhysicsTests {

    @Test func constants() {
        #expect(ScrollPhysics.panThreshold == 10)
        #expect(ScrollPhysics.normalDecelerationRate > 0 && ScrollPhysics.normalDecelerationRate < 1)
    }

    @Test func velocityOverRecentPositions() {
        var tracker = VelocityTracker()
        tracker.reset(x: 0, y: 0, time: 0)
        tracker.add(x: 0, y: 10, time: 0.01)
        tracker.add(x: 0, y: 30, time: 0.03)
        #expect(abs(tracker.velocity.y - 1000) < 0.001)
        #expect(tracker.velocity.x == 0)
        // Old positions fall out of the window.
        tracker.add(x: 0, y: 30, time: 1)
        #expect(tracker.velocity.y == 0)
    }

    @Test func slowFlicksDontCoast() {
        #expect(Deceleration(velocity: (0, 20), time: 0) == nil)
        #expect(Deceleration.glide(velocity: 20) == nil)
    }

    @Test func steppedDecelerationMatchesGlide() throws {
        var deceleration = try #require(Deceleration(velocity: (0, 2000), time: 0))
        let glide = try #require(Deceleration.glide(velocity: 2000))
        var distance = 0.0
        var time = 0.0
        while !deceleration.isFinished {
            time += 1.0 / 120
            distance += deceleration.step(at: time).y
        }
        #expect(abs(distance - glide.distance) / glide.distance < 0.02)
        #expect(abs(time - glide.duration) < 0.1)
    }

    @Test func rubberBandResistsOvershoot() {
        #expect(rubberBand(50, low: 0, high: 100, dimension: 300) == 50)
        let banded = rubberBand(-100, low: 0, high: 100, dimension: 300)
        #expect(banded < 0 && banded > -100)
        // The overshoot never reaches the view's length.
        #expect(rubberBand(-100_000, low: 0, high: 100, dimension: 300) > -300)
        #expect(rubberBand(200, low: 0, high: 100, dimension: 300) < 200)
    }

    @Test func springBackSettles() {
        var spring = SpringBack(from: -80, to: 0, time: 0)
        var time = 0.0
        while !spring.isFinished, time < 2 {
            time += 1.0 / 60
            _ = spring.step(at: time)
        }
        #expect(spring.isFinished)
        #expect(time < 0.6)
    }

    @Test func easedScrollEndsAtTarget() {
        let scroll = EasedScroll(from: 0, to: 40, time: 1)
        #expect(scroll.position(at: 1) == 0)
        #expect(scroll.position(at: 1 + EasedScroll.duration / 2) > 20)
        #expect(scroll.position(at: 2) == 40)
        #expect(scroll.isFinished(at: 2))
    }
}
