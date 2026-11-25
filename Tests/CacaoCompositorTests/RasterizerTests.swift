import CacaoRender
import Testing
import Foundation
import Silica
@testable import Cacao
@testable import CacaoCompositor

@Suite struct RasterizerTests {

    @Test func backend() {
        #if os(macOS)
        #expect(Rasterizer.backendName == "Quartz")
        #elseif os(Linux)
        #expect(Rasterizer.backendName == "Cairo")
        #endif
    }

    /// Fills a bitmap with opaque red and reads back its pixels, which are
    /// premultiplied RGBA.
    @Test func fillBitmap() throws {
        let image = try #require(try Rasterizer.draw(size: CGSize(width: 8, height: 4)) { context in
            context.setFillColor(red: 1, green: 0, blue: 0, alpha: 1)
            context.addRect(Silica.Rect(x: 0, y: 0, width: 8, height: 4))
            context.fillPath()
        })
        #expect(image.width == 8)
        #expect(image.height == 4)
        let pixel = Array(image.data.prefix(4))
        #expect(pixel == [255, 0, 0, 255])
    }

    /// An image made from pixels decodes to them, and a tint keeps their
    /// alpha.
    @Test func decodePixels() throws {
        let pixels = Data([255, 0, 0, 255, 0, 0, 128, 128])
        let source = ImageSource(pixels: ImageSource.Pixels(data: pixels, bytesPerRow: 8), width: 2, height: 1, scale: 1)
        #expect(source.size == CGSize(width: 2, height: 1))
        let image = try #require(Rasterizer.decode(ImageContent(source: source, tint: nil, interpolation: .none)))
        #expect(image.width == 2 && image.height == 1)
        #expect(Array(image.data.prefix(8)) == Array(pixels))
        let white = Color.Resolved(red: 1, green: 1, blue: 1, opacity: 1)
        let tinted = try #require(Rasterizer.decode(ImageContent(source: source, tint: white, interpolation: .none)))
        #expect(Array(tinted.data.prefix(8)) == [255, 255, 255, 255, 128, 128, 128, 128])
    }
}
