import Foundation
#if canImport(CoreGraphics)
import CoreGraphics
#endif
import Observation
import Testing
@testable import Cacao

@Observable
@MainActor
final class GestureLog {
    var events: [String] = []
    func log(_ event: String) { events.append(event) }
}

@MainActor
extension ViewGraph {

    /// Presses and releases at a point, settling after each.
    func click(_ point: CGPoint, at time: Double) {
        pointer(.began, at: point, time: time)
        settle()
        pointer(.ended, at: point, time: time + 0.05)
        settle()
    }

    /// Drags from one point to another in steps.
    func drag(from start: CGPoint, to end: CGPoint, at time: Double, steps: Int = 4, release: Bool = true) {
        pointer(.began, at: start, time: time)
        settle()
        for step in 1...steps {
            let fraction = CGFloat(step) / CGFloat(steps)
            let point = CGPoint(x: start.x + (end.x - start.x) * fraction, y: start.y + (end.y - start.y) * fraction)
            pointer(.moved, at: point, time: time + 0.02 * Double(step))
            settle()
        }
        if release {
            pointer(.ended, at: end, time: time + 0.02 * Double(steps + 1))
            settle()
        }
    }

    func center(_ identifier: String) -> CGPoint {
        let frame = frame(identifier)
        return CGPoint(x: frame.midX, y: frame.midY)
    }
}

@MainActor
@Suite struct GestureTests {

    let log = GestureLog()

    @Test func tapGestureEnds() {
        let log = self.log
        let graph = layout(Color.red.frame(width: 100, height: 100).probe("box").onTapGesture { log.log("tap") })
        graph.click(graph.center("box"), at: 1)
        #expect(log.events == ["tap"])
    }

    @Test func tapFailsWhenMovedAway() {
        let log = self.log
        let graph = layout(Color.red.frame(width: 100, height: 100).probe("box").onTapGesture { log.log("tap") })
        let center = graph.center("box")
        graph.drag(from: center, to: CGPoint(x: center.x + 30, y: center.y), at: 1)
        #expect(log.events.isEmpty)
    }

    @Test func doubleTapNeedsTwoQuickTaps() {
        let log = self.log
        let graph = layout(Color.red.frame(width: 100, height: 100).probe("box").onTapGesture(count: 2) { log.log("double") })
        let center = graph.center("box")
        graph.click(center, at: 1)
        #expect(log.events.isEmpty)
        graph.click(center, at: 1.2)
        #expect(log.events == ["double"])
        // Too slow: the first tap times out.
        graph.click(center, at: 3)
        graph.advance(to: 3.5)
        graph.click(center, at: 3.6)
        #expect(log.events == ["double"])
        #expect(graph.gestureSession != nil)
    }

    @Test func doubleTapTakesPrecedenceOverSingle() {
        let log = self.log
        let graph = layout(
            Color.red.frame(width: 100, height: 100).probe("box")
                .onTapGesture(count: 2) { log.log("double") }
                .onTapGesture { log.log("single") }
        )
        let center = graph.center("box")
        graph.click(center, at: 1)
        graph.click(center, at: 1.1)
        #expect(log.events == ["double"])
        // One tap waits for the double tap to fail.
        graph.click(center, at: 3)
        #expect(log.events == ["double"])
        graph.advance(to: 3.5)
        #expect(log.events == ["double", "single"])
    }

    @Test func spatialTapReportsLocalLocation() {
        let log = self.log
        let graph = layout(
            Color.red.frame(width: 100, height: 100).probe("box")
                .onTapGesture { location in log.log("\(Int(location.x)),\(Int(location.y))") }
        )
        let frame = graph.frame("box")
        graph.click(CGPoint(x: frame.minX + 10, y: frame.minY + 20), at: 1)
        #expect(log.events == ["10,20"])
    }

