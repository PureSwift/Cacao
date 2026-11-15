//
//  TextField.swift
//  Cacao
//
//  Created by Alsey Coleman Miller on 11/13/26.
//

import Foundation
#if canImport(CoreGraphics)
import CoreGraphics
#endif

// MARK: - Views

/// A control that displays an editable text interface.
public struct TextField<Label: View>: View {

    internal let text: Binding<String>

    internal let prompt: Text?

    internal let label: Label

    internal let axis: Axis

    public var body: some View {
        _TextInput(
            text: text,
            placeholder: prompt ?? (label as? Text),
            isSecure: false,
            isMultiline: axis == .vertical,
            fillsHeight: false
        )
    }
}

extension TextField where Label == Text {

    /// Creates a text field with a text label generated from a localized
    /// title string.
    public init(_ titleKey: LocalizedStringKey, text: Binding<String>, prompt: Text? = nil) {
        self.text = text
        self.prompt = prompt
        self.label = Text(titleKey)
        self.axis = .horizontal
    }

    /// Creates a text field with a text label generated from a title string.
    @_disfavoredOverload
    public init<S: StringProtocol>(_ title: S, text: Binding<String>, prompt: Text? = nil) {
        self.text = text
        self.prompt = prompt
        self.label = Text(title)
        self.axis = .horizontal
    }

    /// Creates a text field with a preferred axis: vertical text fields
    /// wrap and grow with their text.
    public init(_ titleKey: LocalizedStringKey, text: Binding<String>, axis: Axis) {
        self.text = text
        self.prompt = nil
        self.label = Text(titleKey)
        self.axis = axis
    }
}

extension TextField {

    /// Creates a text field with a prompt and a custom label.
    public init(text: Binding<String>, prompt: Text? = nil, @ViewBuilder label: () -> Label) {
        self.text = text
        self.prompt = prompt
        self.label = label()
        self.axis = .horizontal
    }
}

/// A control into which people securely enter private text.
public struct SecureField<Label: View>: View {

    internal let text: Binding<String>

    internal let prompt: Text?

    internal let label: Label

    public var body: some View {
        _TextInput(text: text, placeholder: prompt ?? (label as? Text), isSecure: true, isMultiline: false, fillsHeight: false)
    }
}

extension SecureField where Label == Text {

    /// Creates a secure field with a prompt generated from a localized
    /// title string.
    public init(_ titleKey: LocalizedStringKey, text: Binding<String>, prompt: Text? = nil) {
        self.text = text
        self.prompt = prompt
        self.label = Text(titleKey)
    }

    /// Creates a secure field with a prompt generated from a title string.
    @_disfavoredOverload
    public init<S: StringProtocol>(_ title: S, text: Binding<String>, prompt: Text? = nil) {
        self.text = text
        self.prompt = prompt
        self.label = Text(title)
    }
}

/// A view that can display and edit long-form text.
public struct TextEditor: View {

    internal let text: Binding<String>

    /// Creates a plain text editor.
    public init(text: Binding<String>) {
        self.text = text
    }

    public var body: some View {
        _TextInput(text: text, placeholder: nil, isSecure: false, isMultiline: true, fillsHeight: true)
            .textFieldStyle(.plain)
    }
}

// MARK: - Styles

/// The styles of text fields.
public struct TextFieldStyleKind: Equatable, Sendable {
    internal let name: String
    static let roundedBorder = TextFieldStyleKind(name: "roundedBorder")
    static let plain = TextFieldStyleKind(name: "plain")
}

/// A text field style.
public protocol TextFieldStyle {
    var _kind: TextFieldStyleKind { get }
}

/// The default text field style: a rounded border.
public struct DefaultTextFieldStyle: TextFieldStyle {
    public init() { }
    public var _kind: TextFieldStyleKind { .roundedBorder }
}

/// A text field style with a rounded border.
public struct RoundedBorderTextFieldStyle: TextFieldStyle {
    public init() { }
    public var _kind: TextFieldStyleKind { .roundedBorder }
}

