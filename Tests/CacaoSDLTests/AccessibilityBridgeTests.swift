#if os(macOS)
import AppKit
import Testing
import Cacao
@testable import CacaoSDL

@MainActor
@Suite struct AccessibilityBridgeTests {

    @Test func elementsMirrorTheTree() {
        final class Log { var pressed = 0 }
        let log = Log()
        let graph = ViewGraph(rootView: VStack {
            Text("Title")
            Button("Save") { log.pressed += 1 }
            Toggle("On", isOn: .constant(true)).accessibilityAddTraits(.isSelected)
        })
        graph.layout(in: CGSize(width: 300, height: 200))
        let view = NSView(frame: NSRect(x: 0, y: 0, width: 300, height: 200))
        let bridge = AccessibilityBridge(view: view) { name, frame in
            graph.performAccessibilityAction(name, at: frame)
        }
        bridge.update(graph.accessibilityTree())
        let children = view.accessibilityChildren() as? [AccessibilityBridge.Element] ?? []
        #expect(children.count == bridge.elements.count)
        #expect(children.first?.accessibilityRole() == .staticText)
        #expect(children.first?.accessibilityLabel() == "Title")
        let button = children.first { $0.accessibilityRole() == .button }
        #expect(button?.accessibilityLabel() == "Save")
        #expect(button?.accessibilityPerformPress() == true)
        #expect(log.pressed == 1)
        // A view without a window: frames in the view, from its bottom.
        if let button {
            let frame = button.accessibilityFrame()
            #expect(frame.height == button.windowFrame.height)
            #expect(frame.minY == 200 - button.windowFrame.maxY)
        }
        // An unchanged tree keeps its elements.
        let before = bridge.elements.map(ObjectIdentifier.init)
        bridge.update(graph.accessibilityTree())
        #expect(bridge.elements.map(ObjectIdentifier.init) == before)
    }
}
#endif
