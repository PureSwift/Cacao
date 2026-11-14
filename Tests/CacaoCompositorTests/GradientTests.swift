import Foundation
#if canImport(CoreGraphics)
import CoreGraphics
#endif
import Testing
@testable import Cacao
@testable import CacaoCompositor
import Silica

@MainActor
@Suite struct GradientTests {

    static func pixel(_ image: Silica.CGImage, _ x: Int, _ y: Int) -> [Int] {
        image.data.withUnsafeBytes { bytes in
            let base = y * image.bytesPerRow + x * 4
            return (0..<4).map { (index: Int) -> Int in Int(bytes[base + index]) }
        }
    }

    static let redToBlue = [
        ResolvedGradientStop(color: Color.Resolved(red: 1, green: 0, blue: 0), location: 0),
        ResolvedGradientStop(color: Color.Resolved(red: 0, green: 0, blue: 1), location: 1),
    ]

    @Test func paintInterpolatesStops() {
        let paint = GradientPaint(stops: Self.redToBlue, geometry: .axial(start: CGPoint(x: 0, y: 0), end: CGPoint(x: 100, y: 0)))
        #expect(paint.color(at: CGPoint(x: -10, y: 0)) == Color.Resolved(red: 1, green: 0, blue: 0))
        #expect(paint.color(at: CGPoint(x: 50, y: 30)) == Color.Resolved(red: 0.5, green: 0, blue: 0.5))
        #expect(paint.color(at: CGPoint(x: 200, y: 0)) == Color.Resolved(red: 0, green: 0, blue: 1))
        let radial = GradientPaint(stops: Self.redToBlue, geometry: .radial(center: CGPoint(x: 0, y: 0), startRadius: 0, endRadius: 10, scaleY: 1))
        #expect(radial.location(at: CGPoint(x: 3, y: 4)) == 0.5)
        let conic = GradientPaint(stops: Self.redToBlue, geometry: .conic(center: CGPoint(x: 0, y: 0), startAngle: 0, endAngle: 2 * .pi))
        #expect(abs(conic.location(at: CGPoint(x: 0, y: 10)) - 0.25) < 0.0001)
    }

    @Test func linearGradientFillsAShape() throws {
        let graph = ViewGraph(
            rootView: Rectangle()
                .fill(LinearGradient(colors: [Color(red: 1, green: 0, blue: 0), Color(red: 0, green: 0, blue: 1)], startPoint: .leading, endPoint: .trailing))
                .frame(width: 100, height: 20),
            textEngine: SilicaTextEngine()
        )
        graph.layout(in: CGSize(width: 100, height: 20))
        let content = try #require(graph.displayList().items.compactMap { item -> ShapeContent? in
            if case let .content(.shape(shape)) = item.value { return shape }
            return nil
        }.first)
        #expect(content.gradient != nil)
        let image = try #require(Rasterizer.rasterize(.shape(content), size: CGSize(width: 100, height: 20), scale: 1, textEngine: SilicaTextEngine()))
        let left = Self.pixel(image, 1, 10), middle = Self.pixel(image, 50, 10), right = Self.pixel(image, 98, 10)
        #expect(left[0] > 240 && left[2] < 15 && left[3] == 255)
        #expect(abs(middle[0] - 127) < 6 && abs(middle[2] - 127) < 6)
        #expect(right[2] > 240 && right[0] < 15)
    }

    @Test func gradientStrokeKeepsTheStrokeShape() throws {
        let content = ShapeContent(
            path: Path(ellipseIn: CGRect(x: 0, y: 0, width: 40, height: 40)),
            color: Color.Resolved(red: 0, green: 0, blue: 0),
            drawing: .stroke(StrokeStyle(lineWidth: 4)),
            gradient: GradientPaint(stops: Self.redToBlue, geometry: .axial(start: CGPoint(x: 0, y: 0), end: CGPoint(x: 40, y: 0)))
        )
        let image = try #require(Rasterizer.rasterize(.shape(content), size: CGSize(width: 40, height: 40), scale: 1, textEngine: SilicaTextEngine()))
        let outset = Int(Rasterizer.outset(of: .shape(content)))
        // The center isn't stroked; the leading edge is red.
        #expect(Self.pixel(image, 20 + outset, 20 + outset)[3] == 0)
        let edge = Self.pixel(image, outset, 20 + outset)
        #expect(edge[3] > 100 && edge[0] > edge[2])
    }

    @Test func canvasFillsWithAGradient() throws {
        let gradient = Gradient(colors: [.red, .blue])
        let drawing = DrawingContent(operations: [
            .shape(ShapeContent(
                path: Path(CGRect(x: 0, y: 0, width: 20, height: 10)),
                color: Color.Resolved(red: 0, green: 0, blue: 0),
                drawing: .fill(FillStyle()),
                gradient: GradientPaint(stops: gradient.resolve(in: EnvironmentValues()), geometry: .axial(start: CGPoint(x: 0, y: 0), end: CGPoint(x: 20, y: 0)))
            ), DrawingState())
        ])
        let image = try #require(Rasterizer.rasterize(.drawing(drawing), size: CGSize(width: 20, height: 20), scale: 1, textEngine: SilicaTextEngine()))
        let left = Self.pixel(image, 1, 5), right = Self.pixel(image, 18, 5)
        #expect(left[0] > 200 && right[2] > 200)
        #expect(Self.pixel(image, 10, 15)[3] == 0)
    }
}

