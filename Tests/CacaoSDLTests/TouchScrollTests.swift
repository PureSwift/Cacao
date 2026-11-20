import CacaoRender
import Foundation
#if canImport(CoreGraphics)
import CoreGraphics
#endif
import Testing
@testable import Cacao
@testable import CacaoSDL

@MainActor
@Suite struct TouchScrollTests {

    /// Two thousand points of rows in a window 400 points tall.
    private func make() -> (ViewGraph, ScrollController, () -> CGFloat) {
        let view = ScrollView {
            VStack(spacing: 0) {
                ForEach(0..<50, id: \.self) { _ in
                    Color.blue.frame(height: 40)
                }
            }
        }
        let graph = ViewGraph(rootView: view, textEngine: FixedTextEngine())
        graph.layout(in: CGSize(width: 300, height: 400))
        let point = CGPoint(x: 150, y: 200)
        return (graph, ScrollController(), {
            graph.scrollState(at: point, delta: CGSize(width: 0, height: 1))?.offset.y
                ?? graph.scrollState(at: point, delta: CGSize(width: 0, height: -1))?.offset.y ?? -1
        })
    }

    @Test func contentFollowsTheFinger() {
        let (graph, controller, offset) = make()
        let point = CGPoint(x: 150, y: 200)
        // The finger moves up 60 points: the content scrolls down by 60.
        #expect(controller.pan(by: CGSize(width: 0, height: -60), at: point, graph: graph, now: 0))
        #expect(offset() == 60)
        #expect(controller.pan(by: CGSize(width: 0, height: 20), at: point, graph: graph, now: 0.01))
        #expect(offset() == 40)
        // Held still, the content stays where it is.
        controller.step(now: 1)
        #expect(offset() == 40)
        #expect(controller.isAnimating)
    }

    @Test func aFlickCoasts() {
        let (graph, controller, offset) = make()
        let point = CGPoint(x: 150, y: 200)
        for step in 0..<5 {
            controller.pan(by: CGSize(width: 0, height: -20), at: point, graph: graph, now: Double(step) * 0.01)
        }
        #expect(offset() == 100)
        controller.endPan(now: 0.05)
        controller.step(now: 0.2)
        #expect(offset() > 100)
        // It comes to rest.
        controller.step(now: 30)
        controller.step(now: 31)
        #expect(!controller.isAnimating)
    }

    /// A real finger's flick down a list also moves a little across it.
    @Test func aFlickThatIsNotQuiteStraightStillCoasts() {
        let (graph, controller, offset) = make()
        let point = CGPoint(x: 150, y: 200)
        for step in 0..<5 {
            controller.pan(by: CGSize(width: 3, height: -25), at: point, graph: graph, now: Double(step) * 0.01)
        }
        #expect(offset() == 125)
        controller.endPan(now: 0.05)
        controller.step(now: 0.07)
        controller.step(now: 0.2)
        controller.step(now: 0.4)
        // Well past where the finger left it.
        #expect(offset() > 400)
        #expect(controller.isAnimating)
    }

    @Test func aFingerHeldStillBeforeLiftingDoesNotCoast() {
        let (graph, controller, offset) = make()
        let point = CGPoint(x: 150, y: 200)
        for step in 0..<5 {
            controller.pan(by: CGSize(width: 0, height: -20), at: point, graph: graph, now: Double(step) * 0.01)
        }
        controller.endPan(now: 1)
        controller.step(now: 1.2)
        #expect(offset() == 100)
        #expect(!controller.isAnimating)
    }

    @Test func pullingPastTheTopSpringsBack() {
        let (graph, controller, offset) = make()
        let point = CGPoint(x: 150, y: 200)
        controller.pan(by: CGSize(width: 0, height: -40), at: point, graph: graph, now: 0)
        // Down 100 points from there: 60 past the top, on a rubber band.
        controller.pan(by: CGSize(width: 0, height: 100), at: point, graph: graph, now: 0.01)
        #expect(offset() < 0)
        #expect(offset() > -60)
        controller.endPan(now: 1)
        controller.step(now: 5)
        controller.step(now: 6)
        #expect(abs(offset()) < 0.5)
    }

    @Test func aPanBeginsWithoutMovingTheContent() {
        let (graph, controller, offset) = make()
        let point = CGPoint(x: 150, y: 200)
        // The finger has gone 12 points by the time it's a pan.
        #expect(controller.beginPan(toward: CGSize(width: 0, height: -12), at: point, graph: graph, now: 0))
        #expect(offset() == 0)
        controller.pan(by: CGSize(width: 0, height: -5), at: point, graph: graph, now: 0.01)
        #expect(offset() == 5)
        // At the top, a finger moving down has nothing to scroll.
        let (other, second, _) = make()
        #expect(!second.beginPan(toward: CGSize(width: 0, height: 12), at: point, graph: other, now: 0))
    }

    @Test func aFingerDownCatchesCoastingContent() {
        let (graph, controller, offset) = make()
        let point = CGPoint(x: 150, y: 200)
        for step in 0..<5 {
            controller.pan(by: CGSize(width: 0, height: -20), at: point, graph: graph, now: Double(step) * 0.01)
        }
        controller.endPan(now: 0.05)
        controller.step(now: 0.2)
        let caught = offset()
        #expect(caught > 100)
        controller.catchMotion()
        controller.step(now: 0.5)
        #expect(offset() == caught)
        #expect(!controller.isAnimating)
    }

    @Test func nothingScrollsWhereThereIsNoScrollView() {
        let graph = ViewGraph(rootView: Color.blue, textEngine: FixedTextEngine())
        graph.layout(in: CGSize(width: 300, height: 400))
        let controller = ScrollController()
        #expect(!controller.pan(by: CGSize(width: 0, height: -60), at: CGPoint(x: 150, y: 200), graph: graph, now: 0))
    }
}