/// A text field style with no decoration.
public struct PlainTextFieldStyle: TextFieldStyle {
    public init() { }
    public var _kind: TextFieldStyleKind { .plain }
}

extension TextFieldStyle where Self == DefaultTextFieldStyle {
    public static var automatic: DefaultTextFieldStyle { DefaultTextFieldStyle() }
}

extension TextFieldStyle where Self == RoundedBorderTextFieldStyle {
    public static var roundedBorder: RoundedBorderTextFieldStyle { RoundedBorderTextFieldStyle() }
}

extension TextFieldStyle where Self == PlainTextFieldStyle {
    public static var plain: PlainTextFieldStyle { PlainTextFieldStyle() }
}

private struct TextFieldStyleKey: EnvironmentKey {
    static let defaultValue = TextFieldStyleKind.roundedBorder
}

extension EnvironmentValues {

    internal var textFieldStyle: TextFieldStyleKind {
        get { self[TextFieldStyleKey.self] }
        set { self[TextFieldStyleKey.self] = newValue }
    }
}

extension View {

    /// Sets the style for text fields within this view.
    public func textFieldStyle<S: TextFieldStyle>(_ style: S) -> some View {
        environment(\.textFieldStyle, style._kind)
    }
}

// MARK: - Editor

/// The editing state of a text input: its selection and scroll position.
@MainActor
internal final class TextEditorState {

    /// The selected range of Unicode scalars; empty for a caret.
    var selection: Range<Int> = 0..<0

    /// The end of the selection that moves when extending it.
    var anchor = 0

    var isFocused = false

    /// How far a single-line field's text is scrolled.
    var scrollX: CGFloat = 0

    /// The width of the last layout, for vertical caret movement.
    var width: CGFloat = 0

    /// The end of the selection that moves: the caret.
    var head = 0

    var caret: Int {
        head
    }

    /// When the caret last moved, from which it blinks.
    var blinkStart: Double = 0

    /// Text and selections to go back to, and forward again.
    var undoStack: [(text: String, selection: Range<Int>)] = []

    var redoStack: [(text: String, selection: Range<Int>)] = []

    /// Whether the last edit was typing at the caret, which further typing
    /// joins in one undo step.
    var isTyping = false

    func select(_ index: Int, extending: Bool) {
        head = index
        if extending {
            selection = min(anchor, index)..<max(anchor, index)
        } else {
            anchor = index
            selection = index..<index
        }
    }
}

/// The text a text input lays out: the text itself, or bullets.
@MainActor
internal struct TextInputContent {

    let scalars: [Unicode.Scalar]

    let resolved: ResolvedText

    let engine: any TextEngine

    let isMultiline: Bool

    /// The ranges of scalars on each line when wrapped to `width`.
    func lineRanges(width: CGFloat) -> [Range<Int>] {
        guard isMultiline else { return [0..<scalars.count] }
        let lines = engine.layout(resolved, in: ProposedViewSize(width: max(width, 1), height: nil)).lines
        var ranges: [Range<Int>] = []
        var position = 0
        for line in lines {
            let count = line.unicodeScalars.count
            let end = min(position + count, scalars.count)
            ranges.append(position..<end)
            position = end
            // Skip the space or newline the line broke at.
            if position < scalars.count, scalars[position] == " " || scalars[position] == "\n" {
                position += 1
            }
        }
        if ranges.isEmpty || (scalars.last == "\n" && position == scalars.count) {
            ranges.append(scalars.count..<scalars.count)
        }
        return ranges
    }

    /// The width of a run of scalars on one line.
    func width(_ range: Range<Int>) -> CGFloat {
        guard !range.isEmpty else { return 0 }
        var text = resolved
        let string = String(String.UnicodeScalarView(scalars[range]))
        text.runs = [ResolvedText.Run(string: string, font: resolved.runs.first!.font, color: resolved.runs.first!.color)]
        return engine.layout(text, in: .unspecified).size.width
    }

