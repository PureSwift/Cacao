import Foundation
#if canImport(CoreGraphics)
import CoreGraphics
#endif
import Observation
import Testing
@testable import Cacao

@MainActor
extension ViewGraph {

    /// Taps the center of the text with the given string, after laying out.
    func tapText(_ string: String, sourceLocation: SourceLocation = #_sourceLocation) {
        update()
        layout(in: size)
        guard let frame = textFrames[string] else {
            Issue.record("No text \(string): \(texts)", sourceLocation: sourceLocation)
            return
        }
        tap(at: CGPoint(x: frame.midX, y: frame.midY))
        update()
        layout(in: size)
    }

    /// Settles, then lets running animations and transitions finish.
    func finish() {
        settle()
        advance(to: time + 10)
    }

    /// Updates and lays out until nothing changes.
    func settle() {
        var passes = 0
        repeat {
            update()
            layout(in: size)
            passes += 1
        } while needsUpdate && passes < 10
    }
}

@MainActor
@Suite struct NavigationTests {

    struct Item: Hashable {
        let name: String
    }

    struct Root: View {
        var body: some View {
            NavigationStack {
                VStack {
                    NavigationLink("Apple", value: Item(name: "Apple"))
                    NavigationLink("Settings") { Text("Settings screen").navigationTitle("Settings") }
                }
                .navigationTitle("Fruits")
                .navigationDestination(for: Item.self) { item in
                    Text("Detail of \(item.name)")
                        .navigationTitle(item.name)
                        .toolbar {
                            ToolbarItem(placement: .primaryAction) {
                                Button("Edit") { }
                            }
                        }
                }
            }
        }
    }

    @Test func titleShowsInBar() {
        let graph = layout(Root(), width: 400, height: 500)
        graph.settle()
        #expect(graph.texts.contains("Fruits"))
    }

    @Test func linkPushesValueDestination() {
        let graph = layout(Root(), width: 400, height: 500)
        graph.settle()
        graph.tapText("Apple")
        graph.finish()
        #expect(graph.texts.contains("Detail of Apple"))
        // The bar shows the new title, a back button titled with the
        // previous screen's, and the toolbar item.
        #expect(graph.texts.contains("Apple"))
        #expect(graph.texts.contains("Fruits"))
        #expect(graph.texts.contains("Edit"))
        // Only the top screen draws.
        #expect(!graph.texts.contains("Settings"))
        graph.tapText("Fruits")
        graph.finish()
        #expect(!graph.texts.contains("Detail of Apple"))
        #expect(graph.texts.contains("Settings"))
    }

    @Test func linkPushesDestinationView() {
        let graph = layout(Root(), width: 400, height: 500)
        graph.settle()
        graph.tapText("Settings")
        graph.settle()
        #expect(graph.texts.contains("Settings screen"))
    }

    @Test func pathBindingDrivesStack() {
        struct Bound: View {
            @State var path: [Int] = []
            var body: some View {
                NavigationStack(path: $path) {
                    Button("Push two") { path = [1, 2] }
                        .navigationDestination(for: Int.self) { Text("Screen \($0)") }
                }
            }
        }
        let graph = layout(Bound(), width: 400, height: 500)
        graph.settle()
        graph.tapText("Push two")
        graph.finish()
        #expect(graph.texts.contains("Screen 2"))
        #expect(!graph.texts.contains("Screen 1"))
        graph.tapText("Back")
        graph.settle()
        #expect(graph.texts.contains("Screen 1"))
    }

    @Test func searchableInBar() {
        struct Searching: View {
            @State var query = ""
            var body: some View {
                NavigationStack {
                    Text(query.isEmpty ? "All" : "Results for \(query)")
                        .navigationTitle("Search")
                        .searchable(text: $query)
                }
            }
        }
        let graph = layout(Searching(), width: 400, height: 500)
        graph.settle()
        graph.tapText("Search")
        graph.settle()
        // The search field is under the title.
        let field = graph.texts.filter { $0 == "Search" }
        #expect(field.count == 2)
        graph.keyDown(.tab)
        graph.insertText("kiwi")
        graph.settle()
        #expect(graph.texts.contains("Results for kiwi"))
    }

