import CacaoRender
import Foundation
#if canImport(CoreGraphics)
import CoreGraphics
#endif
import Testing
@testable import Cacao

/// A value holder the test reads after interacting with views.
@MainActor
final class Box<Value> {
    var value: Value
    init(_ value: Value) { self.value = value }
    var binding: Binding<Value> {
        Binding(get: { self.value }, set: { self.value = $0 })
    }
}

@MainActor
extension ViewGraph {

    /// Lays out again and taps the center of a view.
    func tap(_ identifier: String, sourceLocation: SourceLocation = #_sourceLocation) {
        layout(in: size)
        let frame = frame(identifier, sourceLocation: sourceLocation)
        tap(at: CGPoint(x: frame.midX, y: frame.midY))
    }

    func tap(at point: CGPoint) {
        pointer(.began, at: point)
        pointer(.ended, at: point)
        layout(in: size)
    }

    func type(_ text: String) {
        insertText(text)
        layout(in: size)
    }

    func press(_ key: KeyCode, _ modifiers: KeyModifiers = []) {
        keyDown(key, modifiers: modifiers)
        layout(in: size)
    }
}

@MainActor
@Suite struct ControlTests {

    @Test func toggleSwitchFlips() {
        let isOn = Box(false)
        let graph = layout(Toggle("Wi-Fi", isOn: isOn.binding).probe("toggle"), width: 300)
        graph.tap("toggle")
        #expect(isOn.value)
        graph.tap("toggle")
        #expect(!isOn.value)
    }

    @Test func checkboxFlips() {
        let isOn = Box(false)
        let graph = layout(Toggle("Agree", isOn: isOn.binding).toggleStyle(.checkbox).probe("toggle"))
        graph.tap("toggle")
        #expect(isOn.value)
    }

    @Test func sliderFollowsDrags() {
        let value = Box(0.0)
        let graph = layout(Slider(value: value.binding, in: 0...100).frame(width: 220).probe("slider"), width: 300)
        let frame = graph.frame("slider")
        // The thumb's center travels from 10 points in to 10 points from the end.
        graph.pointer(.began, at: CGPoint(x: frame.minX + 10, y: frame.midY))
        #expect(abs(value.value - 0) < 0.01)
        graph.pointer(.moved, at: CGPoint(x: frame.midX, y: frame.midY))
        #expect(abs(value.value - 50) < 0.01)
        graph.pointer(.ended, at: CGPoint(x: frame.maxX + 100, y: frame.midY))
        #expect(value.value == 100)
    }

    @Test func steppedSliderSnaps() {
        let value = Box(0.0)
        let graph = layout(Slider(value: value.binding, in: 0...10, step: 5).frame(width: 220).probe("slider"), width: 300)
        let frame = graph.frame("slider")
        graph.pointer(.began, at: CGPoint(x: frame.minX + 10 + 200 * 0.3, y: frame.midY))
        graph.pointer(.ended, at: CGPoint(x: frame.minX + 10 + 200 * 0.3, y: frame.midY))
        #expect(value.value == 5)
    }

    @Test func stepperStaysInBounds() {
        struct Root: View {
            let value: Box<Int>
            var body: some View {
                Stepper("Count", value: value.binding, in: 0...2)
                    .frame(width: 240)
            }
        }
        let value = Box(1)
        let graph = layout(Root(value: value).probe("stepper"))
        // The + segment is the stepper's trailing 32 points; − is before it
        // and a one point divider.
        let stepper = graph.frame("stepper")
        let plus = CGPoint(x: stepper.maxX - 16, y: stepper.midY)
        let minus = CGPoint(x: stepper.maxX - 32 - 1 - 16, y: stepper.midY)
        graph.tap(at: plus)
        #expect(value.value == 2)
        graph.setRootView(Root(value: value).probe("stepper"))
        graph.layout(in: graph.size)
        graph.tap(at: plus)
        #expect(value.value == 2)
        graph.tap(at: minus)
        #expect(value.value == 1)
    }

    // MARK: Text

    struct Field: View {
        let text: Box<String>
        var submitted: Box<Int>? = nil
        var body: some View {
            TextField("Name", text: text.binding)
                .onSubmit { submitted?.value += 1 }
                .frame(width: 200)
                .probe("field")
        }
    }

