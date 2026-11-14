import Foundation
#if canImport(CoreGraphics)
import CoreGraphics
#endif
import Testing
@testable import Cacao
@testable import CacaoCompositor
import Silica

@MainActor
@Suite struct TextRenderingTests {

    /// The rows and columns that have ink in a premultiplied RGBA image.
    static func inkBounds(_ image: Silica.CGImage) -> CGRect? {
        var minX = Int.max, minY = Int.max, maxX = -1, maxY = -1
        image.data.withUnsafeBytes { bytes in
            for y in 0..<image.height {
                for x in 0..<image.width where bytes[y * image.bytesPerRow + x * 4 + 3] > 64 {
                    minX = min(minX, x); maxX = max(maxX, x)
                    minY = min(minY, y); maxY = max(maxY, y)
                }
            }
        }
        guard maxX >= 0 else { return nil }
        return CGRect(x: minX, y: minY, width: maxX - minX + 1, height: maxY - minY + 1)
    }

    static func text(_ string: String, size: CGFloat) -> ResolvedText {
        ResolvedText(
            runs: [ResolvedText.Run(
                string: string,
                font: Font.system(size: size).resolve(),
                color: Color.Resolved(red: 0, green: 0, blue: 0)
            )],
            alignment: .leading,
            lineLimit: nil
        )
    }

    @Test func systemFontLoads() {
        let engine = SilicaTextEngine()
        #expect(engine.font(for: Font.body.resolve()) != nil)
    }

    @Test func measuresWithRealMetrics() {
        let engine = SilicaTextEngine()
        let layout = engine.layout(Self.text("Hello", size: 20), in: .unspecified)
        #expect(layout.size.width > 20 && layout.size.width < 100)
        #expect(layout.size.height > 18 && layout.size.height < 32)
        #expect(layout.firstBaseline > 10 && layout.firstBaseline < layout.size.height)
    }

    @Test func wrapsAtSpaces() {
        let engine = SilicaTextEngine()
        let text = Self.text("Hello world again", size: 20)
        let single = engine.layout(text, in: .unspecified)
        let wrapped = engine.layout(text, in: ProposedViewSize(width: single.size.width / 2, height: nil))
        #expect(wrapped.lines.count >= 2)
        #expect(wrapped.size.width <= single.size.width / 2 + 0.5)
    }

    /// Glyphs are upright and sit on the baseline, within the measured frame.
    @Test func drawsGlyphsInsideTheFrame() throws {
        let engine = SilicaTextEngine()
        let text = Self.text("H", size: 40)
        let layout = engine.layout(text, in: .unspecified)
        let image = try #require(Rasterizer.rasterize(.text(text), size: layout.size, scale: 1, textEngine: engine))
        let ink = try #require(Self.inkBounds(image))
        // An "H" spans from its cap height down to the baseline.
        #expect(ink.minY > 0)
        #expect(abs(ink.maxY - layout.firstBaseline) <= 2, "ink \(ink), baseline \(layout.firstBaseline)")
        #expect(ink.height > 20)
    }

    /// A canvas's drawing, with its transforms, opacity and clips, in pixels.
    @Test func rasterizesCanvasDrawing() throws {
        let red = Color.Resolved(red: 1, green: 0, blue: 0)
        var moved = DrawingState()
        moved.transform = .translation(10, 0)
        var faded = DrawingState()
        faded.opacity = 0.5
        var clipped = DrawingState()
        clipped.clips = [(Path(CGRect(x: 0, y: 0, width: 5, height: 20)), .identity, false)]
        let drawing = DrawingContent(operations: [
            .shape(ShapeContent(path: Path(CGRect(x: 0, y: 0, width: 10, height: 10)), color: red, drawing: .fill(FillStyle())), moved),
            .shape(ShapeContent(path: Path(CGRect(x: 0, y: 10, width: 10, height: 10)), color: red, drawing: .fill(FillStyle())), faded),
            .shape(ShapeContent(path: Path(CGRect(x: 0, y: 0, width: 10, height: 10)), color: red, drawing: .fill(FillStyle())), clipped),
        ])
        let image = try #require(Rasterizer.rasterize(
            .drawing(drawing),
            size: CGSize(width: 20, height: 20),
            scale: 1,
            textEngine: SilicaTextEngine()
        ))
        func pixel(_ x: Int, _ y: Int) -> [UInt8] {
            image.data.withUnsafeBytes { bytes in
                (0..<4).map { bytes[y * image.bytesPerRow + x * 4 + $0] }
            }
        }
        // Moved right by 10 points.
        #expect(pixel(15, 5) == [255, 0, 0, 255])
        // Clipped to the leading 5 points.
        #expect(pixel(2, 5) == [255, 0, 0, 255])
        #expect(pixel(7, 5)[3] == 0)
        // Half opacity, premultiplied.
        let half = pixel(5, 15)
        #expect(abs(Int(half[3]) - 128) <= 2)
    }
}

extension TextRenderingTests {

    @Test func drawsUnderlineAndStrikethrough() throws {
        let engine = SilicaTextEngine()
        var text = Self.text("ace", size: 40)
        let layout = engine.layout(text, in: .unspecified)
        func ink(_ text: ResolvedText) throws -> (bounds: CGRect, count: Int) {
            let image = try #require(Rasterizer.rasterize(.text(text), size: layout.size, scale: 1, textEngine: engine))
            var count = 0
            image.data.withUnsafeBytes { bytes in
                for y in 0..<image.height {
                    for x in 0..<image.width where bytes[y * image.bytesPerRow + x * 4 + 3] > 64 { count += 1 }
                }
            }
            return (try #require(Self.inkBounds(image)), count)
        }
        let plain = try ink(text)
        let black = Color.Resolved(red: 0, green: 0, blue: 0)
        text.runs[0].underline = ResolvedText.Line(color: black, pattern: .solid)
        let underlined = try ink(text)
        // A line across the run, under the letters, which have no descenders.
        #expect(underlined.bounds.maxY > plain.bounds.maxY)
        #expect(underlined.bounds.minY == plain.bounds.minY)
        #expect(underlined.bounds.width >= plain.bounds.width)
        text.runs[0].underline = nil
        text.runs[0].strikethrough = ResolvedText.Line(color: black, pattern: .solid)
        let struck = try ink(text)
        // Through the letters: no taller, but more ink.
        #expect(struck.bounds.maxY == plain.bounds.maxY)
        #expect(struck.count > plain.count + 20)
    }

    @Test func trackingAndLineSpacingChangeLayout() {
        let engine = SilicaTextEngine()
        var text = Self.text("abc\ndef", size: 20)
        let plain = engine.layout(text, in: .unspecified)
        text.runs[0].tracking = 4
        text.lineSpacing = 6
        let spaced = engine.layout(text, in: .unspecified)
        #expect(abs(spaced.size.width - (plain.size.width + 12)) <= 1)
        #expect(spaced.size.height == plain.size.height + 6)
        #expect(spaced.lastBaseline == plain.lastBaseline + 6)
    }
}
