import Foundation
#if canImport(CoreGraphics)
import CoreGraphics
#endif
import Testing
@testable import Cacao

@MainActor
@Suite struct AccessibilityTests {

    func flatten(_ element: AccessibilityElement) -> [AccessibilityElement] {
        [element] + element.children.flatMap(flatten)
    }

    @Test func textAndButtonsBecomeElements() {
        let graph = layout(VStack {
            Text("Title")
            Button("Save") { }
        })
        let elements = flatten(graph.accessibilityTree()).dropFirst()
        #expect(elements.map(\.role) == [.staticText, .button])
        #expect(elements.map(\.label) == ["Title", "Save"])
        #expect(elements.last?.traits.contains(.isButton) == true)
        #expect(elements.last?.actions == ["default"])
    }

    @Test func modifiersSetLabelsValuesAndTraits() {
        let graph = layout(
            Text("42")
                .accessibilityLabel("Answer")
                .accessibilityValue("forty-two")
                .accessibilityHint("The answer")
                .accessibilityAddTraits(.isHeader)
        )
        let element = graph.accessibilityTree().children.first
        #expect(element?.label == "Answer")
        #expect(element?.value == "forty-two")
        #expect(element?.hint == "The answer")
        #expect(element?.traits.contains(.isHeader) == true)
        #expect(element?.traits.contains(.isStaticText) == true)
    }

    @Test func hiddenViewsAreLeftOut() {
        let graph = layout(VStack {
            Text("Shown")
            Text("Hidden").accessibilityHidden(true)
        })
        #expect(flatten(graph.accessibilityTree()).map(\.label).contains("Shown"))
        #expect(!flatten(graph.accessibilityTree()).map(\.label).contains("Hidden"))
    }

    @Test func combinedElementsJoinLabels() {
        let graph = layout(
            HStack {
                Text("Wi-Fi")
                Text("On")
            }
            .accessibilityElement(children: .combine)
        )
        let elements = graph.accessibilityTree().children
        #expect(elements.count == 1)
        #expect(elements.first?.label == "Wi-Fi, On")
        #expect(elements.first?.children.isEmpty == true)
    }

    @Test func actionsPerformByName() {
        let log = GestureLog()
        let graph = layout(
            Button("Delete") { log.log("tap") }
                .accessibilityAction(named: Text("Archive")) { log.log("archive") }
        )
        let button = flatten(graph.accessibilityTree()).first { $0.role == .button }
        #expect(button?.actions == ["default", "Archive"])
        guard let frame = button?.frame else { return }
        graph.performAccessibilityAction("Archive", at: frame)
        graph.performAccessibilityAction("default", at: frame)
        #expect(log.events == ["archive", "tap"])
    }
}

@MainActor
@Suite struct WindowSceneTests {

    struct Item: Hashable, Codable {
        let name: String
    }

    struct TwoScenes: App {
        var body: some Scene {
            WindowGroup("Main") { Text("Main") }
            WindowGroup("Item", for: Item.self) { $item in
                Text(item?.name ?? "None")
            }
            Window("About", id: "about") { Text("About") }
        }
    }

    @Test func valueWindowGroupsMakeRootsForValues() {
        let descriptions = TwoScenes().body.windowDescriptions()
        #expect(descriptions.map(\.title) == ["Main", "Item", "About"])
        #expect(descriptions[2].isUnique)
        guard let make = descriptions[1].makeRootView else {
            Issue.record("No value window")
            return
        }
        let graph = layout(make(AnyHashable(Item(name: "Cacao"))))
        #expect(graph.texts == ["Cacao"])
    }

    @Test func openWindowCallsTheHost() {
        var opened: [String?] = []
        struct Opener: View {
            @Environment(\.openWindow) var openWindow
            var body: some View {
                Button("About") { openWindow(id: "about") }
            }
        }
        var environment = EnvironmentValues()
        environment.openWindow = OpenWindowAction { id, _ in opened.append(id) }
        let graph = ViewGraph(rootView: Opener(), environment: environment)
        graph.layout(in: CGSize(width: 200, height: 100))
        graph.tapText("About")
        #expect(opened == ["about"])
    }
}
