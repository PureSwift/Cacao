import Foundation
#if canImport(CoreGraphics)
import CoreGraphics
#endif
import Testing
@testable import Cacao

@MainActor
@Suite struct TimelineTests {

    @Test func periodicTimelineUpdatesOnSchedule() {
        var now = Date(timeIntervalSinceReferenceDate: 1000)
        let start = Date(timeIntervalSinceReferenceDate: 1000)
        let view = TimelineView(.periodic(from: start, by: 1)) { context in
            Text("\(Int(context.date.timeIntervalSince(start)))")
        }
        let graph = ViewGraph(rootView: EmptyView())
        graph.dateProvider = { now }
        graph.setRootView(view)
        graph.layout(in: CGSize(width: 200, height: 100))
        #expect(graph.texts == ["0"])
        #expect(graph.nextWakeup == 1)
        #expect(!graph.hasActiveAnimations)
        now = now.addingTimeInterval(0.5)
        graph.advance(to: 0.5)
        #expect(graph.texts == ["0"])
        now = now.addingTimeInterval(0.6)
        graph.advance(to: 1.1)
        #expect(graph.texts == ["1"])
    }

    @Test func animationTimelineRunsEveryFrame() {
        let view = TimelineView(.animation) { context in
            Text(context.cadence == .live ? "live" : "slow")
        }
        let graph = layout(view)
        #expect(graph.texts == ["live"])
        #expect(graph.hasActiveAnimations)
        let paused = layout(TimelineView(.animation(paused: true)) { _ in Text("paused") })
        #expect(paused.nextWakeup == nil)
    }

    @Test func explicitTimelineStopsAfterLastDate() {
        var now = Date(timeIntervalSinceReferenceDate: 0)
        let dates = [Date(timeIntervalSinceReferenceDate: 0), Date(timeIntervalSinceReferenceDate: 2)]
        let graph = ViewGraph(rootView: EmptyView())
        graph.dateProvider = { now }
        graph.setRootView(TimelineView(.explicit(dates)) { context in
            Text("\(Int(context.date.timeIntervalSinceReferenceDate))")
        })
        graph.layout(in: CGSize(width: 200, height: 100))
        #expect(graph.texts == ["0"])
        now = Date(timeIntervalSinceReferenceDate: 2.5)
        graph.advance(to: 2.5)
        #expect(graph.texts == ["2"])
        #expect(graph.nextWakeup == nil)
    }
}

@MainActor
@Suite struct CanvasTests {

    @Test func canvasRecordsDrawing() {
        let canvas = Canvas { context, size in
            context.fill(Path(CGRect(origin: .zero, size: size)), with: .color(.red))
            var moved = context
            moved.translateBy(x: 10, y: 0)
            moved.opacity = 0.5
            moved.stroke(Path(CGRect(x: 0, y: 0, width: 5, height: 5)), with: .color(.blue), lineWidth: 2)
            context.draw(Text("Hi"), at: CGPoint(x: size.width / 2, y: size.height / 2))
        }
        .frame(width: 100, height: 50)
        let graph = layout(canvas)
        let drawing = graph.drawnItems.compactMap { drawn -> DrawingContent? in
            if case let .content(.drawing(drawing)) = drawn.item.value { return drawing }
            return nil
        }.first
        #expect(drawing?.operations.count == 3)
        guard let operations = drawing?.operations, operations.count == 3 else { return }
        if case let .shape(shape, state) = operations[0] {
            #expect(shape.path.boundingRect == CGRect(x: 0, y: 0, width: 100, height: 50))
            #expect(state.transform == .identity)
        } else {
            Issue.record("Expected a fill")
        }
        if case let .shape(shape, state) = operations[1] {
            #expect(shape.drawing == .stroke(StrokeStyle(lineWidth: 2)))
            #expect(state.transform == .translation(10, 0))
            #expect(state.opacity == 0.5)
        } else {
            Issue.record("Expected a stroke")
        }
        if case let .text(text, rect, _) = operations[2] {
            #expect(text.string == "Hi")
            #expect(abs(rect.midX - 50) < 0.001 && abs(rect.midY - 25) < 0.001)
        } else {
            Issue.record("Expected text")
        }
    }

    @Test func canvasTakesProposedSize() {
        let graph = layout(Canvas { _, _ in }.probe("canvas"), width: 300, height: 200)
        #expect(graph.frame("canvas").size == CGSize(width: 300, height: 200))
    }
}

@MainActor
@Suite struct ScrollTargetTests {

    func scrollState(_ graph: ViewGraph) -> ScrollState? {
        graph.scrollState(at: CGPoint(x: 50, y: 50), delta: CGSize(width: 1, height: 0))
            ?? graph.scrollState(at: CGPoint(x: 50, y: 50), delta: CGSize(width: 0, height: 1))
    }

