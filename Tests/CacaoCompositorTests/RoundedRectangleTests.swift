import CacaoRender
import Foundation
#if canImport(CoreGraphics)
import CoreGraphics
#endif
import Testing
@testable import CacaoCompositor

@MainActor
@Suite struct RoundedRectangleTests {

    private func list(_ content: RoundedRectangleContent, frame: CGRect) -> DisplayList {
        DisplayList(items: [
            DisplayList.Item(frame: frame, identity: 1, version: 0, value: .content(.roundedRectangle(content))),
        ])
    }

    private func make() -> (Compositor, RecordingBackend) {
        let backend = RecordingBackend()
        return (Compositor(backend: backend, textEngine: SilicaTextEngine()), backend)
    }

    private let white = ResolvedColor(red: 1, green: 1, blue: 1)

    /// The straight parts are filled and each corner is a texture its
    /// radius square: nothing the size of the rectangle is rasterized.
    @Test func drawsFillsAndCornerTextures() {
        let (compositor, backend) = make()
        compositor.render(list(RoundedRectangleContent(color: white, cornerRadius: 10), frame: CGRect(x: 10, y: 20, width: 100, height: 60)),
                          size: CGSize(width: 200, height: 200), scale: 2)
        // At 2 pixels a point: the rectangle is (20, 40, 200, 120), radius 20.
        let fills = backend.commands.compactMap { if case let .fill(rect) = $0 { rect } else { nil } }
        #expect(fills == [
            CGRect(x: 40, y: 40, width: 160, height: 120),
            CGRect(x: 20, y: 60, width: 20, height: 80),
            CGRect(x: 200, y: 60, width: 20, height: 80),
        ])
        let draws = backend.commands.compactMap { if case let .draw(texture, rect) = $0 { (texture, rect) } else { nil } }
        #expect(draws.map(\.1) == [
            CGRect(x: 20, y: 40, width: 20, height: 20),
            CGRect(x: 200, y: 40, width: 20, height: 20),
            CGRect(x: 20, y: 140, width: 20, height: 20),
            CGRect(x: 200, y: 140, width: 20, height: 20),
        ])
        #expect(Set(draws.map(\.0)).count == 4)
        #expect(backend.texturePixels.values.allSatisfy { $0.width == 20 && $0.pixels.count == 20 * 20 * 4 })
    }

    /// A corner is opaque toward the middle, clear at the outer corner and
    /// partly covered along the arc.
    @Test func aCornerIsAnAntialiasedQuarterCircle() throws {
        let (compositor, backend) = make()
        compositor.render(list(RoundedRectangleContent(color: white, cornerRadius: 8, corners: .topLeading), frame: CGRect(x: 0, y: 0, width: 40, height: 40)),
                          size: CGSize(width: 40, height: 40), scale: 1)
        let (width, pixels) = try #require(backend.texturePixels.values.first)
        #expect(backend.texturePixels.count == 1)
        func alpha(_ x: Int, _ y: Int) -> UInt8 { pixels[(y * width + x) * 4 + 3] }
        #expect(alpha(0, 0) == 0)
        #expect(alpha(7, 7) == 255)
        #expect(alpha(7, 0) == 255)
        #expect(alpha(0, 7) == 255)
        let edge = alpha(2, 2)
        #expect(edge > 0 && edge < 255)
        // Premultiplied: white's channels are its alpha.
        #expect(pixels[(2 * width + 2) * 4] == edge)
    }

    /// Square corners are filled; the texture is made once and kept while
    /// the rectangle is drawn, then destroyed with it.
    @Test func cornersAreKeptThenDestroyed() {
        let (compositor, backend) = make()
        let content = RoundedRectangleContent(color: white, cornerRadius: 6, corners: [.topLeading])
        let frame = CGRect(x: 0, y: 0, width: 30, height: 30)
        compositor.render(list(content, frame: frame), size: CGSize(width: 30, height: 30), scale: 1)
        #expect(backend.commands.filter { if case .fill = $0 { true } else { false } }.count == 6)
        let made = backend.liveTextures
        #expect(made.count == 1)
        compositor.render(list(content, frame: frame), size: CGSize(width: 30, height: 30), scale: 1)
        #expect(backend.liveTextures == made)
        compositor.render(DisplayList(), size: CGSize(width: 30, height: 30), scale: 1)
        #expect(backend.liveTextures.isEmpty)
    }

    /// No radius, or a rectangle too small for one, is one fill.
    @Test func withoutARadiusItIsAFill() {
        let (compositor, backend) = make()
        compositor.render(list(RoundedRectangleContent(color: white, cornerRadius: 0), frame: CGRect(x: 0, y: 0, width: 30, height: 30)),
                          size: CGSize(width: 30, height: 30), scale: 1)
        #expect(backend.commands.filter { $0 != .clip(nil) } == [.fill(CGRect(x: 0, y: 0, width: 30, height: 30))])
    }
}
