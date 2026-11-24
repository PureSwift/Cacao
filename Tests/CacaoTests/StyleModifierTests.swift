import CacaoRender
import CacaoTokens
import Foundation
#if canImport(CoreGraphics)
import CoreGraphics
#endif
import Testing
@testable import Cacao

@MainActor
@Suite struct StyleModifierTests {

    @Test func tintChangesAccentColor() {
        let graph = layout(Color.accentColor.frame(width: 10, height: 10).tint(.red))
        #expect(graph.colorItems.first?.color == Color.red.resolve(in: EnvironmentValues()))
        let untinted = layout(Color.accentColor.frame(width: 10, height: 10))
        #if os(Linux)
        #expect(untinted.colorItems.first?.color == StyleTokens.defaultAccentColor)
        #else
        #expect(untinted.colorItems.first?.color == Color.blue.resolve(in: EnvironmentValues()))
        #endif
    }

    @Test func styleTokensFollowTheEnvironment() {
        var environment = EnvironmentValues()
        #expect(environment.styleTokens.isDark == false)
        #expect(environment.styleTokens.isHighContrast == false)
        #expect(environment.styleTokens.accentColor == Color.accentColor.resolve(in: environment))
        environment.colorScheme = .dark
        environment.colorSchemeContrast = .increased
        let orange = Color.Resolved(red: 1, green: 0.5, blue: 0)
        environment.systemAccentColor = orange
        #expect(environment.styleTokens == StyleTokens(isDark: true, accentColor: orange, isHighContrast: true))
        environment.tint = .red
        #expect(environment.styleTokens.accentColor == Color.red.resolve(in: environment))
    }

    @Test func theSystemsAccentColorIsTheAccentWithoutATint() {
        var environment = EnvironmentValues()
        let orange = Color.Resolved(red: 1, green: 0.5, blue: 0)
        environment.systemAccentColor = orange
        #expect(Color.accentColor.resolve(in: environment) == orange)
        environment.tint = .red
        #expect(Color.accentColor.resolve(in: environment) == Color.red.resolve(in: environment))
    }

    @Test func textCaseTransformsText() {
        let graph = layout(VStack {
            Text("Hello").textCase(.uppercase)
            Text("World").textCase(.lowercase)
        })
        #expect(graph.texts == ["HELLO", "world"])
    }

    @Test func shadowWrapsContent() {
        let graph = layout(Color.red.frame(width: 20, height: 20).shadow(color: .black, radius: 4, x: 2, y: 3))
        let shadow = graph.displayList().items.compactMap { item -> ShadowEffect? in
            if case let .effect(.shadow(shadow), _) = item.value { return shadow }
            return nil
        }.first
        #expect(shadow?.offset == CGSize(width: 2, height: 3))
        #expect(shadow?.radius == 4)
    }

    @Test func hoverEntersAndExits() {
        let log = GestureLog()
        let graph = layout(
            Color.red.frame(width: 50, height: 50).probe("box").onHover { log.log($0 ? "in" : "out") },
            width: 200, height: 200
        )
        let center = graph.center("box")
        graph.hover(at: center)
        graph.hover(at: CGPoint(x: center.x + 1, y: center.y))
        graph.hover(at: CGPoint(x: 5, y: 5))
        graph.hover(at: center)
        graph.hover(at: nil)
        #expect(log.events == ["in", "out", "in", "out"])
    }

    @Test func continuousHoverReportsLocalLocation() {
        let log = GestureLog()
        let graph = layout(
            Color.red.frame(width: 50, height: 50).probe("box").onContinuousHover { phase in
                switch phase {
                case let .active(point): log.log("\(Int(point.x)),\(Int(point.y))")
                case .ended: log.log("ended")
                }
            },
            width: 200, height: 200
        )
        let frame = graph.frame("box")
        graph.hover(at: CGPoint(x: frame.minX + 5, y: frame.minY + 7))
        graph.hover(at: nil)
        #expect(log.events == ["5,7", "ended"])
    }

    @Test func keyboardShortcutPressesButton() {
        let log = GestureLog()
        let graph = layout(VStack {
            Button("Save") { log.log("save") }.keyboardShortcut("s")
            Button("Done") { log.log("done") }.keyboardShortcut(.defaultAction)
        })
        graph.keyDown(.character("s"), modifiers: .shortcut)
        graph.keyDown(.returnKey)
        graph.keyDown(.character("x"), modifiers: .shortcut)
        #expect(log.events == ["save", "done"])
    }

    @Test func keyPressGoesToFocusedView() {
        let log = GestureLog()
        let graph = layout(
            Color.red.frame(width: 50, height: 50).probe("box")
                .focusable()
                .onKeyPress(.upArrow) { log.log("up"); return .handled }
                .onKeyPress(phases: .down) { press in log.log("key \(press.characters)"); return .handled },
            width: 100, height: 100
        )
        // Not focused yet.
        graph.keyDown(.up)
        #expect(log.events.isEmpty)
        graph.click(graph.center("box"), at: 1)
        graph.keyDown(.up)
        graph.insertText("a")
        #expect(log.events == ["up", "key a"])
    }

    @Test func preferredColorSchemeReachesTheGraph() {
        let graph = layout(Text("Dark").preferredColorScheme(.dark))
        #expect(graph.preferredColorScheme == .dark)
        #expect(layout(Text("Any")).preferredColorScheme == nil)
    }

    @Test func scrollDisabledStopsScrolling() {
        let graph = layout(
            ScrollView { Color.red.frame(height: 1000) }.scrollDisabled(true),
            width: 100, height: 100
        )
        #expect(!graph.scroll(by: CGSize(width: 0, height: 50), at: CGPoint(x: 50, y: 50)))
    }

    @Test func labeledContentShowsLabelAndValue() {
        let graph = layout(LabeledContent("Name", value: "Cacao"), width: 300, height: 50)
        #expect(graph.texts == ["Name", "Cacao"])
        let frames = graph.textFrames
        #expect((frames["Cacao"]?.minX ?? 0) > (frames["Name"]?.maxX ?? 0) + 100)
    }

    @Test func contentUnavailableViewShowsTitleAndDescription() {
        let graph = layout(ContentUnavailableView("No Mail", systemImage: "tray", description: Text("New mail shows here.")))
        #expect(graph.texts == ["No Mail", "New mail shows here."])
        #expect(layout(ContentUnavailableView.search(text: "cats")).texts.first == "No Results for \"cats\"")
    }

    @Test func viewFontWeightAppliesToText() {
        let graph = layout(Text("Bold").bold())
        let run = graph.drawnItems.compactMap { drawn -> ResolvedText? in
            if case let .content(.text(text)) = drawn.item.value { return text }
            return nil
        }.first?.runs.first
        #expect(run?.font.weight == 700)
    }
}
