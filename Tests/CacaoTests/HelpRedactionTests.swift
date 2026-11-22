import CacaoRender
import Foundation
#if canImport(CoreGraphics)
import CoreGraphics
#endif
import Testing
@testable import Cacao

@MainActor
@Suite struct HelpRedactionTests {

    @Test func helpShowsAsATooltipOnceThePointerRests() {
        let graph = layout(
            VStack(spacing: 0) {
                Color.red.frame(width: 100, height: 40).help("Deletes the file").probe("delete")
                Color.blue.frame(width: 100, height: 40).probe("plain")
            },
            width: 400, height: 300
        )
        let delete = graph.frame("delete")
        graph.advance(to: 1)
        graph.hover(at: CGPoint(x: delete.midX, y: delete.midY))
        graph.advance(to: 1.5)
        #expect(graph.tooltipText == nil)
        graph.advance(to: 2.1)
        graph.settle()
        #expect(graph.tooltipText == "Deletes the file")
        #expect(graph.texts.contains("Deletes the file"))
        // It shows below the pointer, and doesn't take clicks.
        let tip = graph.textFrames["Deletes the file"] ?? .zero
        #expect(tip.minY > delete.midY)
        // Moving to a view without help hides it.
        let plain = graph.frame("plain")
        graph.hover(at: CGPoint(x: plain.midX, y: plain.midY))
        graph.settle()
        #expect(graph.tooltipText == nil)
        #expect(!graph.texts.contains("Deletes the file"))
    }

    @Test func pressingHidesTheTooltip() {
        let graph = layout(Color.red.frame(width: 100, height: 40).help("Tip").probe("box"), width: 400, height: 300)
        let box = graph.frame("box")
        graph.hover(at: CGPoint(x: box.midX, y: box.midY))
        graph.advance(to: 2)
        #expect(graph.tooltipText == "Tip")
        graph.pointer(.began, at: CGPoint(x: box.midX, y: box.midY))
        graph.pointer(.ended, at: CGPoint(x: box.midX, y: box.midY))
        #expect(graph.tooltipText == nil)
    }

    @Test func helpIsTheAccessibilityHint() {
        let graph = layout(Button("Save") { }.help("Saves the document"))
        func find(_ element: AccessibilityElement) -> AccessibilityElement? {
            if element.label == "Save" { return element }
            return element.children.lazy.compactMap(find).first
        }
        #expect(find(graph.accessibilityTree())?.hint == "Saves the document")
    }

    @Test func placeholderRedactionDrawsShapesInPlaceOfText() {
        let graph = layout(
            VStack {
                Text("Secret").probe("secret")
                Text("Shown").unredacted()
            }
            .redacted(reason: .placeholder),
            width: 300, height: 200
        )
        // The text keeps its size but isn't drawn.
        #expect(graph.frame("secret").width > 0)
        let secret = graph.drawnItems.first { item in
            if case let .content(.text(text)) = item.item.value { return text.string == "Secret" }
            return false
        }
        #expect(secret?.opacity == 0)
        let placeholder = Color.primary.opacity(0.15).resolve(in: EnvironmentValues())
        let shape = graph.drawnItems.first { item in
            if case let .content(.shape(content)) = item.item.value, content.color == placeholder { return true }
            if case let .content(.roundedRectangle(content)) = item.item.value, content.color == placeholder { return true }
            return false
        }
        #expect(shape?.item.frame.size == graph.frame("secret").size)
    }

    @Test func controlSizeScalesBorderedButtons() {
        func height(_ size: ControlSize) -> CGFloat {
            let graph = layout(Button("Go") { }.buttonStyle(.bordered).controlSize(size).probe("button"))
            return graph.frame("button").height
        }
        #expect(height(.mini) < height(.small))
        #expect(height(.small) < height(.regular))
        #expect(height(.regular) < height(.large))
        #expect(height(.large) < height(.extraLarge))
    }

    @Test func contentTransitionFadesBetweenStrings() {
        struct Counter: View {
            let model: AnimationModel
            var body: some View {
                Text(model.flag ? "2" : "1")
                    .contentTransition(.numericText())
            }
        }
        let model = AnimationModel()
        let graph = layout(Counter(model: model))
        graph.advance(to: 1)
        withAnimation(.linear(duration: 1)) { model.flag = true }
        graph.settle()
        graph.advance(to: 1.5)
        // Halfway, the old string fades out as the new one fades in.
        func opacity(of string: String) -> Double? {
            graph.drawnItems.first { item in
                if case let .content(.text(text)) = item.item.value { return text.string == string }
                return false
            }?.opacity
        }
        #expect((opacity(of: "1") ?? 0) > 0 && (opacity(of: "1") ?? 1) < 1)
        #expect((opacity(of: "2") ?? 0) > 0 && (opacity(of: "2") ?? 1) < 1)
        graph.advance(to: 2.1)
        #expect(opacity(of: "1") == nil)
        #expect(opacity(of: "2") == 1)
        // Without an animation, the string just changes.
        model.flag = false
        graph.settle()
        #expect(opacity(of: "2") == nil)
        #expect(opacity(of: "1") == 1)
    }

    @Test func badgesShowOnListRowsAndTabs() {
        let list = layout(
            List {
                Text("Inbox").badge(3).probe("inbox")
                Text("Sent").badge(0)
            },
            width: 300, height: 200
        )
        list.settle()
        #expect(list.texts == ["Inbox", "3", "Sent"])
        // At the trailing edge.
        #expect((list.textFrames["3"]?.maxX ?? 0) > 250)

        let tabs = layout(
            TabView {
                Text("Mail").tabItem { Text("Mail") }.badge(5)
                Text("Other").tabItem { Text("Other") }
            },
            width: 400, height: 300
        )
        tabs.settle()
        #expect(tabs.texts.contains("5"))
    }
}

