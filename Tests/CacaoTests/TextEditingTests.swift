import CacaoRender
import Foundation
#if canImport(CoreGraphics)
import CoreGraphics
#endif
import Testing
@testable import Cacao

@MainActor
@Suite struct TextEditingTests {

    func field(_ text: Box<String>) -> ViewGraph {
        let graph = layout(TextField("Name", text: text.binding).frame(width: 300).probe("field"))
        graph.tap("field")
        graph.press(.end)
        return graph
    }

    /// A field 500 points down a scroll view, focused, in a window 600 tall.
    private func fieldInScrollView() -> ViewGraph {
        let text = Box("")
        let graph = layout(
            ScrollView {
                VStack(spacing: 0) {
                    Color.blue.frame(height: 500)
                    TextField("Name", text: text.binding).probe("field")
                    Color.blue.frame(height: 500)
                }
            },
            width: 300, height: 600
        )
        graph.settle()
        graph.tap("field")
        graph.settle()
        return graph
    }

    @Test func aFocusedFieldScrollsBackIntoViewAboveAKeyboard() throws {
        let graph = fieldInScrollView()
        #expect(graph.acceptsTextInput)
        // A keyboard takes the bottom half: the field is below what's left.
        graph.layout(in: CGSize(width: 300, height: 300))
        #expect(try #require(graph.focusedFrame).minY >= 300)
        graph.revealFocusedView(animation: nil)
        graph.layout(in: CGSize(width: 300, height: 300))
        let frame = try #require(graph.focusedFrame)
        #expect(frame.minY >= 0)
        #expect(frame.maxY <= 300 - ViewGraph.focusRevealMargin)
    }

    @Test func aFieldAlreadyInViewStaysWhereItIs() throws {
        let graph = fieldInScrollView()
        let before = try #require(graph.focusedFrame)
        graph.revealFocusedView(animation: nil)
        graph.layout(in: CGSize(width: 300, height: 600))
        #expect(graph.focusedFrame == before)
    }

    @Test func onlyLosingMuchHeightWithATextViewFocusedLooksLikeAKeyboard() {
        let graph = fieldInScrollView()
        #expect(graph.looksLikeKeyboardAppearing(from: 600, to: 300))
        // A window resized a little, or getting taller.
        #expect(!graph.looksLikeKeyboardAppearing(from: 600, to: 560))
        #expect(!graph.looksLikeKeyboardAppearing(from: 300, to: 600))
        // Nothing takes text.
        graph.focus(nil)
        #expect(!graph.looksLikeKeyboardAppearing(from: 600, to: 300))
    }

    @Test func boundariesFollowCharacters() {
        // A flag is two scalars; a family emoji is seven.
        let boundaries = TextBoundaries("a🇫🇷b👨‍👩‍👧‍👦")
        #expect(boundaries.clusters == [0, 1, 3, 4, 11])
        #expect(boundaries.clusterStart(before: 3) == 1)
        #expect(boundaries.clusterEnd(after: 1) == 3)
        #expect(boundaries.clusterStart(atOrBefore: 2) == 1)
        let words = TextBoundaries("one, two  three")
        #expect(words.wordStart(before: 15) == 10)
        #expect(words.wordStart(before: 10) == 5)
        #expect(words.wordEnd(after: 0) == 3)
        #expect(words.wordEnd(after: 3) == 8)
    }

    @Test func backspaceDeletesWholeCharacters() {
        let text = Box("ok🇫🇷")
        let graph = field(text)
        graph.press(.backspace)
        #expect(text.value == "ok")
        graph.type("e\u{301}")
        graph.press(.left)
        graph.type("!")
        // The caret moved over the accented e as one character.
        #expect(text.value == "ok!e\u{301}")
    }

    @Test func wordMovementAndDeletion() {
        let text = Box("hello big world")
        let graph = field(text)
        graph.press(.left, .wordMovement)
        graph.type("wide ")
        #expect(text.value == "hello big wide world")
        graph.press(.backspace, .wordMovement)
        #expect(text.value == "hello big world")
        graph.press(.right, .wordMovement)
        graph.type("!")
        #expect(text.value == "hello big world!")
    }

    @Test func undoJoinsTypingAndRedoes() {
        let text = Box("")
        let graph = field(text)
        graph.type("a")
        graph.type("b")
        graph.type("c")
        graph.press(.backspace)
        #expect(text.value == "ab")
        graph.press(.character("z"), .shortcut)
        #expect(text.value == "abc")
        // The typing undoes as one step.
        graph.press(.character("z"), .shortcut)
        #expect(text.value == "")
        graph.press(.character("z"), [.shortcut, .shift])
        #expect(text.value == "abc")
        graph.press(.character("z"), [.shortcut, .shift])
        #expect(text.value == "ab")
    }

    @Test func caretBlinks() {
        let text = Box("hi")
        let graph = field(text)
        func caretShows() -> Bool {
            graph.displayList().items.contains { item in
                func find(_ item: DisplayList.Item) -> Bool {
                    switch item.value {
                    case let .content(.shape(shape)): shape.path.boundingRect.width == 1.5
                    case .content(.roundedRectangle): item.frame.width == 1.5
                    case .content: false
                    case let .effect(_, nested): nested.items.contains(where: find)
                    }
                }
                return find(item)
            }
        }
        #expect(caretShows())
        graph.advanceAnimations(to: 0.6)
        graph.layout(in: graph.size)
        #expect(!caretShows())
        graph.advanceAnimations(to: 1.1)
        graph.layout(in: graph.size)
        #expect(caretShows())
        // Typing shows it again right away.
        graph.advanceAnimations(to: 1.6)
        graph.type("!")
        #expect(caretShows())
    }
}
