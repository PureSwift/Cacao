import CacaoRender
import Foundation
#if canImport(CoreGraphics)
import CoreGraphics
#endif
import Testing
@testable import Cacao

@MainActor
@Suite struct ScrollIndicatorTests {

    /// Two thousand points of rows in a window 400 points tall.
    private func rows() -> some View {
        ScrollView {
            VStack(spacing: 0) {
                ForEach(0..<50, id: \.self) { _ in
                    Color.blue.frame(height: 40)
                }
            }
        }
    }

    /// The scroll view's effect in what the graph draws.
    private func effect(_ graph: ViewGraph) -> ScrollEffect? {
        func find(_ list: DisplayList) -> ScrollEffect? {
            for item in list.items {
                guard case let .effect(effect, nested) = item.value else { continue }
                if case let .scroll(scroll) = effect { return scroll }
                if let found = find(nested) { return found }
            }
            return nil
        }
        return find(graph.displayList())
    }

    private let point = CGPoint(x: 150, y: 200)

    @Test func indicatorsShowWhileScrollingAndFadeAfter() throws {
        let graph = layout(rows(), width: 300, height: 400)
        graph.settle()
        // Nothing has scrolled yet.
        #expect(try #require(effect(graph)).showsIndicators)
        #expect(try #require(effect(graph)).indicatorOpacity == 0)
        graph.scroll(by: CGSize(width: 0, height: 60), at: point)
        #expect(try #require(effect(graph)).indicatorOpacity == 1)
        // Frames keep coming until they have faded.
        #expect(graph.hasActiveAnimations)
        graph.advance(to: graph.time + ScrollState.indicatorHold - 0.1)
        #expect(try #require(effect(graph)).indicatorOpacity == 1)
        graph.advance(to: graph.time + 0.1 + ScrollState.indicatorFade / 2)
        let fading = try #require(effect(graph)).indicatorOpacity
        #expect(fading > 0 && fading < 1)
        graph.advance(to: graph.time + 1)
        #expect(try #require(effect(graph)).indicatorOpacity == 0)
        #expect(!graph.hasActiveAnimations)
    }

    @Test func scrollingAgainShowsThemAgain() throws {
        let graph = layout(rows(), width: 300, height: 400)
        graph.settle()
        graph.scroll(by: CGSize(width: 0, height: 60), at: point)
        graph.advance(to: graph.time + 5)
        #expect(try #require(effect(graph)).indicatorOpacity == 0)
        graph.scroll(by: CGSize(width: 0, height: 60), at: point)
        #expect(try #require(effect(graph)).indicatorOpacity == 1)
    }

    @Test func visibleIndicatorsStay() throws {
        let graph = layout(rows().scrollIndicators(.visible), width: 300, height: 400)
        graph.settle()
        #expect(try #require(effect(graph)).showsIndicators)
        #expect(try #require(effect(graph)).indicatorOpacity == 1)
        graph.scroll(by: CGSize(width: 0, height: 60), at: point)
        graph.advance(to: graph.time + 5)
        #expect(try #require(effect(graph)).indicatorOpacity == 1)
        // Nothing to fade, so nothing to keep drawing for.
        #expect(!graph.hasActiveAnimations)
    }

    @Test func hiddenIndicatorsNeverShow() throws {
        let graph = layout(rows().scrollIndicators(.hidden), width: 300, height: 400)
        graph.settle()
        graph.scroll(by: CGSize(width: 0, height: 60), at: point)
        #expect(try #require(effect(graph)).showsIndicators == false)
        #expect(!graph.hasActiveAnimations)
    }
}