    var lineHeight: CGFloat {
        var text = resolved
        text.runs = [ResolvedText.Run(string: "X", font: resolved.runs.first!.font, color: resolved.runs.first!.color)]
        return engine.layout(text, in: .unspecified).size.height
    }

    /// The line and x position of the caret before `index`.
    func position(of index: Int, lines: [Range<Int>]) -> (line: Int, x: CGFloat) {
        for (line, range) in lines.enumerated() where index <= range.upperBound {
            if index >= range.lowerBound {
                return (line, width(range.lowerBound..<index))
            }
        }
        let last = lines.count - 1
        return (last, width(lines[last]))
    }

    /// The scalar index nearest a point in the text's coordinate space.
    func index(at point: CGPoint, lines: [Range<Int>]) -> Int {
        let lineHeight = lineHeight
        let line = min(max(Int(point.y / max(lineHeight, 1)), 0), lines.count - 1)
        return index(atX: point.x, line: lines[line])
    }

    func index(atX x: CGFloat, line range: Range<Int>) -> Int {
        var best = range.lowerBound
        var bestDistance = CGFloat.infinity
        for index in range.lowerBound...range.upperBound {
            let distance = abs(width(range.lowerBound..<index) - x)
            if distance < bestDistance {
                best = index
                bestDistance = distance
            }
        }
        return best
    }
}

// MARK: - Text input view

/// The editable text of text fields and editors: its decoration, text,
/// selection and caret, with keyboard and pointer editing.
internal struct _TextInput: View, PrimitiveView {

    let text: Binding<String>

    let placeholder: Text?

    let isSecure: Bool

    let isMultiline: Bool

    let fillsHeight: Bool

    typealias Body = Never

    static func state(of node: ViewNode) -> TextEditorState {
        if let state = node.dynamicStorage["editor"] as? TextEditorState {
            return state
        }
        let state = TextEditorState()
        node.dynamicStorage["editor"] = state
        return state
    }

    func resolve(in context: ResolveContext) -> Resolution {
        let node = context.node
        let environment = context.environment
        let state = Self.state(of: node)
        let string = text.wrappedValue
        let scalars = Array(string.unicodeScalars)
        let count = scalars.count
        state.selection = min(state.selection.lowerBound, count)..<min(state.selection.upperBound, count)
        state.anchor = min(state.anchor, count)
        state.head = min(state.head, count)
        let displayed = isSecure ? String(repeating: "•", count: count) : string
        let style = environment.textFieldStyle
        let isEnabled = environment.isEnabled
        let resolved = Text(verbatim: displayed).resolve(in: environment)
        let content = TextInputContent(
            scalars: Array(displayed.unicodeScalars),
            resolved: resolved,
            engine: context.graph.textEngine,
            isMultiline: isMultiline
        )
        let insets = style == .roundedBorder
            ? EdgeInsets(top: 4, leading: 6, bottom: 4, trailing: 6)
            : EdgeInsets()

        var children: [ChildView] = []
        if style == .roundedBorder {
            let border = state.isFocused ? Color.accentColor : Color.gray.opacity(0.5)
            children.append(ChildView(key: "background", view: RoundedRectangle(cornerRadius: 6)
                .fill(Color.controlBackground(environment.colorScheme))))
            children.append(ChildView(key: "border", view: RoundedRectangle(cornerRadius: 6)
                .strokeBorder(border, lineWidth: state.isFocused ? 2 : 1)))
        }
        children.append(ChildView(key: "selection", view: _TextOverlay(kind: .selection, content: content, state: state, insets: insets)))
        if displayed.isEmpty, let placeholder {
            children.append(ChildView(key: "placeholder", view: placeholder.foregroundColor(.gray)))
        } else {
            children.append(ChildView(key: "text", view: Text(verbatim: displayed)))
        }
        if state.isFocused {
            children.append(ChildView(key: "caret", view: _TextOverlay(kind: .caret, content: content, state: state, insets: insets)))
        }

        var attributes = NodeAttributes()
        if isEnabled {
            attributes.pointerStyle = .horizontalText
            attributes.focus = focusTarget(node: node, state: state, content: content, environment: environment)
            attributes.drag = DragHandler(
                onChanged: { [weak node] start, location, frame in
                    guard let node else { return }
                    let lines = content.lineRanges(width: state.width)
                    @MainActor func index(_ point: CGPoint) -> Int {
                        content.index(
                            at: CGPoint(
                                x: point.x - frame.minX - insets.leading + state.scrollX,
                                y: point.y - frame.minY - insets.top
                            ),
                            lines: lines
                        )
                    }
                    if start == location {
                        state.select(index(start), extending: false)
                    }
                    state.select(index(location), extending: true)
                    node.invalidate()
                },
                onEnded: { _, _, _ in }
            )
            attributes.contentShape = { Path($0) }
        }
        return Resolution(
            behavior: TextInputBehavior(
                content: content,
                state: state,
                insets: insets,
                isMultiline: isMultiline,
                fillsHeight: fillsHeight
            ),
            children: children,
            attributes: attributes
        )
    }