    @Test func longPressNeedsDuration() {
        let log = self.log
        let graph = layout(
            Color.red.frame(width: 100, height: 100).probe("box")
                .onLongPressGesture(minimumDuration: 0.5) {
                    log.log("long")
                } onPressingChanged: { pressing in
                    log.log("pressing \(pressing)")
                }
        )
        let center = graph.center("box")
        // Released too soon.
        graph.click(center, at: 1)
        #expect(log.events == ["pressing true", "pressing false"])
        log.events.removeAll()
        graph.pointer(.began, at: center, time: 2)
        graph.settle()
        #expect(graph.hasActiveAnimations)
        graph.advance(to: 2.3)
        #expect(log.events == ["pressing true"])
        graph.advance(to: 2.6)
        #expect(log.events == ["pressing true", "long", "pressing false"])
        graph.pointer(.ended, at: center, time: 2.7)
        #expect(log.events.count == 3)
    }

    @Test func dragReportsTranslation() {
        let log = self.log
        let graph = layout(
            Color.red.frame(width: 100, height: 100).probe("box")
                .gesture(
                    DragGesture()
                        .onChanged { log.log("changed \(Int($0.translation.width))") }
                        .onEnded { log.log("ended \(Int($0.translation.width))") }
                )
        )
        let center = graph.center("box")
        graph.drag(from: center, to: CGPoint(x: center.x + 40, y: center.y), at: 1)
        // From the minimum distance of 10 points.
        #expect(log.events == ["changed 10", "changed 20", "changed 30", "changed 40", "ended 40"])
    }

    @Test func dragShorterThanMinimumDistanceFails() {
        let log = self.log
        let graph = layout(
            Color.red.frame(width: 100, height: 100).probe("box")
                .gesture(DragGesture(minimumDistance: 20).onEnded { _ in log.log("ended") })
        )
        let center = graph.center("box")
        graph.drag(from: center, to: CGPoint(x: center.x + 10, y: center.y), at: 1)
        #expect(log.events.isEmpty)
    }

    @Test func gestureStateResetsWhenTheGestureEnds() {
        struct Draggable: View {
            @GestureState var offset: CGFloat = 0
            var body: some View {
                Color.red.frame(width: 50, height: 50)
                    .probe("box")
                    .offset(x: offset)
                    .gesture(DragGesture(minimumDistance: 0).updating($offset) { value, state, _ in
                        state = value.translation.width
                    })
            }
        }
        let graph = layout(Draggable())
        let start = graph.frame("box")
        let center = CGPoint(x: start.midX, y: start.midY)
        graph.drag(from: center, to: CGPoint(x: center.x + 40, y: center.y), at: 1, release: false)
        #expect(graph.frame("box").minX == start.minX + 40)
        graph.pointer(.ended, at: CGPoint(x: center.x + 40, y: center.y), time: 2)
        graph.settle()
        #expect(graph.frame("box").minX == start.minX)
    }

    @Test func buttonInsideDragContainerYieldsToDrag() {
        let log = self.log
        let graph = layout(
            VStack {
                Button("Press") { log.log("button") }
            }
            .frame(width: 300, height: 200)
            .contentShape(Rectangle())
            .gesture(DragGesture().onEnded { _ in log.log("drag") })
        )
        guard let frame = graph.textFrames["Press"] else {
            Issue.record("No button")
            return
        }
        let center = CGPoint(x: frame.midX, y: frame.midY)
        graph.click(center, at: 1)
        #expect(log.events == ["button"])
        graph.drag(from: center, to: CGPoint(x: center.x + 60, y: center.y), at: 2)
        #expect(log.events == ["button", "drag"])
    }

    @Test func highPriorityGestureBeatsSubviews() {
        let log = self.log
        let graph = layout(
            VStack {
                Color.red.frame(width: 50, height: 50).probe("inner").onTapGesture { log.log("inner") }
            }
            .highPriorityGesture(TapGesture().onEnded { log.log("outer") })
        )
        graph.click(graph.center("inner"), at: 1)
        #expect(log.events == ["outer"])
    }

    @Test func innerGestureBeatsOuterByDefault() {
        let log = self.log
        let graph = layout(
            VStack {
                Color.red.frame(width: 50, height: 50).probe("inner").onTapGesture { log.log("inner") }
            }
            .onTapGesture { log.log("outer") }
        )
        graph.click(graph.center("inner"), at: 1)
        #expect(log.events == ["inner"])
    }

