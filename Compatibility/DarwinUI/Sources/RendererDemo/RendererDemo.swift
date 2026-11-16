// Shows DarwinAppRuntime's rendering test tree, every node and modifier,
// through DarwinUI's renderer in a Cacao window.
import Foundation
import Cacao
import CacaoSDL
import DynamicRuntime
import DynamicUI
@testable import DarwinUI


/// A guest stand-in: records events and row requests, and answers them
/// through `onEvent` and `rows`, as a guest answers with an update before
/// the call returns.
final class RecordingDelegate: RendererDelegate {

    struct Event: Equatable {
        var node: RenderNode.ID
        var kind: RenderEventKind
        var payload: PropValue?
    }

    var events: [Event] = []

    var rowRequests: [(list: RenderNode.ID, index: Int)] = []

    /// Called for each event, after it's recorded.
    var onEvent: (Event) -> Void = { _ in }

    /// Row `index` of a list, or `nil` for none.
    var rows: (RenderNode.ID, Int) -> RenderNode? = { _, _ in nil }

    func event(_ node: [UInt8], kind: Int32, payload: [UInt8]) {
        let event = Event(
            node: try! RenderCodec.decode(id: node),
            kind: RenderEventKind(rawValue: kind)!,
            payload: payload.isEmpty ? nil : try! RenderCodec.decode(payload: payload)
        )
        events.append(event)
        onEvent(event)
    }

    func rowCount(_ list: [UInt8]) -> Int32 {
        0
    }

    func row(_ list: [UInt8], index: Int32) -> [UInt8] {
        let list = try! RenderCodec.decode(id: list)
        rowRequests.append((list, Int(index)))
        return rows(list, Int(index)).map(RenderCodec.encode) ?? []
    }
}


enum Tree {
    /// The test's modifiers on every node, only when asked for.
    static var modifiers: [ModifierNode] {
        ProcessInfo.processInfo.environment["DEMO_MODIFIERS"] == nil ? [] : allModifiers
    }

    static let allModifiers: [ModifierNode] = [
        ModifierNode("padding", ["top": 1.0, "leading": 2.0, "bottom": 3.0, "trailing": 4.0]),
        ModifierNode("frame", ["width": 100.0, "height": 40.0, "horizontal": "leading", "vertical": "top"]),
        ModifierNode("frame", ["minWidth": 10.0, "maxWidth": .double(.infinity), "maxHeight": 200.0, "horizontal": "center", "vertical": "center"]),
        ModifierNode("frame", ["width": .double(.infinity), "height": -1.0]),
        ModifierNode("offset", ["x": 1.0, "y": 2.0]),
        ModifierNode("background", ["color": "red"]),
        ModifierNode("background", ["color": .array(["blue", 0.5])]),
        ModifierNode("background", ["color": .int(0x80FF_8000)]),
        ModifierNode("foregroundColor", ["color": "mint"]),
        ModifierNode("foregroundColor"),
        ModifierNode("tint", ["color": "cyan"]),
        ModifierNode("tint"),
        ModifierNode("opacity", ["value": 0.5]),
        ModifierNode("cornerRadius", ["radius": 4.0]),
        ModifierNode("border", ["color": "brown", "width": 2.0]),
        ModifierNode("shadow", ["color": .int(0x5400_0000), "radius": 3.0, "x": 0.0, "y": 1.0]),
        ModifierNode("font", ["style": "headline"]),
        ModifierNode("font", ["size": 13.0, "weight": "semibold", "design": "rounded", "italic": true]),
        ModifierNode("font", ["style": "caption", "design": "monospaced"]),
        ModifierNode("font"),
        ModifierNode("fontWeight", ["weight": "bold"]),
        ModifierNode("fontWeight"),
        ModifierNode("italic", ["value": true]),
        ModifierNode("lineLimit", ["lines": 2]),
        ModifierNode("lineLimit"),
        ModifierNode("multilineTextAlignment", ["alignment": "center"]),
        ModifierNode("disabled", ["value": false]),
        ModifierNode("onTapGesture", ["count": 2]),
        ModifierNode("accessibilityLabel", ["text": "Label"]),
        ModifierNode("accessibilityIdentifier", ["identifier": "identifier"]),
        ModifierNode("someFutureModifier", ["value": 1]),
    ]