    private func focusTarget(node: ViewNode, state: TextEditorState, content: TextInputContent, environment: EnvironmentValues) -> FocusTarget {
        let text = self.text
        let isMultiline = self.isMultiline
        let isSecure = self.isSecure
        let onSubmit = environment.onSubmit
        let graph = node.graph
        weak let weakNode = node

        @MainActor func replace(_ range: Range<Int>, with replacement: String, typing: Bool = false) {
            // Typing joins the previous typing in one undo step.
            if !(typing && state.isTyping && range.isEmpty) {
                state.undoStack.append((text.wrappedValue, state.selection))
                if state.undoStack.count > 100 { state.undoStack.removeFirst() }
            }
            state.redoStack.removeAll()
            state.isTyping = typing
            state.blinkStart = graph.time
            var scalars = Array(text.wrappedValue.unicodeScalars)
            let range = min(range.lowerBound, scalars.count)..<min(range.upperBound, scalars.count)
            let inserted = Array(replacement.unicodeScalars)
            scalars.replaceSubrange(range, with: inserted)
            let caret = range.lowerBound + inserted.count
            state.select(caret, extending: false)
            text.wrappedValue = String(String.UnicodeScalarView(scalars))
            weakNode?.invalidate()
        }

        @MainActor func move(_ index: Int, extending: Bool) {
            let index = TextBoundaries(text.wrappedValue).clusterStart(atOrBefore: index)
            state.select(index, extending: extending)
            state.isTyping = false
            state.blinkStart = graph.time
            weakNode?.invalidate()
        }

        /// Restores the text and selection from one stack, saving the
        /// current ones on the other.
        @MainActor func restore(from source: inout [(text: String, selection: Range<Int>)], to destination: inout [(text: String, selection: Range<Int>)]) {
            guard let entry = source.popLast() else { return }
            destination.append((text.wrappedValue, state.selection))
            state.isTyping = false
            text.wrappedValue = entry.text
            state.anchor = entry.selection.lowerBound
            state.head = entry.selection.upperBound
            state.selection = entry.selection
            weakNode?.invalidate()
        }

        return FocusTarget(
            acceptsText: true,
            keyDown: { key, modifiers in
                let extending = modifiers.contains(.shift)
                let count = text.wrappedValue.unicodeScalars.count
                let selection = state.selection
                let lines = content.lineRanges(width: state.width)
                let boundaries = TextBoundaries(isSecure ? String(repeating: "x", count: count) : text.wrappedValue)
                let byWord = modifiers.contains(.wordMovement)
                let byLine = modifiers.contains(.lineMovement)
                switch key {
                case .left where byLine, .home:
                    let line = content.position(of: state.caret, lines: lines).line
                    move(lines[line].lowerBound, extending: extending)
                case .right where byLine, .end:
                    let line = content.position(of: state.caret, lines: lines).line
                    move(lines[line].upperBound, extending: extending)
                case .up where byLine:
                    move(0, extending: extending)
                case .down where byLine:
                    move(count, extending: extending)
                case .left:
                    if byWord {
                        move(boundaries.wordStart(before: state.caret), extending: extending)
                    } else {
                        move(selection.isEmpty || extending ? boundaries.clusterStart(before: state.caret) : selection.lowerBound, extending: extending)
                    }
                case .right:
                    if byWord {
                        move(boundaries.wordEnd(after: state.caret), extending: extending)
                    } else {
                        move(selection.isEmpty || extending ? boundaries.clusterEnd(after: state.caret) : selection.upperBound, extending: extending)
                    }
                case .character("z") where modifiers.contains(.shortcut) && modifiers.contains(.shift),
                     .character("Z") where modifiers.contains(.shortcut),
                     .character("y") where modifiers.contains(.shortcut) && !modifiers.contains(.shift):
                    restore(from: &state.redoStack, to: &state.undoStack)
                case .character("z") where modifiers.contains(.shortcut):
                    restore(from: &state.undoStack, to: &state.redoStack)
                case .up, .down:
                    guard isMultiline else {
                        move(key == .up ? 0 : count, extending: extending)
                        return true
                    }
                    let position = content.position(of: state.caret, lines: lines)
                    let target = position.line + (key == .up ? -1 : 1)
                    guard lines.indices.contains(target) else {
                        move(key == .up ? 0 : count, extending: extending)
                        return true
                    }
                    move(content.index(atX: position.x, line: lines[target]), extending: extending)
                case .backspace:
                    if !selection.isEmpty {
                        replace(selection, with: "")
                    } else if state.caret > 0 {
                        let start = byWord ? boundaries.wordStart(before: state.caret)
                            : byLine ? lines[content.position(of: state.caret, lines: lines).line].lowerBound
                            : boundaries.clusterStart(before: state.caret)
                        replace(start..<state.caret, with: "")
                    }
                case .delete:
                    if !selection.isEmpty {
                        replace(selection, with: "")
                    } else if state.caret < count {
                        let end = byWord ? boundaries.wordEnd(after: state.caret) : boundaries.clusterEnd(after: state.caret)
                        replace(state.caret..<end, with: "")
                    }
                case .returnKey:
                    if isMultiline, !modifiers.contains(.shortcut) {
                        replace(selection, with: "\n")
                    } else {
                        onSubmit?.action()
                    }
                case .character("a") where modifiers.contains(.shortcut):
                    state.anchor = 0
                    state.head = count
                    state.selection = 0..<count
                    weakNode?.invalidate()
                case .character("c") where modifiers.contains(.shortcut):
                    guard !isSecure, !selection.isEmpty else { return true }
                    let scalars = Array(text.wrappedValue.unicodeScalars)[selection]
                    graph.clipboard?.write(String(String.UnicodeScalarView(scalars)))
                case .character("x") where modifiers.contains(.shortcut):
                    guard !isSecure, !selection.isEmpty else { return true }
                    let scalars = Array(text.wrappedValue.unicodeScalars)[selection]
                    graph.clipboard?.write(String(String.UnicodeScalarView(scalars)))
                    replace(selection, with: "")
                case .character("v") where modifiers.contains(.shortcut):
                    guard var pasted = graph.clipboard?.read() else { return true }
                    if !isMultiline {
                        pasted = pasted.replacingOccurrences(of: "\n", with: " ")
                    }
                    replace(selection, with: pasted)
                default:
                    return false
                }
                return true
            },
            insertText: { string in
                var string = string
                if !isMultiline {
                    string = string.replacingOccurrences(of: "\n", with: " ")
                }
                replace(state.selection, with: string, typing: true)
            },
            focusChanged: { isFocused in
                state.isFocused = isFocused
                state.blinkStart = graph.time
                state.isTyping = false
                if !isFocused {
                    state.select(state.caret, extending: false)
                }
                weakNode?.invalidate()
            }
        )
    }
}