    @Test func simultaneousGesturesBothRecognize() {
        let log = self.log
        let graph = layout(
            VStack {
                Color.red.frame(width: 50, height: 50).probe("inner").onTapGesture { log.log("inner") }
            }
            .simultaneousGesture(TapGesture().onEnded { log.log("outer") })
        )
        graph.click(graph.center("inner"), at: 1)
        #expect(Set(log.events) == ["inner", "outer"])
    }

    @Test func gestureMaskDisablesGestures() {
        let log = self.log
        let subviewsOnly = layout(
            VStack {
                Color.red.frame(width: 50, height: 50).probe("inner").onTapGesture { log.log("inner") }
            }
            .gesture(TapGesture().onEnded { log.log("outer") }, including: .subviews)
        )
        subviewsOnly.click(subviewsOnly.center("inner"), at: 1)
        #expect(log.events == ["inner"])
        log.events.removeAll()
        let gestureOnly = layout(
            VStack {
                Color.red.frame(width: 50, height: 50).probe("inner").onTapGesture { log.log("inner") }
            }
            .gesture(TapGesture().onEnded { log.log("outer") }, including: .gesture)
        )
        gestureOnly.click(gestureOnly.center("inner"), at: 1)
        #expect(log.events == ["outer"])
    }

    @Test func sequenceStartsSecondAfterFirst() {
        let log = self.log
        let graph = layout(
            Color.red.frame(width: 100, height: 100).probe("box")
                .gesture(
                    LongPressGesture(minimumDuration: 0.3)
                        .sequenced(before: DragGesture(minimumDistance: 0))
                        .onEnded { value in
                            if case let .second(true, drag?) = value {
                                log.log("dragged \(Int(drag.translation.width))")
                            }
                        }
                )
        )
        let center = graph.center("box")
        // Dragging right away fails the long press.
        graph.drag(from: center, to: CGPoint(x: center.x + 30, y: center.y), at: 1)
        #expect(log.events.isEmpty)
        graph.pointer(.began, at: center, time: 2)
        graph.advance(to: 2.4)
        graph.pointer(.moved, at: CGPoint(x: center.x + 25, y: center.y), time: 2.5)
        graph.pointer(.ended, at: CGPoint(x: center.x + 25, y: center.y), time: 2.6)
        graph.settle()
        #expect(log.events == ["dragged 25"])
    }

    @Test func exclusiveGesturePrefersFirst() {
        let log = self.log
        let graph = layout(
            Color.red.frame(width: 100, height: 100).probe("box")
                .gesture(
                    TapGesture(count: 2).onEnded { log.log("double") }
                        .exclusively(before: TapGesture().onEnded { log.log("single") })
                )
        )
        let center = graph.center("box")
        graph.click(center, at: 1)
        graph.click(center, at: 1.1)
        #expect(log.events == ["double"])
        graph.click(center, at: 3)
        graph.advance(to: 3.5)
        #expect(log.events == ["double", "single"])
    }

    @Test func magnifyReportsScale() {
        let log = self.log
        let graph = layout(
            Color.red.frame(width: 100, height: 100).probe("box")
                .gesture(
                    MagnifyGesture()
                        .onChanged { log.log("scale \($0.magnification)") }
                        .onEnded { log.log("ended \($0.magnification)") }
                )
        )
        let center = graph.center("box")
        graph.magnify(.began, scale: 1, at: center, time: 1)
        graph.magnify(.moved, scale: 1.5, at: center, time: 1.1)
        graph.magnify(.moved, scale: 2, at: center, time: 1.2)
        graph.magnify(.ended, scale: 2, at: center, time: 1.3)
        #expect(log.events == ["scale 1.5", "scale 2.0", "ended 2.0"])
        #expect(graph.gestureSession == nil)
    }

    @Test func mapTransformsValues() {
        let log = self.log
        let graph = layout(
            Color.red.frame(width: 100, height: 100).probe("box")
                .gesture(TapGesture().map { "mapped" }.onEnded { log.log($0) })
        )
        graph.click(graph.center("box"), at: 1)
        #expect(log.events == ["mapped"])
    }

