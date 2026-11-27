import CacaoRender
import Foundation
import Testing
@testable import CacaoCompositor

@MainActor
@Suite struct TextMeasurementTests {
    func text(_ string: String) -> ResolvedText {
        ResolvedText(runs: [.init(
            string: string,
            font: .init(size: 20),
            color: .init(red: 0, green: 0, blue: 0)
        )], alignment: .leading, lineLimit: nil)
    }

    @Test func proportionalBoundariesAndHitTesting() throws {
        let engine = SilicaTextEngine()
        let value = text("WiW")
        let measured = engine.measure(value, in: .unspecified)
        let line = try #require(measured.lines.first)
        let stops = line.boundaries
        #expect(stops.count == 4)
        #expect(stops[1].x - stops[0].x > stops[2].x - stops[1].x)
        #expect(abs(line.frame.width - engine.layout(value, in: .unspecified).size.width) < 1)
        for stop in stops {
            #expect(measured.offset(nearest: CGPoint(x: stop.x, y: line.baseline)) == stop.offset)
        }
        let middle = (stops[1].x + stops[2].x) / 2
        #expect(measured.offset(nearest: CGPoint(x: middle - 0.01, y: 0)) == 1)
        #expect(measured.offset(nearest: CGPoint(x: middle + 0.01, y: 0)) == 2)
        #expect(measured.offset(nearest: CGPoint(x: -100, y: -100)) == 0)
        #expect(measured.offset(nearest: CGPoint(x: 1000, y: 1000)) == 3)
    }

    @Test func emptyTextHasCaret() throws {
        let result = SilicaTextEngine().measure(text(""), in: .unspecified)
        #expect(result.lines.count == 1)
        let caret = try #require(result.caretRect(for: 0))
        #expect(caret.height > 0)
        #expect(caret.minX == 0)
        #expect(result.offset(nearest: .zero) == 0)
        #expect(result.caretRect(for: 1) == nil)
    }

    @Test func wrapsAndPreservesSourceOffsets() throws {
        let engine = SilicaTextEngine()
        var value = text("Hello world\n\nW\n")
        value.lineSpacing = 4
        let wordWidth = max(
            engine.layout(text("Hello"), in: .unspecified).size.width,
            engine.layout(text("world"), in: .unspecified).size.width
        )
        let proposal = ProposedViewSize(width: wordWidth + 1, height: nil)
        let result = engine.measure(value, in: proposal)
        #expect(result.lines.count == engine.layout(value, in: proposal).lines.count)
        #expect(result.lines.count == 5)
        #expect(result.lines.map { $0.boundaries.first?.offset } == [0, 6, 12, 13, 15])
        for line in result.lines {
            let stop = try #require(line.boundaries.first)
            #expect(result.offset(nearest: CGPoint(x: stop.x, y: line.frame.midY)) == stop.offset)
        }
        #expect(result.lines[1].frame.minY == result.lines[0].frame.height + 4)
    }

    @Test func scalarOffsetsAndAlignment() throws {
        let engine = SilicaTextEngine()
        var value = text("é😀e\u{301}")
        value.alignment = .trailing
        let result = engine.measure(value, in: .init(width: 200, height: nil))
        let line = try #require(result.lines.first)
        #expect(line.boundaries.map(\.offset) == [0, 1, 2, 3, 4])
        #expect(abs(line.frame.maxX - 200) < 0.001)
        #expect(result.caretRect(for: -1) == nil)
        #expect(result.caretRect(for: 5) == nil)
    }

    @Test func truncationOnlyExposesVisibleEdges() throws {
        let engine = SilicaTextEngine()
        var value = text("WWWWWWWW")
        value.lineLimit = 1
        let result = engine.measure(value, in: .init(width: 45, height: nil))
        let line = try #require(result.lines.first)
        #expect(result.lines.count == 1)
        #expect(line.boundaries.last?.offset == 8)
        #expect(result.caretRect(for: 5) == nil)
        #expect(result.offset(nearest: CGPoint(x: 1000, y: 0)) == 8)
    }

    @Test func softWrapUsesNextLineForCaret() throws {
        let engine = SilicaTextEngine()
        let width = engine.layout(text("W"), in: .unspecified).size.width + 0.1
        let result = engine.measure(text("WWW"), in: .init(width: width, height: nil))
        #expect(result.lines.count == 3)
        #expect(result.caretRect(for: 1)?.minY == result.lines[1].frame.minY)
    }
}