/// Lays out a text input: decoration filling the frame, and the text inset
/// within it, scrolled to keep the caret visible on a single line.
internal struct TextInputBehavior: NodeBehavior {

    let content: TextInputContent

    let state: TextEditorState

    let insets: EdgeInsets

    let isMultiline: Bool

    let fillsHeight: Bool

    func sizeThatFits(_ proposal: ProposedViewSize, node: ViewNode) -> CGSize {
        let lineHeight = content.lineHeight
        let width = proposal.width.flatMap { $0.isFinite ? $0 : nil }
            ?? max(content.width(0..<content.scalars.count) + insets.horizontal + 2, 120)
        var height = lineHeight
        if isMultiline {
            let lines = content.lineRanges(width: width - insets.horizontal).count
            height = CGFloat(max(lines, 1)) * lineHeight
        }
        height += insets.vertical
        if fillsHeight, let proposed = proposal.height, proposed.isFinite {
            height = max(height, proposed)
        }
        return CGSize(width: width, height: height)
    }

    func placeChildren(in bounds: CGRect, proposal: ProposedViewSize, node: ViewNode) {
        let inner = CGRect(
            x: bounds.minX + insets.leading,
            y: bounds.minY + insets.top,
            width: max(bounds.width - insets.horizontal, 0),
            height: max(bounds.height - insets.vertical, 0)
        )
        state.width = inner.width
        if !isMultiline {
            // Keep the caret within the visible width.
            let caretX = content.position(of: state.caret, lines: content.lineRanges(width: inner.width)).x
            if caretX - state.scrollX > inner.width - 2 {
                state.scrollX = caretX - inner.width + 2
            } else if caretX - state.scrollX < 0 {
                state.scrollX = caretX
            }
            state.scrollX = max(0, min(state.scrollX, max(content.width(0..<content.scalars.count) - inner.width + 2, 0)))
        } else {
            state.scrollX = 0
        }
        for (index, child) in node.children.enumerated() {
            guard let proxy = LayoutProxy.combining(node.layoutChildren(ofChildAt: index)) else { continue }
            switch child.key {
            case AnyHashable("background"), AnyHashable("border"):
                proxy.place(at: bounds.origin, proposal: ProposedViewSize(bounds.size))
            case AnyHashable("text"), AnyHashable("placeholder"):
                let proposal = ProposedViewSize(width: isMultiline ? inner.width : nil, height: nil)
                proxy.place(at: CGPoint(x: inner.minX - state.scrollX, y: inner.minY), proposal: proposal)
            default:
                proxy.place(at: inner.origin, proposal: ProposedViewSize(inner.size))
            }
        }
    }

