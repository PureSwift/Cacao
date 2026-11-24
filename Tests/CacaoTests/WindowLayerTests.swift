import Foundation
#if canImport(CoreGraphics)
import CoreGraphics
#endif
import Testing
@testable import Cacao

/// A menu bar in the top layer, a desktop in the background, and an
/// ordinary window.
@MainActor
struct LayeredApp: App {

    init() { }

    var body: some Scene {
        WindowGroup("Bar") {
            Text("Bar")
        }
        .defaultSize(width: 800, height: 28)
        .windowLayer(
            .top,
            edges: [.top, .leading, .trailing],
            exclusiveZone: 28,
            margins: EdgeInsets(top: 0, leading: 4, bottom: 0, trailing: 4),
            keyboardInteractivity: .none,
            namespace: "menubar"
        )
        Window("Desktop", id: "desktop") {
            Text("Desktop")
        }
        .windowLayer(.background, edges: .all, exclusiveZone: -1)
        .windowLayer(.overlay, edges: .top)
        Window("Notes", id: "notes") {
            Text("Notes")
        }
    }
}

@MainActor
@Suite struct WindowLayerTests {

    @Test func scenesPlaceTheirWindowsInLayers() throws {
        let windows = LayeredApp().body.windowDescriptions()
        #expect(windows.map(\.title) == ["Bar", "Desktop", "Notes"])

        let bar = try #require(windows[0].layer)
        #expect(bar.layer == .top)
        #expect(bar.edges == [.top, .leading, .trailing])
        #expect(bar.exclusiveZone == 28)
        #expect(bar.margins == EdgeInsets(top: 0, leading: 4, bottom: 0, trailing: 4))
        #expect(bar.keyboardInteractivity == .none)
        #expect(bar.namespace == "menubar")
        #expect(windows[0].defaultSize == CGSize(width: 800, height: 28))

        // The modifier nearest the scene wins.
        let desktop = try #require(windows[1].layer)
        #expect(desktop.layer == .background)
        #expect(desktop.edges == .all)
        #expect(desktop.exclusiveZone == -1)
        #expect(desktop.keyboardInteractivity == .onDemand)
        #expect(desktop.namespace == "")

        #expect(windows[2].layer == nil)
    }
}