extension GradientTests {

    @Test func canvasStrokesAndVerticalFillsWithAGradient() throws {
        let topToBottom = GradientPaint(stops: Self.redToBlue, geometry: .axial(start: CGPoint(x: 0, y: 0), end: CGPoint(x: 0, y: 40)))
        let drawing = DrawingContent(operations: [
            .shape(ShapeContent(
                path: Path(CGRect(x: 0, y: 0, width: 10, height: 40)),
                color: Color.Resolved(red: 0, green: 0, blue: 0),
                drawing: .fill(FillStyle()),
                gradient: topToBottom
            ), DrawingState()),
            .shape(ShapeContent(
                path: Path { $0.move(to: CGPoint(x: 30, y: 0)); $0.addLine(to: CGPoint(x: 30, y: 40)) },
                color: Color.Resolved(red: 0, green: 0, blue: 0),
                drawing: .stroke(StrokeStyle(lineWidth: 4)),
                gradient: topToBottom
            ), DrawingState()),
        ])
        let image = try #require(Rasterizer.rasterize(.drawing(drawing), size: CGSize(width: 40, height: 40), scale: 1, textEngine: SilicaTextEngine()))
        // Red at the top and blue at the bottom, for both: not flipped.
        let fillTop = Self.pixel(image, 5, 2), fillBottom = Self.pixel(image, 5, 37)
        #expect(fillTop[0] > 200 && fillBottom[2] > 200)
        let strokeTop = Self.pixel(image, 30, 2), strokeBottom = Self.pixel(image, 30, 37)
        #expect(strokeTop[0] > 200 && strokeTop[3] > 200)
        #expect(strokeBottom[2] > 200)
        // Only the stroke's width is drawn.
        #expect(Self.pixel(image, 36, 20)[3] == 0)
    }
}

extension GradientTests {

    @Test func canvasDrawsImagesUpright() throws {
        // Two pixels: red above blue.
        let pixels = Data([255, 0, 0, 255, 0, 0, 255, 255])
        let png = try #require(Rasterizer.encodePNG(width: 1, height: 2, bytesPerRow: 4, pixels: pixels))
        let source = ImageSource(data: png, scale: 1)
        let drawing = DrawingContent(operations: [
            .image(ImageContent(source: source, tint: nil, interpolation: .none), CGRect(x: 0, y: 0, width: 10, height: 20), DrawingState())
        ])
        let image = try #require(Rasterizer.rasterize(.drawing(drawing), size: CGSize(width: 10, height: 20), scale: 1, textEngine: SilicaTextEngine()))
        #expect(Self.pixel(image, 5, 2)[0] > 200)
        #expect(Self.pixel(image, 5, 17)[2] > 200)
    }
}
