import Foundation
#if canImport(CoreGraphics)
import CoreGraphics
#endif
#if canImport(AppKit)
import AppKit
#endif
import Testing
@testable import Cacao

/// APIs that renderers written for SwiftUI use, like DarwinAppRuntime's.
@MainActor
@Suite struct CompatibilityTests {

    @Test func tabItemsInsideCustomViews() {
        struct Page: View {
            let title: String
            var body: some View {
                Text("Page \(title)").tabItem { Label(title, systemImage: "star") }
            }
        }
        let titles = ["One", "Two"]
        let graph = layout(
            TabView {
                ForEach(Array(titles.enumerated()), id: \.offset) { index, title in
                    Page(title: title).tag(index)
                }
            },
            width: 400, height: 300
        )
        graph.settle()
        #expect(graph.texts.contains("One"))
        #expect(graph.texts.contains("Two"))
        #expect(!graph.texts.contains("Tab 1"))
    }

    @Test func swipeActionsShowInTheContextMenu() {
        let log = Box<[String]>([])
        let graph = layout(
            List {
                Text("Row").swipeActions { Button("Delete") { log.value.append("delete") } }
            },
            width: 300, height: 200
        )
        let row = graph.textFrames["Row"] ?? .zero
        graph.secondaryClick(at: CGPoint(x: row.midX, y: row.midY))
        graph.settle()
        let delete = graph.textFrames["Delete"] ?? .zero
        #expect(delete != .zero)
        graph.tap(at: CGPoint(x: delete.midX, y: delete.midY))
        graph.update()
        #expect(log.value == ["delete"])
    }

    @Test func exitCommandRunsOnEscape() {
        let log = Box<[String]>([])
        let graph = layout(
            TextField("Name", text: .constant("")).onExitCommand { log.value.append("exit") }
        )
        let field = graph.textFrames["Name"] ?? .zero
        graph.tap(at: CGPoint(x: field.midX, y: field.midY))
        graph.keyDown(.escape)
        #expect(log.value == ["exit"])
    }

    @Test func colorSpacesAndInitializers() {
        let linear = Color(.sRGBLinear, red: 0.5, green: 0, blue: 1).resolve(in: EnvironmentValues())
        // Linear 0.5 is about 0.735 in sRGB.
        #expect(abs(linear.red - 0.735) < 0.01)
        #expect(linear.blue == 1)
        #expect(Color(.sRGBLinear, white: 0, opacity: 0.33).resolve(in: EnvironmentValues()).opacity == 0.33)

        let graph = layout(
            VStack {
                Section(header: Text("Header"), footer: Text("Footer")) { Text("Content") }
                Stepper(onIncrement: { }, onDecrement: nil) { Text("Steps") }
                ProgressView(String("Loading"))
                Label(String("Starred"), systemImage: "star")
            }
        )
        #expect(graph.texts == ["Header", "Content", "Footer", "Steps", "−", "+", "Loading", "Starred"])
    }

    #if canImport(AppKit)
    @Test func appKitColorsFollowTheAppearance() {
        let color = Color(NSColor.labelColor)
        var light = EnvironmentValues()
        light.colorScheme = .light
        var dark = EnvironmentValues()
        dark.colorScheme = .dark
        #expect(color.resolve(in: light).red < 0.5)
        #expect(color.resolve(in: dark).red > 0.5)
    }
    #endif
}

#if !canImport(Combine)
/// Cacao's publishers as async sequences, where there's no Combine.
@MainActor
@Suite struct AsyncPublisherTests {

    final class Model: ObservableObject {
        @Published var count = 0
    }

    @Test func publishedValuesArriveInOrder() async {
        let model = Model()
        var iterator = model.$count.values.makeAsyncIterator()
        // The current value first, then each new one.
        #expect(await iterator.next() == 0)
        model.count = 1
        model.count = 2
        #expect(await iterator.next() == 1)
        #expect(await iterator.next() == 2)
    }

    @Test func objectWillChangeIsAPublisher() {
        func changes(of object: some ObservableObject) -> (Box<Int>, AnyCancellable) {
            let count = Box(0)
            let subscription = object.objectWillChange.sink { _ in count.value += 1 }
            return (count, subscription)
        }
        let model = Model()
        let (count, subscription) = changes(of: model)
        model.count = 5
        #expect(count.value == 1)
        subscription.cancel()
        model.count = 6
        #expect(count.value == 1)
    }
}
#endif

