import CacaoRender
import Foundation
#if canImport(CoreGraphics)
import CoreGraphics
#endif
import Testing
@testable import Cacao

@MainActor
@Suite struct SplitViewCollapseTests {

    static let phone = CGSize(width: 360, height: 733)
    static let tablet = CGSize(width: 1000, height: 700)

    /// The strings drawn, and where.
    private func texts(_ graph: ViewGraph) -> [String: CGRect] {
        var found: [String: CGRect] = [:]
        func collect(_ items: [DisplayList.Item]) {
            for item in items {
                switch item.value {
                case let .content(.text(text)): found[text.string] = item.frame
                case .content: break
                case let .effect(_, nested): collect(nested.items)
                }
            }
        }
        collect(graph.displayList().items)
        return found
    }

    private func make(_ view: some View, size: CGSize, variables: [String: String] = [:]) -> ViewGraph {
        let graph = ViewGraph(rootView: view, textEngine: FixedTextEngine())
        graph.applySizeClasses(for: size, environment: variables)
        graph.update()
        graph.layout(in: size)
        settle(graph, size: size)
        return graph
    }

    /// Updates and lays out until nothing changes, then lets transitions end.
    private func settle(_ graph: ViewGraph, size: CGSize) {
        for _ in 0..<6 where graph.needsUpdate {
            graph.update()
            graph.layout(in: size)
        }
        graph.advanceAnimations(to: graph.time + 5)
        for _ in 0..<6 where graph.needsUpdate {
            graph.update()
            graph.layout(in: size)
        }
        graph.layout(in: size)
    }

    private func tap(_ graph: ViewGraph, _ text: String, size: CGSize) {
        guard let frame = texts(graph)[text] else {
            Issue.record("\(text) isn't shown")
            return
        }
        let point = CGPoint(x: frame.midX, y: frame.midY)
        graph.pointer(.began, at: point)
        graph.pointer(.ended, at: point)
        settle(graph, size: size)
    }

    // MARK: Lists in pushed screens

    /// A sidebar of links, and a screen with a list that has a selection.
    private struct PushedList: View {
        @State var selection: Int?
        var body: some View {
            NavigationSplitView {
                List {
                    NavigationLink("Rows", value: "rows")
                }
                .navigationTitle("Catalog")
                .navigationDestination(for: String.self) { _ in
                    List(0..<5, id: \.self, selection: $selection) { index in
                        Text("Row \(index)")
                    }
                    .navigationTitle("Rows")
                }
            } detail: {
                Text("Detail root")
            }
        }
    }

    @Test func selectingARowOfAPushedListStaysOnItsScreen() {
        let graph = make(PushedList(), size: Self.phone)
        // Back from the detail, which shows first, to the sidebar.
        tap(graph, "Catalog", size: Self.phone)
        tap(graph, "Rows", size: Self.phone)
        #expect(texts(graph)["Row 2"] != nil)
        // The row is selected; the split view's detail doesn't take over.
        tap(graph, "Row 2", size: Self.phone)
        #expect(texts(graph)["Row 2"] != nil)
        #expect(texts(graph)["Detail root"] == nil)
    }

    // MARK: Size classes

    @Test func aWindowIsCompactBelowAnIPadsSplitWidth() {
        #expect(SizeClassPolicy.horizontal(width: 360, environment: [:]) == .compact)
        // The widths measured on an iPad: collapsed at 657, split at 739.
        #expect(SizeClassPolicy.horizontal(width: 657, environment: [:]) == .compact)
        #expect(SizeClassPolicy.horizontal(width: 739, environment: [:]) == .regular)
        #expect(SizeClassPolicy.horizontal(width: 678, environment: [:]) == .regular)
        #expect(SizeClassPolicy.vertical(height: 400) == .compact)
        #expect(SizeClassPolicy.vertical(height: 733) == .regular)
    }

    @Test func theThresholdAndTheSizeClassCanBeOverridden() {
        #expect(SizeClassPolicy.horizontal(width: 500, environment: ["CACAO_COMPACT_WIDTH": "400"]) == .regular)
        #expect(SizeClassPolicy.horizontal(width: 900, environment: ["CACAO_COMPACT_WIDTH": "1000"]) == .compact)
        #expect(SizeClassPolicy.horizontal(width: 1400, environment: ["CACAO_SIZE_CLASS": "compact"]) == .compact)
        #expect(SizeClassPolicy.horizontal(width: 300, environment: ["CACAO_SIZE_CLASS": "regular"]) == .regular)
        // Forcing wins over the threshold.
        #expect(SizeClassPolicy.horizontal(width: 900, environment: ["CACAO_SIZE_CLASS": "compact", "CACAO_COMPACT_WIDTH": "100"]) == .compact)
    }

