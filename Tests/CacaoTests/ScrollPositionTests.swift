import Foundation
#if canImport(CoreGraphics)
import CoreGraphics
#endif
import Observation
import Testing
@testable import Cacao

@Observable
final class ScrollModel {
    var rows = 20
    var position: Int?
}

@MainActor
@Suite struct ScrollPositionTests {

    /// The scroll state of the first scroll view.
    func scrollState(_ graph: ViewGraph) throws -> ScrollState {
        let node = try #require(graph.root.firstNode { $0.behavior is ScrollBehavior })
        return (node.behavior as! ScrollBehavior).state(of: node)
    }

    @Test func defaultAnchorStartsAndStaysAtTheBottom() throws {
        struct Log: View {
            let model: ScrollModel
            var body: some View {
                ScrollView {
                    VStack(spacing: 0) {
                        ForEach(0..<model.rows, id: \.self) { index in
                            Color.blue.frame(height: 50).probe("row \(index)")
                        }
                    }
                }
                .defaultScrollAnchor(.bottom)
            }
        }
        let model = ScrollModel()
        let graph = layout(Log(model: model), width: 200, height: 200)
        let state = try scrollState(graph)
        #expect(state.offset == CGPoint(x: 0, y: 800))
        // New rows keep the bottom showing.
        model.rows = 22
        graph.settle()
        #expect(state.offset == CGPoint(x: 0, y: 900))
        // Scrolled away from the bottom, it stays where it is.
        graph.scroll(by: CGSize(width: 0, height: -300), at: CGPoint(x: 100, y: 100))
        model.rows = 24
        graph.settle()
        #expect(state.offset == CGPoint(x: 0, y: 600))
    }

    @Test func alignmentAnchorPlacesShortContent() {
        let graph = layout(
            ScrollView {
                Color.red.frame(height: 50).probe("short")
            }
            .defaultScrollAnchor(.bottom, for: .alignment),
            width: 200, height: 200
        )
        #expect(graph.frame("short").minY == 150)
    }

    @Test func scrollPositionFollowsAndMovesTheScrollView() throws {
        struct Rows: View {
            @Bindable var model: ScrollModel
            var body: some View {
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(0..<100, id: \.self) { index in
                            Text("Row \(index)").frame(height: 50)
                        }
                    }
                    .scrollTargetLayout()
                }
                .scrollPosition(id: $model.position)
            }
        }
        let model = ScrollModel()
        let graph = layout(Rows(model: model), width: 200, height: 200)
        let state = try scrollState(graph)
        // Setting the position scrolls its view to the top.
        model.position = 10
        graph.settle()
        #expect(state.offset == CGPoint(x: 0, y: 500))
        // Scrolling reports the view now at the top.
        graph.scroll(by: CGSize(width: 0, height: 120), at: CGPoint(x: 100, y: 100))
        graph.settle()
        #expect(model.position == 12)
        #expect(state.offset == CGPoint(x: 0, y: 620))
    }
}
