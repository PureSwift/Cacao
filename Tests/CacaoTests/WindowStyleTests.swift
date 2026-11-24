import Foundation
#if canImport(CoreGraphics)
import CoreGraphics
#endif
import Testing
@testable import Cacao

/// A window with the system's title bar, one with none and one plain.
@MainActor
struct StyledWindowsApp: App {

    init() { }

    var body: some Scene {
        WindowGroup("Default") {
            Text("Default")
        }
        Window("System", id: "system") {
            Text("System")
        }
        .windowStyle(.titleBar)
        Window("Hidden", id: "hidden") {
            Text("Hidden")
        }
        .windowStyle(.hiddenTitleBar)
        .windowStyle(.titleBar)
        Window("Plain", id: "plain") {
            Text("Plain")
        }
        .windowStyle(.plain)
    }
}

@MainActor
@Suite struct WindowStyleTests {

    @Test func scenesChooseWhoDrawsTheTitleBar() {
        let windows = StyledWindowsApp().body.windowDescriptions()
        #expect(windows.map(\.windowStyle.value) == [.automatic, .titleBar, .hiddenTitleBar, .plain])
        // The modifier nearest the scene wins.
        #expect(windows.map(\.windowStyle.drawsOwnDecorations) == [false, false, true, true])
    }

    @Test func dragAreasMoveTheWindow() {
        let graph = layout(
            VStack(spacing: 0) {
                HStack(spacing: 0) {
                    Button("Close") { }
                        .probe("button")
                    Spacer()
                    Text("Title")
                        .probe("title")
                }
                .frame(height: 40)
                .background(Color.gray)
                .gesture(WindowDragGesture())
                .probe("bar")
                Color.white
                    .probe("content")
            }
        )
        let bar = graph.frame("bar")
        let title = graph.frame("title")
        // The bar's background and the text on it move the window.
        #expect(graph.movesWindow(at: CGPoint(x: bar.midX, y: bar.midY)))
        #expect(graph.movesWindow(at: CGPoint(x: title.midX, y: title.midY)))
        // A button on the bar takes its press.
        let button = graph.frame("button")
        #expect(!graph.movesWindow(at: CGPoint(x: button.midX, y: button.midY)))
        // Content outside the bar doesn't move it.
        let content = graph.frame("content")
        #expect(!graph.movesWindow(at: CGPoint(x: content.midX, y: content.midY)))
    }

    @Test func gesturesAroundADragAreaStillSeePresses() {
        var taps = 0
        let graph = layout(
            Color.gray
                .frame(width: 200, height: 40)
                .gesture(WindowDragGesture())
                .onTapGesture { taps += 1 }
                .probe("bar")
        )
        let bar = graph.frame("bar")
        // A tap gesture around the area takes presses, outside it.
        #expect(graph.movesWindow(at: CGPoint(x: bar.midX, y: bar.midY)))
        graph.pointer(.began, at: CGPoint(x: bar.midX, y: bar.midY))
        graph.pointer(.ended, at: CGPoint(x: bar.midX, y: bar.midY))
        #expect(taps == 1)
    }
}
