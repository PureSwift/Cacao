import CacaoRender
import Foundation
#if canImport(CoreGraphics)
import CoreGraphics
#endif
import Testing
@testable import Cacao

@MainActor
@Suite struct ExternalInputTests {

    /// What a surface's producer was sent.
    @MainActor
    final class Log {
        var inputs: [String] = []

        func record(_ input: ExternalInput) {
            switch input {
            case let .pointer(phase, button, location):
                inputs.append("pointer \(phase) \(button) \(Int(location.x)),\(Int(location.y))")
            case let .hover(location):
                inputs.append("hover " + (location.map { "\(Int($0.x)),\(Int($0.y))" } ?? "left"))
            case let .scroll(x, y, location):
                inputs.append("scroll \(x) \(y) \(Int(location.x)),\(Int(location.y))")
            case let .touch(phase, finger, location):
                inputs.append("touch \(phase) \(finger) \(Int(location.x)),\(Int(location.y))")
            case let .key(key):
                inputs.append("key \(key.isDown ? "down" : "up") \(key.usage)")
            case let .text(text):
                inputs.append("text \(text)")
            case let .focus(focused):
                inputs.append("focus \(focused)")
            }
        }
    }

    /// A surface 100 points square, 50 points in from the window's corner,
    /// over a tap target that fills the window.
    private func make(acceptsText: Bool = false) -> (ViewGraph, Log, taps: () -> Int) {
        let log = Log()
        let counter = Counter()
        let surface = ExternalSurface()
        let view = ZStack(alignment: .topLeading) {
            Color.blue.onTapGesture { counter.value += 1 }
            ExternalSurfaceView(surface)
                .onInput(acceptsText: acceptsText) { log.record($0) }
                .frame(width: 100, height: 100)
                .padding(50)
        }
        let graph = ViewGraph(rootView: view, textEngine: FixedTextEngine())
        graph.layout(in: CGSize(width: 300, height: 300))
        return (graph, log, { counter.value })
    }

    @MainActor
    final class Counter {
        var value = 0
    }

    @Test func aPressOnTheSurfaceGoesToItInItsCoordinates() {
        let (graph, log, taps) = make()
        #expect(graph.externalPointer(.began, button: .primary, at: CGPoint(x: 60, y: 70)))
        // The drag and release follow the press, even outside the view.
        #expect(graph.externalPointer(.moved, button: .primary, at: CGPoint(x: 200, y: 20)))
        #expect(graph.externalPointer(.ended, button: .primary, at: CGPoint(x: 200, y: 20)))
        #expect(log.inputs == [
            "focus true",
            "pointer began primary 10,20",
            "pointer moved primary 150,-30",
            "pointer ended primary 150,-30",
        ])
        #expect(taps() == 0)
        // The press is over: another movement isn't the surface's.
        #expect(!graph.externalPointer(.moved, button: .primary, at: CGPoint(x: 60, y: 70)))
    }

    @Test func aPressElsewhereIsNotTheSurfaces() {
        let (graph, log, taps) = make()
        let point = CGPoint(x: 250, y: 250)
        #expect(!graph.externalPointer(.began, button: .primary, at: point))
        graph.pointer(.began, at: point)
        graph.pointer(.ended, at: point)
        #expect(log.inputs.isEmpty)
        #expect(taps() == 1)
    }

    @Test func otherButtonsReachTheSurface() {
        let (graph, log, _) = make()
        #expect(graph.externalPointer(.began, button: .secondary, at: CGPoint(x: 100, y: 100)))
        #expect(graph.externalPointer(.ended, button: .secondary, at: CGPoint(x: 100, y: 100)))
        #expect(log.inputs.suffix(2) == ["pointer began secondary 50,50", "pointer ended secondary 50,50"])
    }

    @Test func hoveringReportsMovementAndLeaving() {
        let (graph, log, _) = make()
        graph.externalHover(at: CGPoint(x: 75, y: 75))
        graph.externalHover(at: CGPoint(x: 250, y: 250))
        graph.externalHover(at: CGPoint(x: 250, y: 260))
        #expect(log.inputs == ["hover 25,25", "hover left"])
    }

    @Test func scrollingOverTheSurfaceGoesToIt() {
        let (graph, log, _) = make()
        #expect(graph.externalScroll(x: 0, y: -1, at: CGPoint(x: 140, y: 140)))
        #expect(!graph.externalScroll(x: 0, y: -1, at: CGPoint(x: 250, y: 250)))
        #expect(log.inputs == ["scroll 0.0 -1.0 90,90"])
    }

    @Test func aFingerBelongsToTheSurfaceItCameDownOn() {
        let (graph, log, _) = make()
        #expect(!graph.externalTouch(.began, finger: 1, at: CGPoint(x: 250, y: 250)))
        #expect(graph.externalTouch(.began, finger: 2, at: CGPoint(x: 60, y: 60)))
        #expect(graph.externalTouch(.moved, finger: 2, at: CGPoint(x: 250, y: 250)))
        #expect(!graph.externalTouch(.moved, finger: 1, at: CGPoint(x: 60, y: 60)))
        #expect(graph.externalTouch(.ended, finger: 2, at: CGPoint(x: 250, y: 250)))
        #expect(!graph.externalTouch(.moved, finger: 2, at: CGPoint(x: 60, y: 60)))
        #expect(log.inputs == ["touch began 2 10,10", "touch moved 2 200,200", "touch ended 2 200,200"])
    }

    @Test func keysAndTextGoToTheSurfaceWhileItHasFocus() {
        let (graph, log, _) = make(acceptsText: true)
        let key = ExternalInput.Key(isDown: true, usage: 4, keyCode: 97)
        // No focus yet.
        #expect(!graph.externalKey(key))
        #expect(!graph.acceptsTextInput)
        graph.externalPointer(.began, button: .primary, at: CGPoint(x: 60, y: 60))
        graph.externalPointer(.ended, button: .primary, at: CGPoint(x: 60, y: 60))
        #expect(graph.acceptsTextInput)
        #expect(graph.externalKey(key))
        #expect(graph.externalKey(ExternalInput.Key(isDown: false, usage: 4, keyCode: 97)))
        graph.insertText("a")
        // A click elsewhere takes focus away.
        graph.pointer(.began, at: CGPoint(x: 250, y: 250))
        graph.pointer(.ended, at: CGPoint(x: 250, y: 250))
        #expect(!graph.externalKey(key))
        #expect(log.inputs.suffix(4) == ["key down 4", "key up 4", "text a", "focus false"])
    }

    @Test func aSurfaceWithoutAHandlerLeavesInputToSwiftUI() {
        let counter = Counter()
        let view = ExternalSurfaceView(ExternalSurface())
            .frame(width: 100, height: 100)
            .onTapGesture { counter.value += 1 }
        let graph = ViewGraph(rootView: view, textEngine: FixedTextEngine())
        graph.layout(in: CGSize(width: 100, height: 100))
        let point = CGPoint(x: 50, y: 50)
        #expect(!graph.externalPointer(.began, button: .primary, at: point))
        graph.pointer(.began, at: point)
        graph.pointer(.ended, at: point)
        #expect(counter.value == 1)
    }
}
