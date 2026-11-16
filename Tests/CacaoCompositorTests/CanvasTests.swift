import Foundation
#if canImport(CoreGraphics)
import CoreGraphics
#endif
import Testing
@testable import Cacao
@testable import CacaoCompositor
import Silica

@MainActor
@Suite struct CanvasTests {

    let engine = SilicaTextEngine()

    /// A canvas's drawing, rasterized at 1 pixel a point.
    func render(size: CGSize = CGSize(width: 40, height: 40), _ renderer: @escaping (inout GraphicsContext, CGSize) -> Void) throws -> Silica.CGImage {
        try render(Canvas(renderer: renderer).frame(width: size.width, height: size.height), size: size)
    }

    func render<V: View>(_ view: V, size: CGSize) throws -> Silica.CGImage {
        let graph = ViewGraph(rootView: view, textEngine: engine)
        graph.layout(in: size)
        let content = try #require(graph.displayList().items.compactMap { item -> DisplayList.Content? in
            if case let .content(content) = item.value, case .drawing = content { return content }
            return nil
        }.first)
        return try #require(Rasterizer.rasterize(content, size: size, scale: 1, textEngine: engine))
    }

    func pixel(_ image: Silica.CGImage, _ x: Int, _ y: Int) -> [Int] {
        image.data.withUnsafeBytes { (bytes: UnsafeRawBufferPointer) in
            let base = y * image.bytesPerRow + x * 4
            return (0..<4).map { (index: Int) -> Int in Int(bytes[base + index]) }
        }
    }

    static let red = Color(red: 1, green: 0, blue: 0)
    static let blue = Color(red: 0, green: 0, blue: 1)

    @Test func blendModesBlendWithWhatsBelow() throws {
        let image = try render { context, size in
            context.fill(Path(CGRect(x: 0, y: 0, width: 40, height: 40)), with: .color(Color(red: 1, green: 1, blue: 0)))
            context.blendMode = .multiply
            context.fill(Path(CGRect(x: 0, y: 0, width: 20, height: 40)), with: .color(Color(red: 0, green: 1, blue: 1)))
            context.blendMode = .destinationOut
            context.fill(Path(CGRect(x: 30, y: 0, width: 10, height: 40)), with: .color(.black))
        }
        // Yellow multiplied by cyan is green.
        #expect(pixel(image, 10, 10) == [0, 255, 0, 255])
        #expect(pixel(image, 25, 10) == [255, 255, 0, 255])
        // Destination out erases.
        #expect(pixel(image, 35, 10)[3] == 0)
    }

    @Test func layersCompositeAsOne() throws {
        let image = try render { context, size in
            context.opacity = 0.5
            context.drawLayer { layer in
                layer.fill(Path(CGRect(x: 0, y: 0, width: 30, height: 30)), with: .color(Self.red))
                layer.fill(Path(CGRect(x: 10, y: 10, width: 30, height: 30)), with: .color(Self.red))
            }
        }
        // The overlap is no more opaque than the rest.
        let single = pixel(image, 5, 5), overlap = pixel(image, 20, 20)
        #expect(abs(single[3] - 128) <= 2)
        #expect(abs(overlap[3] - single[3]) <= 1)
    }

    @Test func filtersShadowBlurAndRecolor() throws {
        let shadowed = try render { context, size in
            context.addFilter(.shadow(color: .black, radius: 0, x: 10, y: 0))
            context.fill(Path(CGRect(x: 0, y: 0, width: 20, height: 20)), with: .color(Self.red))
        }
        #expect(pixel(shadowed, 5, 5) == [255, 0, 0, 255])
        // The shadow shows beside the square, under where it doesn't cover.
        #expect(pixel(shadowed, 25, 5)[3] > 200 && pixel(shadowed, 25, 5)[0] < 20)
        let blurred = try render { context, size in
            context.addFilter(.blur(radius: 4))
            context.fill(Path(CGRect(x: 10, y: 10, width: 20, height: 20)), with: .color(Self.red))
        }
        // Soft edges: partly opaque outside the square.
        let edge = pixel(blurred, 8, 20)[3]
        #expect(edge > 10 && edge < 200)
        let recolored = try render { context, size in
            context.addFilter(.colorMultiply(Color(red: 0, green: 1, blue: 1)))
            context.addFilter(.grayscale(1))
            context.fill(Path(CGRect(x: 0, y: 0, width: 40, height: 40)), with: .color(Color(red: 1, green: 1, blue: 1)))
        }
        let gray = pixel(recolored, 5, 5)
        #expect(gray[0] == gray[1] && gray[1] == gray[2] && gray[0] > 150)
    }

    @Test func clipsInvertAndClipToLayers() throws {
        let image = try render { context, size in
            var inverted = context
            inverted.clip(to: Path(CGRect(x: 0, y: 0, width: 20, height: 40)), options: .inverse)
            inverted.fill(Path(CGRect(x: 0, y: 0, width: 40, height: 20)), with: .color(Self.red))
            var masked = context
            masked.clipToLayer { layer in
                layer.fill(Path(ellipseIn: CGRect(x: 0, y: 20, width: 20, height: 20)), with: .color(.black))
            }
            masked.fill(Path(CGRect(x: 0, y: 20, width: 40, height: 20)), with: .color(Self.blue))
        }
        #expect(pixel(image, 5, 5)[3] == 0)
        #expect(pixel(image, 30, 5) == [255, 0, 0, 255])
        // Within the layer's circle only.
        #expect(pixel(image, 10, 30) == [0, 0, 255, 255])
        #expect(pixel(image, 1, 21)[3] == 0)
        #expect(pixel(image, 30, 30)[3] == 0)
    }

    @Test func drawsTaggedSymbolsAndSystemImages() throws {
        let canvas = Canvas { context, size in
            if let dot = context.resolveSymbol(id: "dot") {
                #expect(dot.size == CGSize(width: 10, height: 10))
                context.draw(dot, at: CGPoint(x: 10, y: 10))
                context.draw(dot, in: CGRect(x: 20, y: 20, width: 20, height: 20))
            }
            #expect(context.resolveSymbol(id: "missing") == nil)
        } symbols: {
            Self.red.frame(width: 10, height: 10).tag("dot")
        }
        let image = try render(canvas.frame(width: 40, height: 40), size: CGSize(width: 40, height: 40))
        #expect(pixel(image, 10, 10) == [255, 0, 0, 255])
        #expect(pixel(image, 2, 2)[3] == 0)
        #expect(pixel(image, 38, 38) == [255, 0, 0, 255])
        let star = try render { context, size in
            var shaded = context.resolve(Image(systemName: "star.fill"))
            shaded.shading = .color(Self.blue)
            context.draw(shaded, in: CGRect(x: 0, y: 0, width: 40, height: 40))
        }
        #expect(pixel(star, 20, 22)[2] > 200)
        #expect(pixel(star, 1, 39)[3] == 0)
    }

    @Test func resolvedTextMeasuresAndDraws() throws {
        var measured = CGSize.zero
        let image = try render(size: CGSize(width: 120, height: 40)) { context, size in
            var text = context.resolve(Text("Hi").font(.system(size: 20)))
            measured = text.measure(in: size)
            text.shading = .color(Self.blue)
            context.draw(text, at: CGPoint(x: 0, y: 0), anchor: .topLeading)
        }
        #expect(measured.width > 10 && measured.height > 15)
        let ink = TextRenderingTests.inkBounds(image)
        #expect(ink != nil)
        if let ink {
            let inked = pixel(image, Int(ink.midX), Int(ink.midY))
            #expect(inked[0] < 60)
        }
    }

    @Test func tiledImagesRepeat() throws {
        let pixels = Data([255, 0, 0, 255, 0, 0, 255, 255])
        let png = try #require(Rasterizer.encodePNG(width: 2, height: 1, bytesPerRow: 8, pixels: pixels))
        let tile = Image(pngData: png)
        let image = try render { context, size in
            context.fill(Path(CGRect(x: 0, y: 0, width: 40, height: 40)), with: .tiledImage(tile, scale: 5))
        }
        // Each tile is 10 by 5: red then blue, again and again.
        #expect(pixel(image, 2, 2)[0] > 200)
        #expect(pixel(image, 7, 2)[2] > 200)
        #expect(pixel(image, 12, 22)[0] > 200)
        #expect(pixel(image, 37, 37)[2] > 200)
    }

    /// An image made from pixels draws them as they are, two pixels a point
    /// at scale 2.
    @Test func pixelImagesDraw() throws {
        // Two rows, top to bottom: red, then blue, with padding after each.
        let pixels = Data([255, 0, 0, 255, 255, 0, 0, 255, 9, 9, 9, 9,
                           0, 0, 255, 255, 0, 0, 255, 255, 9, 9, 9, 9])
        let source = Image(pixels: pixels, width: 2, height: 2, bytesPerRow: 12, scale: 2)
        let image = try render { context, size in
            context.draw(source, in: CGRect(x: 0, y: 0, width: 40, height: 40))
        }
        #expect(pixel(image, 20, 5)[0] > 200)
        #expect(pixel(image, 20, 35)[2] > 200)
        #expect(pixel(image, 20, 35)[0] < 50)
    }
}

extension CanvasTests {

    @Test func rotatesAndScales() throws {
        let image = try render { context, size in
            var rotated = context
            rotated.translateBy(x: 20, y: 0)
            rotated.rotate(by: .degrees(90))
            // Turned a quarter clockwise: x runs down, y runs left.
            rotated.fill(Path(CGRect(x: 0, y: 0, width: 10, height: 5)), with: .color(Self.red))
            var scaled = context
            scaled.translateBy(x: 30, y: 30)
            scaled.scaleBy(x: 2, y: 1)
            scaled.fill(Path(CGRect(x: 0, y: 0, width: 4, height: 4)), with: .color(Self.blue))
        }
        #expect(pixel(image, 17, 5) == [255, 0, 0, 255])
        #expect(pixel(image, 22, 5)[3] == 0)
        #expect(pixel(image, 17, 12)[3] == 0)
        #expect(pixel(image, 36, 32) == [0, 0, 255, 255])
        #expect(pixel(image, 39, 32)[3] == 0)
    }
}
