import Testing
import Foundation
import Silica
@testable import CacaoCompositor

@Suite struct RasterizerTests {

    @Test func backend() {
        #if os(macOS)
        #expect(Rasterizer.backendName == "CoreGraphics")
        #elseif os(Linux)
        #expect(Rasterizer.backendName == "Cairo")
        #endif
    }

    /// Fills a bitmap with opaque red and reads back its pixels, which are
    /// premultiplied RGBA.
    @Test func fillBitmap() throws {
        let image = try #require(try Rasterizer.draw(size: CGSize(width: 8, height: 4)) { context in
            context.setFillColor(red: 1, green: 0, blue: 0, alpha: 1)
            context.addRect(CGRect(x: 0, y: 0, width: 8, height: 4))
            context.fillPath()
        })
        #expect(image.width == 8)
        #expect(image.height == 4)
        let pixel = Array(image.data.prefix(4))
        #expect(pixel == [255, 0, 0, 255])
    }
}
