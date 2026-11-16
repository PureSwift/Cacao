import Foundation
#if canImport(CoreGraphics)
import CoreGraphics
#endif
import Testing
@testable import Cacao

@MainActor
@Suite struct LazyTests {

    struct Rows: View {
        var count = 10_000
        var body: some View {
            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(0..<count, id: \.self) { index in
                        Color.gray.frame(height: 40).probe("row \(index)")
                    }
                }
            }
            .frame(width: 300, height: 400)
        }
    }

    /// The nodes in the graph.
    func nodeCount(_ graph: ViewGraph) -> Int {
        var count = 0
        graph.root.forEachNode { _ in count += 1 }
        return count
    }

    /// Runs updates and layouts until the graph settles, as a host does
    /// across frames.
    func settle(_ graph: ViewGraph) {
        var passes = 0
        repeat {
            graph.layout(in: CGSize(width: 300, height: 400))
            passes += 1
        } while graph.needsUpdate && passes < 10
    }

    @Test func createsOnlyVisibleRows() {
        let graph = ViewGraph(rootView: Rows())
        settle(graph)
        #expect(graph.frame(forIdentifier: "row 0") == rect(0, 0, 300, 40))
        #expect(graph.frame(forIdentifier: "row 9") != nil)
        #expect(graph.frame(forIdentifier: "row 200") == nil)
        #expect(nodeCount(graph) < 400)
    }

    @Test func contentSizeCoversAllRows() throws {
        let graph = ViewGraph(rootView: Rows())
        settle(graph)
        let state = try #require(graph.scrollState(at: CGPoint(x: 150, y: 200), delta: CGSize(width: 0, height: 10)))
        #expect(state.contentSize.height == 400_000)
    }

    @Test func scrollingCreatesRowsComingIntoView() {
        let graph = ViewGraph(rootView: Rows())
        settle(graph)
        graph.scroll(by: CGSize(width: 0, height: 200_000), at: CGPoint(x: 150, y: 200))
        #expect(graph.needsUpdate)
        settle(graph)
        // Row 5000 starts at 200,000, the top of the viewport.
        #expect(graph.frame(forIdentifier: "row 5000") == rect(0, 200_000, 300, 40))
        #expect(graph.frame(forIdentifier: "row 0") == nil)
        #expect(nodeCount(graph) < 400)
    }

    @Test func scrollingWithinCreatedRowsDoesNotUpdate() {
        let graph = ViewGraph(rootView: Rows())
        settle(graph)
        let before = graph.statistics.resolves
        graph.scroll(by: CGSize(width: 0, height: 20), at: CGPoint(x: 150, y: 200))
        #expect(!graph.needsUpdate)
        #expect(graph.statistics.resolves == before)
    }

    @Test func rowStatePersistsWhileCreated() {
        struct Row: View {
            let index: Int
            @State var taps = 0
            var body: some View {
                Text("\(index):\(taps)").onAppear { Row.bindings[index] = $taps }
            }
            nonisolated(unsafe) static var bindings: [Int: Binding<Int>] = [:]
        }
        struct Root: View {
            var body: some View {
                ScrollView {
                    LazyVStack {
                        ForEach(0..<100, id: \.self) { Row(index: $0) }
                    }
                }
            }
        }
        Row.bindings = [:]
        let graph = ViewGraph(rootView: Root())
        settle(graph)
        Row.bindings[1]?.wrappedValue = 3
        settle(graph)
        #expect(graph.texts.contains("1:3"))
    }

    @Test func listRowsAreLazyAndSelectable() {
        struct Root: View {
            @State var selection: Int?
            var body: some View {
                List(0..<10_000, id: \.self, selection: $selection) { index in
                    Text("Item \(index)")
                }
                .overlay(alignment: .bottom) { Text("Selected \(selection.map(String.init) ?? "none")") }
            }
        }
        let graph = ViewGraph(rootView: Root())
        settle(graph)
        #expect(nodeCount(graph) < 600)
        #expect(graph.texts.last == "Selected none")
        // Tap the second row.
        let second = graph.texts.firstIndex(of: "Item 1")
        #expect(second != nil)
        graph.pointer(.began, at: CGPoint(x: 100, y: 60))
        graph.pointer(.ended, at: CGPoint(x: 100, y: 60))
        settle(graph)
        #expect(graph.texts.last == "Selected 1")
    }
}