    @Test func disabledViewsHaveNoGestures() {
        let log = self.log
        let graph = layout(
            Color.red.frame(width: 100, height: 100).probe("box")
                .onTapGesture { log.log("tap") }
                .disabled(true)
        )
        graph.click(graph.center("box"), at: 1)
        #expect(log.events.isEmpty)
    }

    @Test func rotateGestureFollowsTwoFingerTouches() {
        let log = self.log
        let graph = layout(
            Color.red.frame(width: 200, height: 200).probe("box")
                .gesture(
                    RotateGesture()
                        .onChanged { log.log("angle \(Int(($0.rotation.degrees).rounded()))") }
                        .onEnded { log.log("ended \(Int(($0.rotation.degrees).rounded()))") }
                )
        )
        let center = graph.center("box")
        var tracker = TouchRotationTracker()
        func send(_ update: TouchRotationTracker.Update?, at time: Double) {
            guard let update else { return }
            graph.rotate(update.phase, angle: update.angle, at: update.location, time: time)
        }
        // Two fingers either side of the center turn a quarter turn clockwise.
        send(tracker.fingerDown(1, at: CGPoint(x: center.x - 40, y: center.y)), at: 1)
        send(tracker.fingerDown(2, at: CGPoint(x: center.x + 40, y: center.y)), at: 1)
        for step in 1...3 {
            let angle = Double(step) * .pi / 6
            let offset = CGPoint(x: 40 * cos(angle), y: 40 * sin(angle))
            send(tracker.fingerMoved(2, to: CGPoint(x: center.x + offset.x, y: center.y + offset.y)), at: 1 + Double(step) * 0.1)
            send(tracker.fingerMoved(1, to: CGPoint(x: center.x - offset.x, y: center.y - offset.y)), at: 1 + Double(step) * 0.1 + 0.05)
        }
        send(tracker.fingerUp(2), at: 2)
        #expect(log.events.last == "ended 90")
        #expect(log.events.first?.hasPrefix("angle ") == true)
        #expect(graph.gestureSession == nil)
    }
}

@Suite struct TouchRotationTrackerTests {

    @Test func reportsTheTurnOfTheFirstTwoFingers() {
        var tracker = TouchRotationTracker()
        #expect(tracker.fingerDown(1, at: CGPoint(x: 0, y: 0)) == nil)
        let began = tracker.fingerDown(2, at: CGPoint(x: 10, y: 0))
        #expect(began == .init(phase: .began, angle: 0, location: CGPoint(x: 5, y: 0)))
        // Moving the second finger below the first turns clockwise on screen.
        let moved = tracker.fingerMoved(2, to: CGPoint(x: 0, y: 10))
        #expect(moved?.phase == .moved)
        #expect(abs((moved?.angle ?? 0) - .pi / 2) < 1e-9)
        // A third finger doesn't count.
        #expect(tracker.fingerDown(3, at: CGPoint(x: 50, y: 50)) == nil)
        #expect(tracker.fingerMoved(3, to: CGPoint(x: 60, y: 50)) == nil)
        let ended = tracker.fingerUp(1)
        #expect(ended?.phase == .ended)
        #expect(tracker.fingerMoved(2, to: CGPoint(x: 5, y: 5)) == nil)
    }

    @Test func keepsCountingPastAHalfTurn() {
        var tracker = TouchRotationTracker()
        _ = tracker.fingerDown(1, at: .zero)
        _ = tracker.fingerDown(2, at: CGPoint(x: 10, y: 0))
        var angle = 0.0
        for step in 1...12 {
            let turn = Double(step) * .pi / 4
            angle = tracker.fingerMoved(2, to: CGPoint(x: 10 * cos(turn), y: 10 * sin(turn)))?.angle ?? angle
        }
        // One and a half turns.
        #expect(abs(angle - 3 * .pi) < 1e-9)
        #expect(tracker.fingerUp(2, cancelled: true)?.phase == .cancelled)
    }
}

