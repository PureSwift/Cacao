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
}

@MainActor
@Suite struct TabViewStyleTests {

    private func make(compact: Bool) -> ViewGraph {
        let size = CGSize(width: compact ? 360 : 900, height: 500)
        let graph = ViewGraph(rootView: TabContentTests.Root(), textEngine: FixedTextEngine())
        graph.applySizeClasses(for: size)
        graph.update()
        graph.layout(in: size)
        graph.settle()
        return graph
    }

    @Test func aSidebarAdaptableTabViewShowsASidebarWhereThereIsRoom() throws {
        let graph = make(compact: false)
        let frames = graph.textFrames
        // The tabs in a column, beside the page, with the section's title.
        let home = try #require(frames["Home"]), search = try #require(frames["Search"])
        let page = try #require(frames["Home page"])
        #expect(search.minY > home.maxY)
        #expect(page.minX > home.maxX)
        let title = try #require(frames["Library"]), shelf = try #require(frames["Shelf 0"])
        #expect(title.maxY <= shelf.minY)
        #expect(title.minY > search.maxY)
    }

    @Test func aSidebarAdaptableTabViewShowsATabBarInACompactWidth() throws {
        let graph = make(compact: true)
        let frames = graph.textFrames
        // The tabs in a row, above the page; a section has no title there.
        let home = try #require(frames["Home"]), search = try #require(frames["Search"])
        #expect(search.minX > home.maxX)
        #expect(try #require(frames["Home page"]).minY > home.maxY)
        #expect(frames["Library"] == nil)
    }

    @Test func moreTabsThanFitKeepTheirLabelsOnALine() throws {
        struct Many: View {
            @State var selection = 0
            var body: some View {
                TabView(selection: $selection) {
                    ForEach(0..<12, id: \.self) { index in
                        Tab("Long tab title \(index)", value: index) { Text("Page \(index)") }
                    }
                }
            }
        }
        let graph = layout(Many(), width: 300, height: 400)
        graph.settle()
        // One line each, in a bar that scrolls: not squeezed to wrap.
        let first = try #require(graph.textFrames["Long tab title 0"])
        let page = try #require(graph.textFrames["Page 0"])
        #expect(first.height < 30)
        // The bar is as tall as a line of tabs, with the page below it.
        #expect(first.maxY < 60)
        #expect(page.minY > first.maxY)
    }

    @Test func otherStylesShowATabBar() throws {
        struct Bar: View {
            @State var selection = 0
            var body: some View {
                TabView(selection: $selection) {
                    Tab("One", value: 0) { Text("Page one") }
                    Tab("Two", value: 1) { Text("Page two") }
                }
                .tabViewStyle(.tabBarOnly)
            }
        }
        let graph = layout(Bar(), width: 900, height: 500)
        graph.settle()
        let frames = graph.textFrames
        #expect(try #require(frames["Two"]).minX > (try #require(frames["One"])).maxX)
    }
}

@MainActor
@Suite struct HoverEffectTests {

    /// The shapes drawn, which is what a hover effect adds.
    private func shapes(_ graph: ViewGraph) -> Int {
        graph.drawnItems.filter { drawn in
            if case .content(.text) = drawn.item.value { return false }
            return true
        }.count
    }

    @Test func aHighlightShowsWhileThePointerIsOverTheView() throws {
        let graph = layout(Text("Card").hoverEffect(.highlight), width: 300, height: 200)
        graph.settle()
        #expect(shapes(graph) == 0)
        let frame = try #require(graph.textFrames["Card"])
        graph.hover(at: CGPoint(x: frame.midX, y: frame.midY))
        graph.finish()
        #expect(shapes(graph) == 1)
        graph.hover(at: nil)
        graph.finish()
        #expect(shapes(graph) == 0)
    }

    @Test func aDisabledEffectShowsNothing() throws {
        let graph = layout(Text("Card").hoverEffect(.highlight, isEnabled: false), width: 300, height: 200)
        graph.settle()
        let frame = try #require(graph.textFrames["Card"])
        graph.hover(at: CGPoint(x: frame.midX, y: frame.midY))
        graph.finish()
        #expect(shapes(graph) == 0)
    }
}

@MainActor
@Suite struct DirectionalFocusTests {

    /// A focusable label that says when it has focus.
    struct Item: View {
        let name: String
        var body: some View {
            Label(name: name).focusable()
        }
        struct Label: View {
            let name: String
            @Environment(\.isFocused) var isFocused
            var body: some View {
                Text(isFocused ? "\(name) focused" : name).frame(width: 100, height: 40)
            }
        }
    }

    /// Two items side by side, and below them a third that's off to the
    /// right of both, in a row as wide as the window.
    struct Shelves: View {
        let hasSection: Bool
        var body: some View {
            VStack(spacing: 20) {
                HStack(spacing: 20) {
                    Item(name: "A")
                    Item(name: "B")
                }
                if hasSection {
                    row.focusSection()
                } else {
                    row
                }
            }
        }
        var row: some View {
            HStack(spacing: 0) {
                Color.clear.frame(width: 450, height: 40)
                Item(name: "C")
            }
        }
    }

    @Test func arrowKeysMoveFocusToTheNearestViewThatWay() {
        let graph = layout(Shelves(hasSection: false), width: 600, height: 300)
        graph.settle()
        graph.tapText("A")
        graph.settle()
        #expect(graph.texts.contains("A focused"))
        #expect(graph.keyDown(.right))
        graph.settle()
        #expect(graph.texts.contains("B focused"))
        #expect(graph.keyDown(.left))
        graph.settle()
        #expect(graph.texts.contains("A focused"))
        // Nothing is below it, in line with it.
        #expect(!graph.keyDown(.down))
        graph.settle()
        #expect(graph.texts.contains("A focused"))
    }

    @Test func aFocusSectionTakesFocusForAViewThatIsNotInLine() {
        let graph = layout(Shelves(hasSection: true), width: 600, height: 300)
        graph.settle()
        graph.tapText("A")
        graph.settle()
        #expect(graph.keyDown(.down))
        graph.settle()
        #expect(graph.texts.contains("C focused"))
    }
}

@MainActor
@Suite struct SearchSuggestionTests {

    struct Search: View {
        @State var text = "ap"
        var body: some View {
            Text("Results for \(text)")
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .searchable(text: $text)
                .searchSuggestions {
                    ForEach(["apple", "apricot"].filter { $0.hasPrefix(text) }, id: \.self) { fruit in
                        Text(fruit).searchCompletion(fruit)
                    }
                    Text("No completion")
                }
        }
    }

    @Test func suggestionsAreListedUnderTheSearchField() {
        let graph = layout(Search(), width: 400, height: 400)
        graph.settle()
        #expect(graph.texts.contains("apple"))
        #expect(graph.texts.contains("apricot"))
        #expect(graph.texts.contains("Results for ap"))
    }

    @Test func choosingASuggestionCompletesTheSearch() {
        let graph = layout(Search(), width: 400, height: 400)
        graph.settle()
        graph.tapText("apricot")
        graph.settle()
        #expect(graph.texts.contains("Results for apricot"))
        // The list goes once a suggestion is chosen.
        #expect(!graph.texts.contains("No completion"))
    }

    @Test func aSuggestionWithoutACompletionIsNotAButton() {
        let graph = layout(Search(), width: 400, height: 400)
        graph.settle()
        graph.tapText("No completion")
        graph.settle()
        #expect(graph.texts.contains("Results for ap"))
        #expect(graph.texts.contains("apple"))
    }
}
