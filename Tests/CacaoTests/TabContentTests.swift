import CacaoRender
import Foundation
#if canImport(CoreGraphics)
import CoreGraphics
#endif
import Testing
@testable import Cacao

@MainActor
@Suite struct TabContentTests {

    enum Page: Hashable {
        case home
        case search
        case library(Int)
    }

    /// Tabs whose values are inferred from the tab view's selection, with a
    /// section of tabs from a `ForEach`.
    struct Root: View {
        @State var selection: Page = .home
        var body: some View {
            TabView(selection: $selection) {
                Tab("Home", systemImage: "house", value: .home) {
                    Text("Home page")
                }
                Tab(value: .search, role: .search) {
                    Text("Search page")
                }
                TabSection("Library") {
                    ForEach(0..<2, id: \.self) { index in
                        Tab("Shelf \(index)", value: Page.library(index)) {
                            Text("Shelf page \(index)")
                        }
                    }
                }
            }
            .tabViewStyle(.sidebarAdaptable)
        }
    }

    @Test func tabsTakeTheirValuesTypeFromTheSelection() {
        let graph = layout(Root(), width: 600, height: 400)
        graph.settle()
        // Every tab is in the bar, a section's among the others.
        for title in ["Home", "Search", "Shelf 0", "Shelf 1"] {
            #expect(graph.texts.contains(title))
        }
        #expect(graph.texts.contains("Home page"))
        #expect(!graph.texts.contains("Shelf page 1"))
    }

    @Test func choosingATabOfASectionShowsItsPage() {
        let graph = layout(Root(), width: 600, height: 400)
        graph.settle()
        graph.tapText("Shelf 1")
        graph.settle()
        #expect(graph.texts.contains("Shelf page 1"))
        #expect(!graph.texts.contains("Home page"))
        graph.tapText("Search")
        graph.settle()
        #expect(graph.texts.contains("Search page"))
    }

    /// The scroll view's effect in what the graph draws.
    private func scrollEffect(_ graph: ViewGraph) -> ScrollEffect? {
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

    @Test func scrollViewsClipUnlessToldNotTo() throws {
        let rows = ScrollView { Color.blue.frame(height: 900) }
        #expect(try #require(scrollEffect(layout(rows))).isClipDisabled == false)
        #expect(try #require(scrollEffect(layout(rows.scrollClipDisabled()))).isClipDisabled)
        #expect(try #require(scrollEffect(layout(rows.scrollClipDisabled(false)))).isClipDisabled == false)
    }

    @Test func searchSuggestionsLeaveAViewAsItIs() {
        let view = Text("Results")
            .searchSuggestions { Text("Suggestion").searchCompletion("suggestion") }
        #expect(layout(view).texts == ["Results"])
    }

    @Test func aViewIsToldWhenItScrollsOutOfViewAndBack() {
        let log = Box<[Bool]>([])
        let graph = layout(
            ScrollView {
                VStack(spacing: 0) {
                    Color.red.frame(height: 100)
                        .onScrollVisibilityChange { log.value.append($0) }
                    Color.blue.frame(height: 900)
                }
            },
            width: 300, height: 400
        )
        graph.settle()
        #expect(log.value == [true])
        let point = CGPoint(x: 150, y: 200)
        // Less than half of it left in view.
        graph.scroll(by: CGSize(width: 0, height: 60), at: point)
        #expect(log.value == [true, false])
        graph.scroll(by: CGSize(width: 0, height: -60), at: point)
        #expect(log.value == [true, false, true])
    }

    @Test func borderedButtonsTakeABorderShape() {
        let graph = layout(Button("Play") { }.buttonStyle(.bordered).buttonBorderShape(.capsule))
        #expect(graph.texts == ["Play"])
    }

    @Test func cardButtonsShowTheirLabelAndAct() {
        let taps = Box(0)
        let graph = layout(Button("Poster") { taps.value += 1 }.buttonStyle(.card))
        #expect(graph.texts == ["Poster"])
        graph.tapText("Poster")
        #expect(taps.value == 1)
    }

    @Test func styledTextsJoinIntoOne() {
        let joined = Text("Starring").foregroundStyle(.secondary) + Text(" Someone").foregroundStyle(Color.red)
        #expect(joined.runs.count == 2)
        #expect(joined.runs[0].color == .secondary)
        #expect(joined.runs[1].color == .red)
        #expect(layout(joined).texts == ["Starring Someone"])
    }

    @Test func hoverEffectsLeaveAViewAsItIs() {
        #expect(layout(Text("Card").hoverEffect(.highlight)).texts == ["Card"])
    }
}