    @Test func splitViewShowsSidebarSelectionInDetail() {
        struct Split: View {
            var body: some View {
                NavigationSplitView {
                    List {
                        NavigationLink("Apple", value: Item(name: "Apple"))
                        NavigationLink("Pear", value: Item(name: "Pear"))
                    }
                    .navigationTitle("Fruits")
                    .navigationDestination(for: Item.self) { Text("Detail of \($0.name)") }
                } detail: {
                    Text("Pick a fruit")
                }
            }
        }
        let graph = layout(Split(), width: 700, height: 500)
        graph.settle()
        #expect(graph.texts.contains("Pick a fruit"))
        graph.tapText("Pear")
        graph.settle()
        #expect(graph.texts.contains("Detail of Pear"))
        graph.tapText("Apple")
        graph.finish()
        #expect(graph.texts.contains("Detail of Apple"))
        #expect(!graph.texts.contains("Detail of Pear"))
        #expect(!graph.texts.contains("Back"))
    }

    @Test func splitViewColumnWidthsAndVisibility() {
        struct Split: View {
            @Bindable var model: SplitModel
            var body: some View {
                NavigationSplitView(columnVisibility: $model.visibility) {
                    Color.red.accessibilityIdentifier("sidebar")
                        .navigationSplitViewColumnWidth(min: 100, ideal: 150, max: 300)
                } content: {
                    Color.green.accessibilityIdentifier("content")
                        .navigationSplitViewColumnWidth(200)
                } detail: {
                    Color.blue.accessibilityIdentifier("detail")
                }
            }
        }
        let model = SplitModel()
        let graph = layout(Split(model: model), width: 800, height: 400)
        graph.settle()
        var frames = graph.identifiedFrames()
        #expect(frames["sidebar"]?.minX == 0)
        #expect(frames["sidebar"]?.width == 150)
        #expect(frames["content"]?.minX == 151)
        #expect(frames["content"]?.width == 200)
        #expect(frames["detail"]?.minX == 352)
        #expect(frames["detail"]?.maxX == 800)

        model.visibility = .doubleColumn
        graph.settle()
        frames = graph.identifiedFrames()
        #expect(frames["content"]?.minX == 0)
        #expect(frames["detail"]?.minX == 201)
        #expect(!graph.colorItems.contains { $0.color == Color.red.resolve(in: EnvironmentValues()) })

        model.visibility = .detailOnly
        graph.settle()
        frames = graph.identifiedFrames()
        #expect(frames["detail"] == CGRect(x: 0, y: 0, width: 800, height: 400))
        #expect(graph.colorItems.count == 1)
    }

    // MARK: Tabs

    @Test func tabsSwitchAndKeepState() {
        struct Tabs: View {
            var body: some View {
                TabView {
                    Counter().tabItem { Text("Count") }.tag(0)
                    Text("Second page").tabItem { Text("Other") }.tag(1)
                }
            }
        }
        struct Counter: View {
            @State var count = 0
            var body: some View {
                Button("Count \(count)") { count += 1 }
            }
        }
        let graph = layout(Tabs(), width: 400, height: 400)
        graph.settle()
        graph.tapText("Count 0")
        graph.settle()
        #expect(graph.texts.contains("Count 1"))
        graph.tapText("Other")
        graph.settle()
        #expect(graph.texts.contains("Second page"))
        #expect(!graph.texts.contains("Count 1"))
        graph.tapText("Count")
        graph.settle()
        #expect(graph.texts.contains("Count 1"))
    }

    @Test func tabStructWithSelection() {
        struct Tabs: View {
            @State var selection = "b"
            var body: some View {
                TabView(selection: $selection) {
                    Tab("First", value: "a") { Text("Page A") }
                    Tab("Second", value: "b") { Text("Page B") }
                }
            }
        }
        let graph = layout(Tabs(), width: 400, height: 400)
        graph.settle()
        #expect(graph.texts.contains("Page B"))
        graph.tapText("First")
        graph.settle()
        #expect(graph.texts.contains("Page A"))
    }
}

@MainActor
@Suite struct PresentationTests {

    @Test func sheetPresentsAndDismisses() {
        struct Sheet: View {
            @Environment(\.dismiss) var dismiss
            var body: some View {
                VStack {
                    Text("In the sheet")
                    Button("Done") { dismiss() }
                }
            }
        }
        struct Root: View {
            @State var isPresented = false
            var body: some View {
                Button("Show") { isPresented = true }
                    .sheet(isPresented: $isPresented) { Sheet() }
            }
        }
        let graph = layout(Root(), width: 600, height: 600)
        graph.tapText("Show")
        graph.settle()
        #expect(graph.texts.contains("In the sheet"))
        #expect(graph.isPresenting)
        // The backdrop blocks the content below.
        graph.tap(at: CGPoint(x: 5, y: 5))
        graph.settle()
        #expect(graph.isPresenting)
        graph.tapText("Done")
        graph.finish()
        #expect(!graph.isPresenting)
        #expect(!graph.texts.contains("In the sheet"))
    }

