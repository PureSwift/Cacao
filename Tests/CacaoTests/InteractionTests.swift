import Foundation
#if canImport(CoreGraphics)
import CoreGraphics
#endif
import Testing
@testable import Cacao

@MainActor
@Suite struct InteractionTests {

    final class Log {
        var events: [String] = []
    }

    @Test func buttonTapRunsAction() {
        let log = Log()
        let graph = layout(Button("Tap") { log.events.append("tap") }.probe("button"))
        let frame = graph.frame("button")
        graph.pointer(.began, at: CGPoint(x: frame.midX, y: frame.midY))
        graph.pointer(.ended, at: CGPoint(x: frame.midX, y: frame.midY))
        #expect(log.events == ["tap"])
    }

    @Test func pressReleasedOutsideDoesNothing() {
        let log = Log()
        let graph = layout(Button("Tap") { log.events.append("tap") }.probe("button"))
        let frame = graph.frame("button")
        graph.pointer(.began, at: CGPoint(x: frame.midX, y: frame.midY))
        graph.pointer(.moved, at: CGPoint(x: frame.maxX + 50, y: frame.midY))
        graph.pointer(.ended, at: CGPoint(x: frame.maxX + 50, y: frame.midY))
        #expect(log.events.isEmpty)
    }

    @Test func pressedStateRestylesButton() {
        struct Recording: ButtonStyle {
            func makeBody(configuration: Configuration) -> some View {
                configuration.label.opacity(configuration.isPressed ? 0.5 : 1)
            }
        }
        let graph = layout(Button("Tap") { }.buttonStyle(Recording()).probe("button"))
        func opacities() -> [Double] {
            graph.displayList().items.compactMap { item in
                if case let .effect(.opacity(value), _) = item.value { return value }
                return nil
            }
        }
        #expect(opacities() == [1])
        let frame = graph.frame("button")
        graph.pointer(.began, at: CGPoint(x: frame.midX, y: frame.midY))
        graph.update()
        #expect(opacities() == [0.5])
        graph.pointer(.ended, at: CGPoint(x: frame.midX, y: frame.midY))
        graph.update()
        #expect(opacities() == [1])
    }

    @Test func disabledButtonIgnoresTaps() {
        let log = Log()
        let graph = layout(Button("Tap") { log.events.append("tap") }.disabled(true).probe("button"))
        let frame = graph.frame("button")
        graph.pointer(.began, at: CGPoint(x: frame.midX, y: frame.midY))
        graph.pointer(.ended, at: CGPoint(x: frame.midX, y: frame.midY))
        #expect(log.events.isEmpty)
    }

    @Test func innermostTapWins() {
        let log = Log()
        let graph = layout(
            VStack {
                Color.red.frame(width: 50, height: 50)
                    .onTapGesture { log.events.append("inner") }
                    .probe("inner")
                Color.blue.frame(width: 50, height: 50)
            }
            .onTapGesture { log.events.append("outer") }
        )
        let inner = graph.frame("inner")
        graph.pointer(.began, at: CGPoint(x: inner.midX, y: inner.midY))
        graph.pointer(.ended, at: CGPoint(x: inner.midX, y: inner.midY))
        graph.pointer(.began, at: CGPoint(x: inner.midX, y: inner.maxY + 30))
        graph.pointer(.ended, at: CGPoint(x: inner.midX, y: inner.maxY + 30))
        #expect(log.events == ["inner", "outer"])
    }

    @Test func clearAreasNeedContentShape() {
        let log = Log()
        let graph = layout(
            VStack {
                Color.clear.frame(width: 50, height: 50).onTapGesture { log.events.append("clear") }.probe("clear")
                Color.clear.frame(width: 50, height: 50).contentShape(Rectangle()).onTapGesture { log.events.append("shaped") }.probe("shaped")
            }
        )
        for name in ["clear", "shaped"] {
            let frame = graph.frame(name)
            graph.pointer(.began, at: CGPoint(x: frame.midX, y: frame.midY))
            graph.pointer(.ended, at: CGPoint(x: frame.midX, y: frame.midY))
        }
        #expect(log.events == ["shaped"])
    }