    func displayEffect(node: ViewNode) -> DisplayList.Effect? {
        .clip(ClipEffect(path: Path(CGRect(origin: CGPoint(x: 0, y: 0), size: node.frame.size)), isRectangle: true))
    }
}

/// The caret or selection of a text input, drawn over its text area.
internal struct _TextOverlay: View, PrimitiveView {

    enum Kind {
        case caret
        case selection
    }

    let kind: Kind

    let content: TextInputContent

    let state: TextEditorState

    let insets: EdgeInsets

    /// How long the caret shows, then hides, as it blinks.
    static let blinkInterval = 0.5

    func resolve(in context: ResolveContext) -> Resolution {
        let color = kind == .caret
            ? Color.accentColor.resolve(in: context.environment)
            : Color.accentColor.opacity(0.3).resolve(in: context.environment)
        var isVisible = true
        if kind == .caret {
            // Solid after each edit or move, then blinking.
            let graph = context.node.graph
            let elapsed = max(graph.time - state.blinkStart, 0)
            let phase = Int(elapsed / Self.blinkInterval)
            isVisible = phase % 2 == 0
            graph.scheduleWakeup(context.node, after: Double(phase + 1) * Self.blinkInterval - elapsed)
        }
        return Resolution(behavior: TextOverlayBehavior(kind: kind, content: content, state: state, color: color, isVisible: isVisible))
    }