    @Test func typingEditsText() {
        let text = Box("")
        let graph = layout(Field(text: text))
        graph.tap("field")
        #expect(graph.acceptsTextInput)
        graph.type("Hello")
        #expect(text.value == "Hello")
        graph.press(.backspace)
        #expect(text.value == "Hell")
        graph.press(.left)
        graph.press(.left)
        graph.type("X")
        #expect(text.value == "HeXll")
        graph.press(.end)
        graph.type("!")
        #expect(text.value == "HeXll!")
    }

    @Test func selectAllAndClipboard() {
        let text = Box("Copy me")
        var clipboard: String?
        let graph = layout(Field(text: text))
        graph.clipboard = Clipboard(read: { clipboard }, write: { clipboard = $0 })
        graph.tap("field")
        graph.press(.character("a"), .shortcut)
        graph.press(.character("x"), .shortcut)
        #expect(clipboard == "Copy me")
        #expect(text.value == "")
        graph.press(.character("v"), .shortcut)
        graph.press(.character("v"), .shortcut)
        #expect(text.value == "Copy meCopy me")
    }

    @Test func shiftExtendsSelection() {
        let text = Box("abcdef")
        let graph = layout(Field(text: text))
        graph.tap("field")
        graph.press(.end)
        graph.press(.left, .shift)
        graph.press(.left, .shift)
        graph.type("Z")
        #expect(text.value == "abcdZ")
    }

    @Test func returnSubmits() {
        let text = Box("")
        let submitted = Box(0)
        let graph = layout(Field(text: text, submitted: submitted))
        graph.tap("field")
        graph.press(.returnKey)
        #expect(submitted.value == 1)
    }

    @Test func secureFieldShowsBullets() {
        let text = Box("secret")
        let graph = layout(SecureField("Password", text: text.binding).frame(width: 200))
        #expect(graph.texts == ["••••••"])
    }

    @Test func placeholderShowsWhenEmpty() {
        let text = Box("")
        let graph = layout(Field(text: text))
        #expect(graph.texts == ["Name"])
    }

    @Test func tabMovesFocus() {
        struct Form: View {
            let first: Box<String>
            let second: Box<String>
            var body: some View {
                VStack {
                    TextField("First", text: first.binding).frame(width: 200)
                    TextField("Second", text: second.binding).frame(width: 200)
                }
            }
        }
        let first = Box(""), second = Box("")
        let graph = layout(Form(first: first, second: second))
        graph.press(.tab)
        graph.type("1")
        graph.press(.tab)
        graph.type("2")
        graph.press(.tab, .shift)
        graph.type("!")
        #expect(first.value == "1!")
        #expect(second.value == "2")
        graph.press(.escape)
        #expect(!graph.acceptsTextInput)
    }

    @Test func focusStateFocusesAndFollows() {
        struct Form: View {
            enum Field: Hashable { case name, email }
            let name: Box<String>
            let email: Box<String>
            let focus: Box<Field?>
            @FocusState var focused: Field?
            var body: some View {
                VStack {
                    TextField("Name", text: name.binding).focused($focused, equals: .name)
                    TextField("Email", text: email.binding).focused($focused, equals: .email)
                    Button("Next") { focused = .email }.probe("next")
                }
                .frame(width: 200)
                .onChange(of: focused) { _, new in focus.value = new }
            }
        }
        let name = Box(""), email = Box(""), focus = Box<Form.Field?>(nil)
        let graph = layout(Form(name: name, email: email, focus: focus))
        graph.tap("next")
        graph.update()
        graph.type("a@b.c")
        #expect(email.value == "a@b.c")
        graph.press(.tab, .shift)
        graph.update()
        #expect(focus.value == .name)
    }

    @Test func multilineTextEditor() {
        let text = Box("one")
        let graph = layout(TextEditor(text: text.binding).frame(width: 200, height: 100).probe("editor"))
        graph.tap("editor")
        graph.press(.end)
        graph.press(.returnKey)
        graph.type("two")
        #expect(text.value == "one\ntwo")
        graph.press(.up)
        graph.type("1")
        #expect(text.value == "one1\ntwo")
    }

    // MARK: Pickers and menus