    @Test func viewsReadTheSizeClass() {
        struct Reader: View {
            @Environment(\.horizontalSizeClass) var sizeClass
            var body: some View { Text(sizeClass == .compact ? "compact" : "regular") }
        }
        #expect(texts(make(Reader(), size: Self.phone))["compact"] != nil)
        #expect(texts(make(Reader(), size: Self.tablet))["regular"] != nil)
        #expect(texts(make(Reader(), size: Self.tablet, variables: ["CACAO_SIZE_CLASS": "compact"]))["compact"] != nil)
    }

    // MARK: Links

    /// A catalog, like the demo: links in the sidebar, a first screen in
    /// the detail.
    struct Catalog: View {
        var body: some View {
            NavigationSplitView {
                List {
                    NavigationLink("Controls", value: "Controls")
                    NavigationLink("Shapes", value: "Shapes")
                }
                .navigationTitle("Catalog")
                .navigationDestination(for: String.self) { name in
                    Text("\(name) screen").navigationTitle(name)
                }
            } detail: {
                Text("Welcome screen").navigationTitle("Welcome")
            }
        }
    }

    @Test func aRegularWidthShowsBothColumns() {
        let shown = texts(make(Catalog(), size: Self.tablet))
        #expect(shown["Shapes"] != nil)
        #expect(shown["Welcome screen"] != nil)
        // Side by side.
        if let sidebar = shown["Shapes"], let detail = shown["Welcome screen"] {
            #expect(sidebar.maxX < detail.minX)
        }
    }

    @Test func aCompactWidthShowsTheDetailAloneAboveTheSidebar() {
        let graph = make(Catalog(), size: Self.phone)
        var shown = texts(graph)
        #expect(shown["Welcome screen"] != nil)
        #expect(shown["Shapes"] == nil)
        // The detail has the window's width, not what a sidebar leaves.
        if let detail = shown["Welcome screen"] {
            #expect(detail.midX > 100)
            #expect(detail.midX < 260)
        }
        // Back, to the sidebar.
        tap(graph, "Catalog", size: Self.phone)
        shown = texts(graph)
        #expect(shown["Shapes"] != nil)
        #expect(shown["Welcome screen"] == nil)
        // A link pushes its destination over the sidebar.
        tap(graph, "Shapes", size: Self.phone)
        shown = texts(graph)
        #expect(shown["Shapes screen"] != nil)
        #expect(shown["Controls"] == nil)
    }

    @Test func forcingCompactCollapsesAWideWindow() {
        let shown = texts(make(Catalog(), size: Self.tablet, variables: ["CACAO_SIZE_CLASS": "compact"]))
        #expect(shown["Welcome screen"] != nil)
        #expect(shown["Shapes"] == nil)
    }

    @Test func whatIsShownSurvivesResizing() {
        let graph = make(Catalog(), size: Self.tablet)
        tap(graph, "Shapes", size: Self.tablet)
        #expect(texts(graph)["Shapes screen"] != nil)
        // Narrowed: the screen the detail showed is on top.
        graph.applySizeClasses(for: Self.phone, environment: [:])
        graph.update()
        graph.layout(in: Self.phone)
        settle(graph, size: Self.phone)
        var shown = texts(graph)
        #expect(shown["Shapes screen"] != nil)
        #expect(shown["Controls"] == nil)
        // Widened again: it's back in the detail column, beside the sidebar.
        graph.applySizeClasses(for: Self.tablet, environment: [:])
        graph.update()
        graph.layout(in: Self.tablet)
        settle(graph, size: Self.tablet)
        shown = texts(graph)
        #expect(shown["Shapes screen"] != nil)
        #expect(shown["Controls"] != nil)
    }

    // MARK: Selection

    @MainActor
    final class Model: ObservableObject {
        @Published var selection: String?
    }

    /// Devices, like a list whose selection the detail shows.
    struct Devices: View {
        @ObservedObject var model: Model
        var body: some View {
            NavigationSplitView {
                List(["Lamp", "Sensor"], id: \.self, selection: $model.selection) { name in
                    Text(name)
                }
                .navigationTitle("Devices")
            } detail: {
                Text(model.selection.map { "\($0) details" } ?? "Nothing selected")
            }
        }
    }

    @Test func aSelectionListShowsItsDetailOnlyOnceARowIsSelected() {
        let model = Model()
        let graph = make(Devices(model: model), size: Self.phone)
        var shown = texts(graph)
        // Nothing is selected: the list, not an empty detail.
        #expect(shown["Lamp"] != nil)
        #expect(shown["Nothing selected"] == nil)
        tap(graph, "Sensor", size: Self.phone)
        #expect(model.selection == "Sensor")
        shown = texts(graph)
        #expect(shown["Sensor details"] != nil)
        #expect(shown["Lamp"] == nil)
        // Going back deselects.
        tap(graph, "Devices", size: Self.phone)
        #expect(model.selection == nil)
        shown = texts(graph)
        #expect(shown["Lamp"] != nil)
        #expect(shown["Sensor details"] == nil)
    }
}