    @Test func alertActionsRunAndDismiss() {
        final class Log { var events: [String] = [] }
        struct Root: View {
            let log: Log
            @State var isPresented = false
            var body: some View {
                Button("Delete") { isPresented = true }
                    .alert("Delete file?", isPresented: $isPresented) {
                        Button("Cancel", role: .cancel) { log.events.append("cancel") }
                        Button("Delete", role: .destructive) { log.events.append("delete") }
                    } message: {
                        Text("This can't be undone.")
                    }
            }
        }
        let log = Log()
        let graph = layout(Root(log: log), width: 600, height: 600)
        graph.tapText("Delete")
        graph.settle()
        #expect(graph.texts.contains("Delete file?"))
        #expect(graph.texts.contains("This can't be undone."))
        graph.tapText("Cancel")
        graph.settle()
        #expect(log.events == ["cancel"])
        #expect(!graph.isPresenting)
    }

    @Test func escapeDismissesTopPresentation() {
        struct Root: View {
            @State var isPresented = false
            var body: some View {
                Button("Ask") { isPresented = true }
                    .confirmationDialog("Choose", isPresented: $isPresented) {
                        Button("One") { }
                        Button("Two") { }
                    }
            }
        }
        let graph = layout(Root(), width: 600, height: 600)
        graph.tapText("Ask")
        graph.settle()
        #expect(graph.texts.contains("Two"))
        graph.keyDown(.escape)
        graph.settle()
        #expect(!graph.isPresenting)
    }

    @Test func popoverAnchorsToItsView() {
        struct Root: View {
            @State var isPresented = false
            var body: some View {
                Button("Info") { isPresented = true }
                    .popover(isPresented: $isPresented) { Text("Popover text") }
            }
        }
        let graph = layout(Root(), width: 600, height: 600)
        graph.tapText("Info")
        graph.settle()
        let info = graph.textFrames["Info"] ?? .zero
        let popover = graph.textFrames["Popover text"] ?? .zero
        #expect(popover.minY > info.maxY)
        // A tap outside dismisses it.
        graph.tap(at: CGPoint(x: 5, y: 5))
        graph.settle()
        #expect(!graph.isPresenting)
    }

    @Test func contextMenuOnSecondaryClick() {
        final class Log { var events: [String] = [] }
        let log = Log()
        let graph = layout(
            Text("File")
                .contextMenu {
                    Button("Open") { log.events.append("open") }
                    Button("Rename") { log.events.append("rename") }
                }
                .probe("file"),
            width: 400, height: 400
        )
        let file = graph.frame("file")
        #expect(graph.secondaryClick(at: CGPoint(x: file.midX, y: file.midY)))
        graph.settle()
        graph.tapText("Rename")
        graph.settle()
        #expect(log.events == ["rename"])
        #expect(!graph.isPresenting)
    }

    @Test func presentationLeavesWithItsPresenter() {
        struct Root: View {
            @State var show = true
            @State var isPresented = true
            var body: some View {
                VStack {
                    Button("Hide") { show = false }
                    if show {
                        Text("Presenter").sheet(isPresented: $isPresented) { Text("Sheet") }
                    }
                }
            }
        }
        let graph = layout(Root(), width: 600, height: 600)
        graph.settle()
        #expect(graph.isPresenting)
        // Tap the button through the sheet's backdrop: dismiss the sheet first.
        graph.dismissTopPresentation()
        graph.settle()
        #expect(!graph.isPresenting)
    }
}

@MainActor
@Suite struct ContainerTests {

    @Test func formGroupsSections() {
        let graph = layout(
            Form {
                Section("Account") {
                    Text("Name")
                    Text("Email")
                }
                Section {
                    Text("Notifications")
                } footer: {
                    Text("Alerts for new messages.")
                }
            },
            width: 400, height: 500
        )
        #expect(graph.texts == ["Account", "Name", "Email", "Notifications", "Alerts for new messages."])
        let name = graph.textFrames["Name"] ?? .zero
        let email = graph.textFrames["Email"] ?? .zero
        #expect(email.minY > name.maxY)
    }

    @Test func listSectionsAreLazy() {
        let graph = layout(
            List {
                ForEach(0..<50, id: \.self) { section in
                    Section("Section \(section)") {
                        ForEach(0..<100, id: \.self) { row in
                            Text("Row \(section).\(row)")
                        }
                    }
                }
            },
            width: 400, height: 600
        )
        graph.settle()
        #expect(graph.texts.first == "Section 0")
        #expect(graph.texts.contains("Row 0.0"))
        #expect(!graph.texts.contains("Section 1"))
    }

