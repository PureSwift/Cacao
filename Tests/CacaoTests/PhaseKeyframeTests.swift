import Foundation
#if canImport(CoreGraphics)
import CoreGraphics
#endif
import Testing
import Observation
@testable import Cacao

@MainActor
@Suite struct PhaseKeyframeTests {

    struct Point: Animatable, Equatable {
        var x: Double
        var y: Double
        var animatableData: AnimatablePair<Double, Double> {
            get { AnimatablePair(x, y) }
            set { (x, y) = (newValue.first, newValue.second) }
        }
    }

    @Test func timelineInterpolatesTracks() {
        let timeline = KeyframeTimeline(initialValue: Point(x: 0, y: 0)) {
            KeyframeTrack(\.x) {
                LinearKeyframe(10, duration: 1)
                MoveKeyframe(20)
                LinearKeyframe(30, duration: 1, timingCurve: .easeIn)
            }
            KeyframeTrack(\.y) {
                CubicKeyframe(5, duration: 1)
                CubicKeyframe(0, duration: 1)
            }
        }
        #expect(timeline.duration == 2)
        #expect(timeline.value(time: 0.5).x == 5)
        // The move jumps; the eased segment starts slowly from there.
        let eased = timeline.value(time: 1.5).x
        #expect(eased > 20 && eased < 25)
        #expect(timeline.value(time: 3).x == 30)
        // Cubic keyframes pass through their values.
        #expect(abs(timeline.value(time: 1).y - 5) < 0.0001)
        #expect(timeline.value(time: 0.5).y > 2)
        #expect(timeline.value(progress: 1).y == 0)
    }

    @Test func springKeyframeSettles() {
        let timeline = KeyframeTimeline(initialValue: 0.0) {
            KeyframeTrack {
                SpringKeyframe(1.0, duration: 0.5, spring: .bouncy)
            }
        }
        #expect(timeline.value(time: 0.25) > 0.3)
        #expect(timeline.value(time: 0.5) == 1)
    }

    @Test func keyframeAnimatorRepeats() {
        let graph = layout(
            Color.red.frame(width: 10, height: 10)
                .keyframeAnimator(initialValue: 0.0) { content, value in
                    content.opacity(value)
                } keyframes: { _ in
                    KeyframeTrack {
                        LinearKeyframe(1.0, duration: 1)
                    }
                }
        )
        graph.advance(to: 0.25)
        #expect(abs((graph.colorItems.first?.opacity ?? 0) - 0.25) < 0.001)
        #expect(graph.hasActiveAnimations)
        graph.advance(to: 1.5)
        #expect(abs((graph.colorItems.first?.opacity ?? 0) - 0.5) < 0.001)
    }

    @Observable
    final class Trigger {
        var count = 0
    }

    @Test func keyframeAnimatorPlaysOnTrigger() {
        let trigger = Trigger()
        struct Bouncing: View {
            let trigger: Trigger
            var body: some View {
                Color.red.frame(width: 10, height: 10)
                    .keyframeAnimator(initialValue: 1.0, trigger: trigger.count) { content, value in
                        content.opacity(value)
                    } keyframes: { _ in
                        KeyframeTrack {
                            LinearKeyframe(0.0, duration: 0.5)
                            LinearKeyframe(1.0, duration: 0.5)
                        }
                    }
            }
        }
        let graph = layout(Bouncing(trigger: trigger))
        #expect(graph.colorItems.first?.opacity == 1)
        #expect(!graph.hasActiveAnimations)
        trigger.count += 1
        graph.advance(to: 0)
        graph.advance(to: 0.25)
        #expect(abs((graph.colorItems.first?.opacity ?? 0) - 0.5) < 0.001)
        graph.advance(to: 2)
        #expect(graph.colorItems.first?.opacity == 1)
        #expect(!graph.hasActiveAnimations)
    }

    @Test func phaseAnimatorCyclesOnTrigger() {
        let trigger = Trigger()
        struct Phases: View {
            let trigger: Trigger
            var body: some View {
                PhaseAnimator([10.0, 50.0], trigger: trigger.count) { width in
                    Color.red.frame(width: width, height: 10)
                } animation: { _ in .linear(duration: 1) }
            }
        }
        let graph = layout(Phases(trigger: trigger))
        func width() -> CGFloat { graph.colorItems.first?.frame.width ?? -1 }
        #expect(width() == 10)
        trigger.count += 1
        graph.advance(to: 0)
        graph.advance(to: 0.5)
        // Halfway to the second phase.
        #expect(abs(width() - 30) < 0.01)
        graph.advance(to: 1)
        #expect(width() == 50)
        // Then back to the first phase, and done.
        graph.advance(to: 1.5)
        #expect(abs(width() - 30) < 0.01)
        graph.advance(to: 2.5)
        #expect(width() == 10)
        #expect(!graph.hasActiveAnimations)
    }

    @Test func phaseAnimatorCyclesContinuously() {
        let graph = layout(
            Color.red.frame(width: 10, height: 10)
                .phaseAnimator([1.0, 0.0]) { content, opacity in
                    content.opacity(opacity)
                } animation: { _ in .linear(duration: 1) }
        )
        #expect(graph.colorItems.first?.opacity == 1)
        graph.advance(to: 0)
        graph.advance(to: 0.5)
        #expect(abs((graph.colorItems.first?.opacity ?? 0) - 0.5) < 0.001)
        graph.advance(to: 1)
        graph.advance(to: 1.5)
        #expect(abs((graph.colorItems.first?.opacity ?? 0) - 0.5) < 0.001)
        #expect(graph.hasActiveAnimations)
    }
}