    @Test func circleHitsInsideItsPath() {
        let log = Log()
        let graph = layout(Circle().frame(width: 100, height: 100).onTapGesture { log.events.append("circle") }.probe("circle"))
        let frame = graph.frame("circle")
        // A corner of the frame is outside the circle.
        graph.pointer(.began, at: CGPoint(x: frame.minX + 2, y: frame.minY + 2))
        graph.pointer(.ended, at: CGPoint(x: frame.minX + 2, y: frame.minY + 2))
        graph.pointer(.began, at: CGPoint(x: frame.midX, y: frame.midY))
        graph.pointer(.ended, at: CGPoint(x: frame.midX, y: frame.midY))
        #expect(log.events == ["circle"])
    }

    // MARK: Scrolling

    struct Rows: View {
        var log: Log?
        var body: some View {
            ScrollView {
                VStack(spacing: 0) {
                    ForEach(0..<50) { index in
                        Color.gray.frame(height: 20)
                            .onTapGesture { log?.events.append("row \(index)") }
                            .probe("row \(index)")
                    }
                }
            }
            .frame(width: 100, height: 200)
            .probe("scroll")
        }
    }

    @Test func scrollViewLaysOutContentUnscrolled() {
        let graph = layout(Rows(), width: 100, height: 200)
        #expect(graph.frame("scroll") == rect(0, 0, 100, 200))
        #expect(graph.frame("row 0") == rect(0, 0, 100, 20))
        #expect(graph.frame("row 49") == rect(0, 980, 100, 20))
    }

    @Test func scrollingClampsToContent() throws {
        let graph = layout(Rows(), width: 100, height: 200)
        let state = try #require(graph.scrollState(at: CGPoint(x: 50, y: 50), delta: CGSize(width: 0, height: 10)))
        #expect(state.maxOffset == CGPoint(x: 0, y: 800))
        #expect(graph.scroll(by: CGSize(width: 0, height: 5000), at: CGPoint(x: 50, y: 50)))
        #expect(state.offset == CGPoint(x: 0, y: 800))
        #expect(!graph.scroll(by: CGSize(width: 0, height: 10), at: CGPoint(x: 50, y: 50)))
        #expect(graph.scroll(by: CGSize(width: 0, height: -100), at: CGPoint(x: 50, y: 50)))
        #expect(state.offset == CGPoint(x: 0, y: 700))
    }

    @Test func scrollingDoesNotUpdateOrLayOut() {
        let graph = layout(Rows(), width: 100, height: 200)
        _ = graph.displayList()
        let before = graph.statistics
        graph.scroll(by: CGSize(width: 0, height: 300), at: CGPoint(x: 50, y: 50))
        #expect(graph.needsDisplay)
        #expect(!graph.needsUpdate)
        let list = graph.displayList()
        #expect(graph.statistics == before)
        // The content keeps its unscrolled frames; the scroll effect moves it.
        guard case let .effect(.scroll(effect), _) = list.items.first?.value else {
            Issue.record("Expected a scroll effect")
            return
        }
        #expect(effect.offset == CGPoint(x: 0, y: 300))
    }

    @Test func tapsHitScrolledContent() {
        let log = Log()
        let graph = layout(Rows(log: log), width: 100, height: 200)
        graph.scroll(by: CGSize(width: 0, height: 300), at: CGPoint(x: 50, y: 50))
        // Row 15 spans 300 to 320 in the content, so 0 to 20 on screen.
        graph.pointer(.began, at: CGPoint(x: 50, y: 10))
        graph.pointer(.ended, at: CGPoint(x: 50, y: 10))
        #expect(log.events == ["row 15"])
    }

    // MARK: App

    @Test func appScenesDescribeWindows() {
        struct DemoApp: App {
            var body: some Scene {
                WindowGroup("Main") {
                    Text("Hello")
                }
                .defaultSize(width: 300, height: 200)
                Window("Inspector", id: "inspector") {
                    Text("Details")
                }
            }
        }
        let windows = DemoApp().body.windowDescriptions()
        #expect(windows.map(\.title) == ["Main", "Inspector"])
        #expect(windows.first?.defaultSize == CGSize(width: 300, height: 200))
        #expect(windows.last?.id == "inspector")
    }
}
