import Foundation
import Testing
@testable import Cacao

// MARK: - Tests

@MainActor
@Suite struct SampleAppTests {

    @Test func todoAppRuns() {
        let windows = TodoApp().body.windowDescriptions()
        #expect(windows.map(\.title) == ["Todos"])
        guard let window = windows.first else { return }
        let graph = layout(window.rootView, width: 400, height: 600)
        graph.settle()
        #expect(graph.texts.contains("Todos"))
        #expect(graph.texts.contains("1 remaining"))
        #expect(graph.texts.contains("Buy cacao"))
        #expect(graph.texts.contains("Write docs"))
        // Push a detail screen.
        graph.tapText("Buy cacao")
        graph.finish()
        #expect(graph.texts.contains("Status"))
        #expect(graph.texts.contains("Open"))
        UserDefaults.standard.removeObject(forKey: "detailVisits")
    }
}