    @Test func menuPickerSelects() {
        enum Flavor: Hashable { case vanilla, chocolate }
        let flavor = Box(Flavor.vanilla)
        let graph = layout(
            Picker("Flavor", selection: flavor.binding) {
                Text("Vanilla").tag(Flavor.vanilla)
                Text("Chocolate").tag(Flavor.chocolate)
            }
            .frame(width: 260),
            width: 400, height: 400
        )
        #expect(graph.texts.contains("Vanilla"))
        #expect(!graph.texts.contains("Chocolate"))
        let button = graph.texts.firstIndex(of: "Vanilla")
        #expect(button != nil)
        // Open the menu by its button, then choose.
        graph.tap(at: CGPoint(x: 330 - 30, y: 200))
        #expect(graph.isPresentingPopup)
        #expect(graph.texts.contains("Chocolate"))
        graph.layout(in: graph.size)
        let item = graph.textFrames["Chocolate"] ?? .zero
        graph.tap(at: CGPoint(x: item.midX, y: item.midY))
        graph.update()
        #expect(flavor.value == .chocolate)
        #expect(!graph.isPresentingPopup)
    }

    @Test func segmentedPickerSelects() {
        let index = Box(0)
        let graph = layout(
            Picker("Mode", selection: index.binding) {
                ForEach(0..<3, id: \.self) { Text("Mode \($0)") }
            }
            .pickerStyle(.segmented)
            .frame(width: 300)
        )
        let frame = graph.textFrames["Mode 2"] ?? .zero
        graph.tap(at: CGPoint(x: frame.midX, y: frame.midY))
        #expect(index.value == 2)
    }

    @Test func menuRunsActionsAndCloses() {
        let log = Box<[String]>([])
        let graph = layout(
            Menu("Actions") {
                Button("Rename") { log.value.append("rename") }
                Button("Delete", role: .destructive) { log.value.append("delete") }
            },
            width: 400, height: 400
        )
        let label = graph.textFrames["Actions"] ?? .zero
        graph.tap(at: CGPoint(x: label.midX, y: label.midY))
        #expect(graph.isPresentingPopup)
        let delete = graph.textFrames["Delete"] ?? .zero
        graph.tap(at: CGPoint(x: delete.midX, y: delete.midY))
        graph.update()
        #expect(log.value == ["delete"])
        #expect(!graph.isPresentingPopup)
        // Escape and taps outside also close it.
        graph.tap(at: CGPoint(x: label.midX, y: label.midY))
        graph.press(.escape)
        graph.update()
        #expect(!graph.isPresentingPopup)
        graph.tap(at: CGPoint(x: label.midX, y: label.midY))
        graph.tap(at: CGPoint(x: 5, y: 5))
        graph.update()
        #expect(!graph.isPresentingPopup)
        #expect(log.value == ["delete"])
    }

    @Test func disclosureGroupExpands() {
        let graph = layout(
            DisclosureGroup("Details") {
                Text("Hidden content")
            }
            .frame(width: 200)
        )
        #expect(!graph.texts.contains("Hidden content"))
        let label = graph.textFrames["Details"] ?? .zero
        graph.tap(at: CGPoint(x: label.midX, y: label.midY))
        graph.update()
        graph.layout(in: graph.size)
        #expect(graph.texts.contains("Hidden content"))
    }

    @Test func progressViewDraws() {
        let graph = layout(ProgressView(value: 0.25).frame(width: 200))
        let fills = graph.displayList().items.filter {
            if case .content(.shape) = $0.value { return true }
            return false
        }
        #expect(fills.count == 2)
        #expect(fills.last?.frame.width == 50)
    }

    // MARK: Clipping

    @Test func clipShapeLimitsHits() {
        let log = Box<[String]>([])
        let graph = layout(
            Color.red
                .frame(width: 100, height: 100)
                .onTapGesture { log.value.append("tap") }
                .clipShape(Circle())
                .probe("circle")
        )
        let frame = graph.frame("circle")
        graph.tap(at: CGPoint(x: frame.minX + 3, y: frame.minY + 3))
        graph.tap(at: CGPoint(x: frame.midX, y: frame.midY))
        #expect(log.value == ["tap"])
        let clips = graph.displayList().items.filter {
            if case .effect(.clip, _) = $0.value { return true }
            return false
        }
        #expect(clips.count == 1)
    }