    /// One node of every type, each with every modifier kind.
    static var everything: RenderNode {
        var next: RenderNode.ID = 1000
        func node(_ type: String, _ props: [String: PropValue] = [:], _ children: [RenderNode] = [], count: Int? = nil) -> RenderNode {
            next += 1
            return RenderNode(type, id: next, props: props, modifiers: modifiers, children: children, count: count)
        }
        func label(_ string: String) -> RenderNode {
            node("Text", ["text": .string(string)])
        }
        let content: [RenderNode] = [
            label("Text"),
            node("Image", ["systemName": "star", "resizable": true]),
            node("Image", ["name": "missing"]),
            node("Image"),
            node("Label", ["title": "Label", "systemImage": "star"]),
            node("Spacer", ["minLength": 8.0]),
            node("Divider"),
            node("Color", ["color": "indigo"]),
            node("Color", ["color": "notAColor"]),
            node("HStack", ["alignment": "top", "spacing": 4.0], [label("a"), label("b")]),
            node("ZStack", ["horizontal": "trailing", "vertical": "bottom"], [label("back"), label("front")]),
            node("ScrollView", ["axes": "both", "showsIndicators": false], [label("scrolled")]),
            node("Button", [:], [label("Button")]),
            node("NavigationLink", [:], [label("Link")]),
            node("Toggle", ["isOn": true], [label("Toggle")]),
            node("TextField", ["text": "text", "placeholder": "Name"]),
            node("TextField", ["text": "secret", "placeholder": "Password", "secure": true]),
            node("Slider", ["value": 0.5, "min": 0.0, "max": 1.0]),
            node("Slider", ["value": 2.0, "min": 0.0, "max": 10.0, "step": 1.0]),
            node("Slider", ["value": 0.0, "min": 1.0, "max": 0.0, "step": 0.0]),
            node("Stepper", ["value": 1, "min": .int(.min), "max": .int(.max), "step": 1], [label("Stepper")]),
            node("ProgressView", ["total": 1.0, "value": 0.25, "title": "Loading"]),
            node("ProgressView", ["total": 0.0, "value": 5.0]),
            node("ProgressView", ["total": 1.0]),
            node("List", [:], [
                node("Section", ["header": "Header", "footer": "Footer"], [label("Row"), node("NavigationLink", [:], [label("Row link")])]),
                node("Section", [:], [label("Row")]),
            ]),
            node("List", ["revision": 1], count: 3),
            node("LazyVStack", ["alignment": "leading", "spacing": 2.0, "revision": 1], count: 2),
            node("LazyHStack", ["alignment": "bottom", "spacing": 2.0, "revision": 1], count: 2),
            node("LazyVStack", ["alignment": "trailing", "spacing": 2.0], [label("eager")]),
            node("LazyHStack", ["alignment": "top", "spacing": 2.0], [label("eager")]),
            node("Button", ["role": "destructive"], [label("Delete")]),
            node("Picker", ["title": "Segmented", "selection": 1, "style": "segmented"], [label("A"), label("B")]),
            node("Picker", ["title": "Menu", "selection": 0, "style": "menu"], [label("A"), node("Label", ["title": "B", "systemImage": "star"])]),
            node("Picker", ["title": "Inline", "style": "inline"], [label("A")]),
            node("Picker", ["title": "Wheel", "selection": 5, "style": "wheel"], [label("A")]),
            node("Picker", ["title": "Default", "style": "someFutureStyle"], []),
            node("LazyVGrid", ["columns": .array([
                .array(["fixed", 40.0, 40.0, 8.0, "center", "center"]),
                .array(["flexible", 10.0, .double(.infinity), 4.0, "leading", "top"]),
                .array(["adaptive", 0.0, -1.0]),
                .array(["someFutureSize", 1.0, 2.0]),
                "notAnItem",
            ]), "alignment": "leading", "spacing": 4.0, "revision": 1], count: 4),
            node("LazyVGrid", ["columns": .array([]), "alignment": "center", "spacing": 8.0], [label("1"), label("2")]),
            node("LazyHGrid", ["rows": .array([.array(["adaptive", 20.0, 40.0, 8.0, "center", "bottom"])]), "alignment": "top", "spacing": 2.0, "revision": 1], count: 2),
            node("LazyHGrid", ["alignment": "center", "spacing": 8.0], [label("1")]),
            node("TabView", ["selection": 1], [
                node("Tab", ["title": "One", "systemImage": "1.circle"], [label("Tab one")]),
                node("Tab", ["systemImage": "2.circle"], [label("Tab two")]),
                node("Tab", ["title": "Three"], []),
            ]),
            node("Tab", ["title": "Loose tab"], [label("tab")]),
            node("Sheet", ["isPresented": false, "style": "sheet"], [label("Anchor")]),
            node("Sheet", ["isPresented": false, "style": "fullScreenCover"], [label("Cover anchor")]),
            node("Alert", ["title": "Alert", "isPresented": false, "message": "Message"], [label("Alert anchor")]),
            node("Form", [:], [node("Section", ["header": "Form"], [label("In a form")]), node("Toggle", ["isOn": false], [label("Switch")])]),
            node("Menu", ["title": "Menu", "systemImage": "ellipsis.circle"], [
                node("Button", [:], [label("Item")]),
                node("Divider"),
                node("Menu", ["title": "Submenu"], [node("Button", ["role": "destructive"], [label("Delete")])]),
            ]),
            node("Alert", ["title": "Dialog", "isPresented": false, "style": "dialog", "titleVisibility": "visible"], [label("Dialog anchor")]),
            node("ToolbarItem", ["placement": "automatic"], [label("loose item")]),
            node("Grid", ["horizontal": "leading", "vertical": "top", "horizontalSpacing": 12.0, "verticalSpacing": 4.0], [
                node("GridRow", [:], [label("A"), label("B")]),
                node("Divider"),
                node("GridRow", ["alignment": "bottom"], [label("C")]),
            ]),
            node("GridRow", [:], [label("loose cell")]),
            node("DisclosureGroup", ["isExpanded": true], [label("Details"), label("Shown")]),
            node("DisclosureGroup", ["isExpanded": false], [label("Closed")]),
            node("Link", ["url": "https://example.com"], [label("Link")]),
            node("Link", ["url": "not a url"], [label("Not a link")]),
            node("List", [:], [
                node("SwipeActions", ["edge": "trailing", "allowsFullSwipe": true], [
                    node("SwipeActions", ["edge": "leading", "allowsFullSwipe": false], [label("Row"), node("Button", [:], [label("Pin")])]),
                    node("Button", ["role": "destructive"], [label("Delete")]),
                ]),
            ]),
            node("Searchable", ["text": "query", "prompt": "Search"], [label("Searched")]),
            node("HStack", [:], [
                node("Shape", ["shape": "rectangle"]),
                node("Shape", ["shape": "roundedRectangle", "cornerRadius": 4.0, "fill": "red"]),
                node("Shape", ["shape": "circle", "stroke": "blue", "lineWidth": 2.0]),
                node("Shape", ["shape": "ellipse", "fill": "notAColor"]),
                node("Shape", ["shape": "capsule"]),
                node("Shape", ["shape": "someFutureShape"]),
            ]),
            node("DatePicker", ["title": "When", "value": 1_000_000.0, "components": "date", "min": 0.0, "max": 2_000_000.0]),
            node("DatePicker", ["title": "Any", "value": 0.0, "components": "date,hourAndMinute,someFuture"]),
            node("DatePicker", ["title": "Bad range", "value": 0.0, "min": 5.0, "max": 1.0]),
            node("ContextMenu", [:], [label("Pressed"), node("Button", [:], [label("Copy")]), node("Divider")]),
            node("Refreshable", ["refreshing": false], [node("List", [:], [label("Pull")])]),
            node("NavLevel", ["title": "Loose level"], [label("level")]),
            node("SomeFutureView", ["value": 1], [label("never shown")]),
        ]
        let toolbar = [
            node("ToolbarItem", ["placement": "primaryAction"], [node("Button", [:], [label("Add")])]),
            node("ToolbarItem", ["placement": "automatic"], [node("Button", [:], [label("Edit")]), node("Button", [:], [label("Share")])]),
            node("ToolbarItem", ["placement": "bottomBar"], [label("Status")]),
            node("ToolbarItem", ["placement": "someFuturePlacement"], [label("Elsewhere")]),
        ]
        let root = node("NavLevel", ["title": "Root"], [node("VStack", ["alignment": "leading", "spacing": 8.0], content)] + toolbar)
        let detail = node("NavLevel", ["title": "Detail"], [label("Detail")])
        return RenderNode("NavStack", id: 1, children: [root, detail])
    }

}

@main
struct RendererDemo: App {

    let renderer: SwiftUIRenderer

    init() {
        let delegate = RecordingDelegate()
        delegate.rows = { list, index in
            RenderNode("Text", id: list &* 100 &+ RenderNode.ID(index), props: ["text": .string("Row \(index)")])
        }
        renderer = SwiftUIRenderer(delegate: delegate)
        renderer.store.schedule = { $0() }
        var tree = Tree.everything
        // Only the root level, unless asked for the pushed detail too.
        if ProcessInfo.processInfo.environment["DEMO_DETAIL"] == nil {
            tree.children = [tree.children[0]]
        }
        renderer.store.apply(tree)
        retained = delegate
    }

    nonisolated(unsafe) static var retainedDelegate: RecordingDelegate?

    var retained: RecordingDelegate? {
        get { Self.retainedDelegate }
        nonmutating set { Self.retainedDelegate = newValue }
    }

    var body: some Scene {
        WindowGroup("DarwinUI on Cacao") {
            RendererView(renderer: renderer)
        }
        .defaultSize(width: 700, height: 1400)
    }
}