    @Test func gridColumnsFitWidestCell() {
        let graph = layout(
            Grid(horizontalSpacing: 10, verticalSpacing: 4) {
                GridRow {
                    Color.red.frame(width: 30, height: 20).probe("a")
                    Color.blue.frame(width: 50, height: 20).probe("b")
                }
                GridRow {
                    Color.green.frame(width: 60, height: 10).probe("c")
                    Color.yellow.frame(width: 20, height: 10).probe("d")
                }
            }
            .probe("grid"),
            width: 300, height: 300
        )
        // Columns 60 and 50 wide, rows 20 and 10 tall.
        #expect(graph.frame("grid").size == CGSize(width: 120, height: 34))
        let grid = graph.frame("grid")
        #expect(graph.frame("b").minX == grid.minX + 70)
        #expect(graph.frame("d").minX == grid.minX + 70 + 15)
        #expect(graph.frame("c").minY == grid.minY + 24)
    }

    @Test func adaptiveGridFitsColumns() {
        let graph = layout(
            ScrollView {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 90))], spacing: 10) {
                    ForEach(0..<1000, id: \.self) { index in
                        Color.gray.frame(height: 50).probe("cell \(index)")
                    }
                }
            },
            width: 400, height: 300
        )
        graph.settle()
        // (400 + 8) / (90 + 8) = 4 columns of (400 - 24) / 4 = 94 points.
        #expect(graph.frame("cell 0").width == 94)
        #expect(abs(graph.frame("cell 3").minX - 306) < 0.01)
        #expect(graph.frame("cell 4").minY == 60)
        #expect(graph.frame(forIdentifier: "cell 900") == nil)
    }
}

@MainActor
@Suite struct NavigationAnimationTests {

    @Test func pushSlidesInOverThePreviousScreen() {
        struct Stack: View {
            @State var path: [Int] = []
            var body: some View {
                NavigationStack(path: $path) {
                    Button("Push") { path = [1] }
                        .navigationDestination(for: Int.self) { Text("Screen \($0)") }
                }
            }
        }
        let graph = layout(Stack(), width: 400, height: 500)
        graph.settle()
        graph.tapText("Push")
        graph.settle()
        // Both screens draw while the new one slides in from the trailing edge.
        #expect(graph.texts.contains("Push"))
        #expect(graph.texts.contains("Screen 1"))
        #expect(graph.hasActiveAnimations)
        graph.advance(to: graph.time + 0.1)
        let offset = graph.drawnItems.first { drawn in
            if case let .content(.text(text)) = drawn.item.value { return text.string == "Screen 1" }
            return false
        }?.transforms.first?.tx ?? 0
        #expect(offset > 0 && offset < 400)
        graph.advance(to: graph.time + 2)
        #expect(!graph.texts.contains("Push"))
        #expect(!graph.hasActiveAnimations)
    }

    @Test func disabledAnimationsPushInstantly() {
        struct Stack: View {
            @State var path: [Int] = []
            var body: some View {
                NavigationStack(path: $path) {
                    Button("Push") {
                        var transaction = Transaction()
                        transaction.disablesAnimations = true
                        withTransaction(transaction) { path = [1] }
                    }
                    .navigationDestination(for: Int.self) { Text("Screen \($0)") }
                }
            }
        }
        let graph = layout(Stack(), width: 400, height: 500)
        graph.settle()
        graph.tapText("Push")
        graph.settle()
        #expect(!graph.texts.contains("Push"))
        #expect(!graph.hasActiveAnimations)
    }

    @Test func sheetSlidesUp() {
        struct Root: View {
            @State var isPresented = false
            var body: some View {
                Button("Show") { isPresented = true }
                    .sheet(isPresented: $isPresented) { Text("Sheet") }
            }
        }
        let graph = layout(Root(), width: 400, height: 400)
        graph.tapText("Show")
        graph.settle()
        #expect(graph.hasActiveAnimations)
        graph.advance(to: graph.time + 0.05)
        let offset = graph.drawnItems.first { drawn in
            if case let .content(.text(text)) = drawn.item.value { return text.string == "Sheet" }
            return false
        }?.transforms.first?.ty ?? 0
        #expect(offset > 0)
    }
}

@Observable
final class SplitModel {
    var visibility = NavigationSplitViewVisibility.all
}