    typealias Body = Never
}

internal struct TextOverlayBehavior: NodeBehavior {

    let kind: _TextOverlay.Kind

    let content: TextInputContent

    let state: TextEditorState

    let color: Color.Resolved

    var isVisible = true

    func sizeThatFits(_ proposal: ProposedViewSize, node: ViewNode) -> CGSize {
        proposal.replacingUnspecifiedDimensions(by: .zero)
    }

    func displayContent(node: ViewNode) -> DisplayList.Content? {
        guard isVisible else { return nil }
        let lines = content.lineRanges(width: node.frame.width)
        let lineHeight = content.lineHeight
        var path = Path()
        switch kind {
        case .caret:
            guard state.selection.isEmpty else { return nil }
            let position = content.position(of: state.caret, lines: lines)
            path.addRect(CGRect(x: position.x - state.scrollX, y: CGFloat(position.line) * lineHeight, width: 1.5, height: lineHeight))
        case .selection:
            guard !state.selection.isEmpty else { return nil }
            for (line, range) in lines.enumerated() {
                let start = max(range.lowerBound, state.selection.lowerBound)
                let end = min(range.upperBound, state.selection.upperBound)
                guard start < end || (start == end && state.selection.contains(start) && range.upperBound == start && line < lines.count - 1) else {
                    continue
                }
                let minX = content.width(range.lowerBound..<start) - state.scrollX
                let maxX = content.width(range.lowerBound..<end) - state.scrollX
                path.addRect(CGRect(x: minX, y: CGFloat(line) * lineHeight, width: max(maxX - minX, 4), height: lineHeight))
            }
        }
        return path.isEmpty ? nil : .shape(ShapeContent(path: path, color: color, drawing: .fill(FillStyle())))
    }

    func hitTest(_ point: CGPoint, node: ViewNode) -> Bool {
        false
    }
}

// MARK: - Boundaries

/// Where characters (grapheme clusters) and words start and end in text,
/// as offsets in its Unicode scalars.
internal struct TextBoundaries {

    /// The scalar offset where each character starts, then the end.
    let clusters: [Int]

    /// Whether each character is part of a word.
    let isWord: [Bool]

    init(_ string: String) {
        var clusters = [0], isWord: [Bool] = []
        var offset = 0
        for character in string {
            offset += character.unicodeScalars.count
            clusters.append(offset)
            isWord.append(character.isLetter || character.isNumber || character == "_" || character == "'")
        }
        self.clusters = clusters
        self.isWord = isWord
    }

    /// The character containing or starting at an offset.
    private func cluster(at offset: Int) -> Int {
        var low = 0, high = clusters.count - 1
        while low < high {
            let middle = (low + high + 1) / 2
            if clusters[middle] <= offset { low = middle } else { high = middle - 1 }
        }
        return low
    }

    func clusterStart(atOrBefore offset: Int) -> Int {
        clusters[cluster(at: max(0, min(offset, clusters.last!)))]
    }

    func clusterStart(before offset: Int) -> Int {
        let index = cluster(at: offset)
        return clusters[clusters[index] == offset ? max(index - 1, 0) : index]
    }

    func clusterEnd(after offset: Int) -> Int {
        clusters[min(cluster(at: offset) + 1, clusters.count - 1)]
    }

    /// The start of the word before an offset, skipping what isn't words.
    func wordStart(before offset: Int) -> Int {
        var index = cluster(at: offset)
        if clusters[index] == offset { index -= 1 } else if index >= isWord.count { index = isWord.count - 1 }
        while index >= 0, !isWord[index] { index -= 1 }
        while index > 0, isWord[index - 1] { index -= 1 }
        return clusters[max(index, 0)]
    }

    /// The end of the word after an offset, skipping what isn't words.
    func wordEnd(after offset: Int) -> Int {
        var index = cluster(at: offset)
        while index < isWord.count, !isWord[index] { index += 1 }
        while index < isWord.count, isWord[index] { index += 1 }
        return clusters[index]
    }
}