    @Test func shareLinkUsesTheHostsPicker() {
        let shared = Box<[ShareRequest]>([])
        let graph = layout(ShareLink(item: URL(string: "https://example.com")!, subject: Text("Look")).probe("link"))
        // Set by the host after the graph is made.
        graph.share = { request in
            shared.value.append(request)
            return true
        }
        graph.layout(in: CGSize(width: 400, height: 300))
        let label = graph.textFrames["Share"] ?? .zero
        graph.tap(at: CGPoint(x: label.midX, y: label.midY))
        #expect(shared.value.count == 1)
        #expect(shared.value.first?.items.first as? URL == URL(string: "https://example.com"))
        #expect(shared.value.first?.subject == "Look")
        #expect(shared.value.first?.anchor == graph.frame("link"))
    }

    @Test func shareLinkMenuCopiesAndOpens() {
        let copied = Box<[String]>([])
        let opened = Box<[URL]>([])
        let graph = layout(
            ShareLink("Send", item: URL(string: "https://example.com/page")!)
                .environment(\.openURL, OpenURLAction { opened.value.append($0) }),
            width: 400, height: 300
        )
        graph.clipboard = Clipboard(read: { nil }, write: { copied.value.append($0) })
        let label = graph.textFrames["Send"] ?? .zero
        graph.tap(at: CGPoint(x: label.midX, y: label.midY))
        #expect(graph.isPresentingPopup)
        let copy = graph.textFrames["Copy"] ?? .zero
        graph.tap(at: CGPoint(x: copy.midX, y: copy.midY))
        graph.update()
        #expect(copied.value == ["https://example.com/page"])
        graph.tap(at: CGPoint(x: label.midX, y: label.midY))
        let open = graph.textFrames["Open"] ?? .zero
        graph.tap(at: CGPoint(x: open.midX, y: open.midY))
        graph.update()
        #expect(opened.value == [URL(string: "https://example.com/page")!])
    }
}

extension ViewGraph {

    /// The frame of each text in the display list, by its string, in the
    /// window: after scroll offsets.
    var textFrames: [String: CGRect] {
        var result: [String: CGRect] = [:]
        func collect(_ list: DisplayList, offset: CGPoint) {
            for item in list.items {
                switch item.value {
                case let .content(.text(text)):
                    result[text.string] = item.frame.offsetBy(dx: -offset.x, dy: -offset.y)
                case let .effect(.scroll(effect), nested):
                    collect(nested, offset: CGPoint(x: offset.x + effect.offset.x, y: offset.y + effect.offset.y))
                case let .effect(_, nested):
                    collect(nested, offset: offset)
                case .content:
                    break
                }
            }
        }
        collect(displayList(), offset: CGPoint(x: 0, y: 0))
        return result
    }
}

@MainActor
@Suite struct PointerStyleTests {

    @Test func innermostStyleUnderThePointerWins() {
        let graph = layout(
            VStack(spacing: 0) {
                Color.red.frame(width: 100, height: 40)
                    .pointerStyle(.grabIdle)
                    .probe("grab")
                Color.blue.frame(width: 100, height: 40)
                    .overlay { Color.green.frame(width: 20, height: 20).pointerStyle(.zoomIn).probe("zoom") }
                    .pointerStyle(.rowResize)
                    .probe("row")
                TextField("Name", text: .constant("")).frame(width: 100).probe("field")
                Link("Docs", destination: URL(string: "https://example.com")!).probe("link")
                Color.gray.frame(width: 100, height: 40).probe("plain")
            }
        )
        func style(at identifier: String, dx: CGFloat = 0) -> PointerStyle? {
            let frame = graph.frame(identifier)
            graph.hover(at: CGPoint(x: frame.midX + dx, y: frame.midY))
            return graph.pointerStyle
        }
        #expect(style(at: "grab") == .grabIdle)
        #expect(style(at: "zoom") == .zoomIn)
        #expect(style(at: "row", dx: 30) == .rowResize)
        #expect(style(at: "field") == .horizontalText)
        #expect(style(at: "link") == .link)
        #expect(style(at: "plain") == nil)
        graph.hover(at: CGPoint(x: 5, y: 5))
        #expect(graph.pointerStyle == nil)
    }

    @Test func splitViewDividersShowResizePointers() {
        let graph = layout(
            NavigationSplitView {
                Color.red
            } detail: {
                Color.blue
            },
            width: 800, height: 400
        )
        graph.hover(at: CGPoint(x: 240.5, y: 200))
        #expect(graph.pointerStyle == .columnResize)
        graph.hover(at: CGPoint(x: 400, y: 200))
        #expect(graph.pointerStyle == nil)
    }
}