    @Test func pagingSnapsToPages() throws {
        let graph = layout(
            ScrollView(.horizontal) {
                HStack(spacing: 0) {
                    ForEach(0..<5) { index in
                        Color.red.frame(width: 200, height: 100)
                    }
                }
            }
            .scrollTargetBehavior(.paging)
            .frame(width: 200, height: 100),
            width: 200, height: 100
        )
        let state = try #require(scrollState(graph))
        // Slow: the nearest page.
        #expect(state.snappedOffset(projected: CGPoint(x: 120, y: 0), from: .zero, velocity: .zero) == CGPoint(x: 200, y: 0))
        #expect(state.snappedOffset(projected: CGPoint(x: 80, y: 0), from: .zero, velocity: .zero) == .zero)
        // Fast: one page in the direction of the flick, never more.
        #expect(state.snappedOffset(projected: CGPoint(x: 50, y: 0), from: .zero, velocity: CGSize(width: 500, height: 0)) == CGPoint(x: 200, y: 0))
        #expect(state.snappedOffset(projected: CGPoint(x: 900, y: 0), from: .zero, velocity: CGSize(width: 5000, height: 0)) == CGPoint(x: 200, y: 0))
        #expect(state.gestureLimit == CGSize(width: 200, height: 100))
    }

    @Test func viewAlignedSnapsToTargetLayoutViews() throws {
        let graph = layout(
            ScrollView(.horizontal) {
                LazyHStack(spacing: 10) {
                    ForEach(0..<10) { index in
                        Color.red.frame(width: 90, height: 100)
                    }
                }
                .scrollTargetLayout()
            }
            .scrollTargetBehavior(.viewAligned)
            .frame(width: 250, height: 100),
            width: 250, height: 100
        )
        let state = try #require(scrollState(graph))
        // Views start every 100 points.
        #expect(state.snappedOffset(projected: CGPoint(x: 140, y: 0), from: .zero, velocity: .zero) == CGPoint(x: 100, y: 0))
        #expect(state.snappedOffset(projected: CGPoint(x: 360, y: 0), from: .zero, velocity: .zero) == CGPoint(x: 400, y: 0))
        #expect(state.gestureLimit == nil)
    }

    @Test func scrollViewsWithoutBehaviorDontSnap() throws {
        let graph = layout(ScrollView { Color.red.frame(height: 1000) }.frame(height: 100), width: 100, height: 100)
        let state = try #require(scrollState(graph))
        #expect(state.snappedOffset(projected: CGPoint(x: 0, y: 130), from: .zero, velocity: .zero) == nil)
    }

    @Test func scrollToShowsLazyRows() throws {
        struct Reader: View {
            let log: GestureLog
            var body: some View {
                ScrollViewReader { proxy in
                    VStack(spacing: 0) {
                        Text("Jump").onTapGesture { proxy.scrollTo(500, anchor: .top) }
                        ScrollView {
                            LazyVStack(spacing: 0) {
                                ForEach(0..<1000, id: \.self) { index in
                                    Text("Row \(index)").frame(height: 20)
                                }
                            }
                        }
                    }
                }
            }
        }
        let graph = layout(Reader(log: GestureLog()), width: 200, height: 220)
        #expect(!graph.texts.contains("Row 500"))
        graph.tapText("Jump")
        graph.settle()
        #expect(graph.texts.contains("Row 500"))
        let state = try #require(graph.scrollState(at: CGPoint(x: 100, y: 100), delta: CGSize(width: 0, height: -1)))
        #expect(abs(state.offset.y - 10_000) < 0.01)
    }

    @Test func animatedScrollToMovesOverTime() throws {
        struct Reader: View {
            var body: some View {
                ScrollViewReader { proxy in
                    VStack(spacing: 0) {
                        Text("Jump").onTapGesture {
                            withAnimation(.linear(duration: 1)) { proxy.scrollTo("bottom", anchor: .top) }
                        }
                        ScrollView {
                            VStack(spacing: 0) {
                                Color.red.frame(height: 1000)
                                Color.blue.frame(height: 100).id("bottom")
                            }
                        }
                        .frame(height: 100)
                    }
                }
            }
        }
        let graph = layout(Reader(), width: 200, height: 200)
        graph.tapText("Jump")
        #expect(graph.hasActiveAnimations)
        graph.advance(to: 0.5)
        let state = try #require(graph.scrollState(at: CGPoint(x: 100, y: 100), delta: CGSize(width: 0, height: -1)))
        #expect(state.offset.y == 500)
        graph.advance(to: 1)
        #expect(state.offset.y == 1000)
        #expect(!graph.hasActiveAnimations)
    }
}
