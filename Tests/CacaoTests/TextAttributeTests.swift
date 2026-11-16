import Foundation
#if canImport(CoreGraphics)
import CoreGraphics
#endif
import Testing
@testable import Cacao

@MainActor
@Suite struct TextAttributeTests {

    /// The resolved text of the first text item.
    func resolvedText(_ graph: ViewGraph) -> ResolvedText? {
        func find(_ list: DisplayList) -> ResolvedText? {
            for item in list.items {
                switch item.value {
                case let .content(.text(text)): return text
                case .content: continue
                case let .effect(_, nested): if let text = find(nested) { return text }
                }
            }
            return nil
        }
        return find(graph.displayList())
    }

    @Test func decorationsResolveColors() throws {
        let graph = layout(
            (Text("A").underline() + Text("B").strikethrough(color: .red) + Text("C").underline(false))
                .foregroundColor(.blue)
        )
        let runs = try #require(resolvedText(graph)).runs
        let blue = Color.blue.resolve(in: EnvironmentValues())
        #expect(runs[0].underline == ResolvedText.Line(color: blue, pattern: .solid))
        #expect(runs[1].strikethrough?.color == Color.red.resolve(in: EnvironmentValues()))
        #expect(runs[2].underline == nil)
    }

    @Test func viewModifiersApplyToTextInside() throws {
        let graph = layout(
            VStack { Text("Hello") }
                .underline(pattern: .dash)
                .kerning(1)
                .tracking(2)
                .baselineOffset(3)
        )
        let run = try #require(resolvedText(graph)?.runs.first)
        #expect(run.underline?.pattern == .dash)
        #expect(run.tracking == 3)
        #expect(run.baselineOffset == 3)
    }

    @Test func trackingWidensText() {
        // FixedTextEngine: characters are half the font size (17) wide.
        let plain = layout(Text("abcd").fixedSize().probe("text"))
        let tracked = layout(Text("abcd").tracking(2).fixedSize().probe("text"))
        #expect(tracked.frame("text").width == plain.frame("text").width + 8)
    }

    @Test func lineSpacingAddsSpaceBetweenLines() {
        let plain = layout(Text("a\nb\nc").fixedSize().probe("text"))
        let spaced = layout(Text("a\nb\nc").lineSpacing(5).fixedSize().probe("text"))
        #expect(spaced.frame("text").height == plain.frame("text").height + 10)
    }
}

extension TextAttributeTests {

    @Test func gradientTextIsMaskedGradient() {
        let graph = layout(
            Text("Hi").foregroundStyle(LinearGradient(colors: [.red, .blue], startPoint: .leading, endPoint: .trailing))
                .fixedSize()
                .probe("text")
        )
        let plain = layout(Text("Hi").fixedSize().probe("text"))
        #expect(graph.frame("text") == plain.frame("text"))
        let masks = graph.displayList().items.flatMap { item -> [DisplayList.Item] in
            func collect(_ item: DisplayList.Item) -> [DisplayList.Item] {
                guard case let .effect(effect, nested) = item.value else { return [] }
                if case .mask = effect { return [item] }
                return nested.items.flatMap(collect)
            }
            return collect(item)
        }
        #expect(masks.count == 1)
        // Shown once to accessibility.
        #expect(graph.texts.count == 1)
    }

    @Test func truncatedLinesEndInAnEllipsis() {
        let layout = FixedTextEngine().layout(
            ResolvedText(runs: [ResolvedText.Run(string: "abcdefghij", font: Font.body.resolve(), color: Color.Resolved(red: 0, green: 0, blue: 0))], alignment: .leading, lineLimit: 1),
            in: ProposedViewSize(width: 50, height: nil)
        )
        #expect(layout.lines.count == 1)
        #expect(layout.lines[0].hasSuffix("\u{2026}"))
    }
}
