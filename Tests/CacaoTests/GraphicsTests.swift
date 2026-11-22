import CacaoRender
import Foundation
#if canImport(CoreGraphics)
import CoreGraphics
#endif
import Testing
@testable import Cacao

@MainActor
@Suite struct GraphicsTests {

    @Test func shapesFillTheirProposal() {
        let graph = layout(
            HStack(spacing: 0) {
                Circle().probe("circle")
                Rectangle().probe("rectangle")
            }
            .frame(width: 200, height: 100),
            width: 200, height: 100
        )
        #expect(graph.frame("circle") == rect(0, 0, 100, 100))
        #expect(graph.frame("rectangle") == rect(100, 0, 100, 100))
    }

    @Test func shapeDisplayContent() {
        let graph = layout(Ellipse().fill(.red).frame(width: 40, height: 20))
        guard case let .content(.shape(shape)) = graph.displayList().items.first?.value else {
            Issue.record("Expected a shape")
            return
        }
        #expect(shape.path.boundingRect == rect(0, 0, 40, 20))
        #expect(shape.drawing == .fill(FillStyle()))
        #expect(shape.color == Color.red.resolve(in: EnvironmentValues()))
    }

    /// A filled rounded rectangle or capsule in a color is a rounded
    /// rectangle the compositor draws on the GPU; stroked, it's a shape.
    @Test func roundedRectangleDisplayContent() {
        let graph = layout(RoundedRectangle(cornerRadius: 8).fill(.red).frame(width: 40, height: 20))
        guard case let .content(.roundedRectangle(rounded)) = graph.displayList().items.first?.value else {
            Issue.record("Expected a rounded rectangle")
            return
        }
        #expect(graph.displayList().items.first?.frame.size == CGSize(width: 40, height: 20))
        #expect(rounded.cornerRadius == 8)
        #expect(rounded.color == Color.red.resolve(in: EnvironmentValues()))
        let capsule = layout(Capsule().fill(.blue).frame(width: 40, height: 20))
        guard case let .content(.roundedRectangle(pill)) = capsule.displayList().items.first?.value else {
            Issue.record("Expected a rounded rectangle")
            return
        }
        #expect(pill.cornerRadius == 10)
        let stroked = layout(RoundedRectangle(cornerRadius: 8).stroke(.red).frame(width: 40, height: 20))
        guard case .content(.shape) = stroked.displayList().items.first?.value else {
            Issue.record("Expected a shape")
            return
        }
    }

    @Test func circlePathIsCentered() {
        let path = Circle().path(in: rect(0, 0, 100, 50))
        #expect(path.boundingRect == rect(25, 0, 50, 50))
        #expect(path.contains(CGPoint(x: 50, y: 25)))
        #expect(!path.contains(CGPoint(x: 26, y: 1)))
    }

    @Test func strokeBorderInsetsByHalfTheLineWidth() {
        let graph = layout(Rectangle().strokeBorder(.blue, lineWidth: 4).frame(width: 40, height: 40))
        guard case let .content(.shape(shape)) = graph.displayList().items.first?.value else {
            Issue.record("Expected a shape")
            return
        }
        #expect(shape.path.boundingRect == rect(2, 2, 36, 36))
        #expect(shape.drawing == .stroke(StrokeStyle(lineWidth: 4)))
    }

    /// A 4×2 opaque red PNG.
    static let png = Data(base64Encoded: "iVBORw0KGgoAAAANSUhEUgAAAAQAAAACCAYAAAB/qH1jAAAAEklEQVR4nGP4z8DwHxkzoAsAAA8hD/EEN8afAAAAAElFTkSuQmCC")!

    @Test func imageNaturalSize() {
        let graph = layout(Image(pngData: Self.png).probe("image"))
        #expect(graph.frame("image").size == CGSize(width: 4, height: 2))
    }

    @Test func imageNaturalSizeAtScale() {
        let graph = layout(Image(pngData: Self.png, scale: 2).probe("image"))
        #expect(graph.frame("image").size == CGSize(width: 2, height: 1))
    }

    @Test func resizableImageScaledToFit() {
        let graph = layout(
            Image(pngData: Self.png).resizable().scaledToFit().frame(width: 100, height: 100).probe("frame"),
            width: 100, height: 100
        )
        let image = graph.displayList().items.compactMap { item -> CGRect? in
            if case .content(.image) = item.value { return item.frame }
            return nil
        }
        #expect(image == [rect(0, 25, 100, 50)])
    }

    @Test func resizableImageScaledToFill() {
        let graph = layout(
            Image(pngData: Self.png).resizable().scaledToFill().frame(width: 100, height: 100),
            width: 100, height: 100
        )
        let image = graph.displayList().items.compactMap { item -> CGRect? in
            if case .content(.image) = item.value { return item.frame }
            return nil
        }
        #expect(image == [rect(-50, 0, 200, 100)])
    }
}
