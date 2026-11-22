import CacaoRender
import Foundation
#if canImport(CoreGraphics)
import CoreGraphics
#endif
import Testing
@testable import CacaoCompositor

@MainActor
@Suite struct RoundedClipTests {

    private func make() -> (Compositor, RecordingBackend) {
        let backend = RecordingBackend()
        return (Compositor(backend: backend, textEngine: SilicaTextEngine()), backend)
    }

    private let blue = ResolvedColor(red: 0, green: 0, blue: 1)

    /// A color filling a rounded clip's frame, at 2 pixels a point.
    private func list(radius: CGFloat, corners: RoundedRectangleContent.Corners = .all) -> DisplayList {
        let frame = CGRect(x: 10, y: 20, width: 100, height: 60)
        let content = DisplayList(items: [
            DisplayList.Item(frame: frame, identity: 2, version: 0, value: .content(.color(blue))),
        ])
        let clip = ClipEffect(roundedRectangleOf: frame.size, cornerRadius: radius, corners: corners)
        return DisplayList(items: [
            DisplayList.Item(frame: frame, identity: 1, version: 0, value: .effect(.clip(clip), content)),
        ])
    }

    /// The content is drawn into one layer, whose corners alone are cut
    /// with corner textures; nothing the size of the frame is rasterized.
    @Test func masksOnlyTheCorners() {
        let (compositor, backend) = make()
        compositor.render(list(radius: 10), size: CGSize(width: 200, height: 200), scale: 2)
        let masks = backend.commands.compactMap { if case let .mask(texture, rect) = $0 { (texture, rect) } else { nil } }
        // In the layer's pixels: the frame is (0, 0, 200, 120), radius 20.
        #expect(masks.map(\.1) == [
            CGRect(x: 0, y: 0, width: 20, height: 20),
            CGRect(x: 180, y: 0, width: 20, height: 20),
            CGRect(x: 0, y: 100, width: 20, height: 20),
            CGRect(x: 180, y: 100, width: 20, height: 20),
        ])
        #expect(backend.texturePixels.count == 4)
        #expect(backend.texturePixels.values.allSatisfy { $0.width == 20 })
        let layers = backend.commands.compactMap { if case let .drawLayer(_, rect, _, masked) = $0 { (rect, masked) } else { nil } }
        #expect(layers.count == 1)
        #expect(layers.first?.0 == CGRect(x: 20, y: 40, width: 200, height: 120))
        #expect(layers.first?.1 == false)
        // The order: into the layer, the content, the corners, out.
        let begin = backend.commands.firstIndex { if case .beginLayer = $0 { true } else { false } }
        let fill = backend.commands.firstIndex { if case .fill = $0 { true } else { false } }
        let mask = backend.commands.firstIndex { if case .mask = $0 { true } else { false } }
        let end = backend.commands.firstIndex { $0 == .endLayer }
        #expect(begin! < fill! && fill! < mask! && mask! < end!)
    }

    /// Square corners aren't masked.
    @Test func masksOnlyRoundedCorners() {
        let (compositor, backend) = make()
        compositor.render(list(radius: 10, corners: [.topLeading, .bottomTrailing]), size: CGSize(width: 200, height: 200), scale: 1)
        let masks = backend.commands.compactMap { if case let .mask(_, rect) = $0 { rect } else { nil } }
        #expect(masks == [CGRect(x: 0, y: 0, width: 10, height: 10), CGRect(x: 90, y: 50, width: 10, height: 10)])
    }

    /// A clip partly off the window masks only the corners it shows.
    @Test func cornersOffTheWindowAreSkipped() {
        let (compositor, backend) = make()
        compositor.render(list(radius: 10), size: CGSize(width: 60, height: 200), scale: 1)
        let masks = backend.commands.compactMap { if case let .mask(_, rect) = $0 { rect } else { nil } }
        // The layer is the visible 50 points of the frame's width.
        #expect(masks == [CGRect(x: 0, y: 0, width: 10, height: 10), CGRect(x: 0, y: 50, width: 10, height: 10)])
    }

    /// Any other clip shape still masks with its path.
    @Test func otherShapesMaskWithTheirPath() {
        let (compositor, backend) = make()
        let frame = CGRect(x: 0, y: 0, width: 40, height: 40)
        let content = DisplayList(items: [DisplayList.Item(frame: frame, identity: 2, version: 0, value: .content(.color(blue)))])
        let clip = ClipEffect(path: Path(ellipseIn: CGRect(origin: CGPoint(x: 0, y: 0), size: frame.size)), isRectangle: false)
        compositor.render(DisplayList(items: [DisplayList.Item(frame: frame, identity: 1, version: 0, value: .effect(.clip(clip), content))]),
                          size: CGSize(width: 40, height: 40), scale: 1)
        let masks = backend.commands.compactMap { if case let .mask(_, rect) = $0 { rect } else { nil } }
        #expect(masks == [CGRect(x: 0, y: 0, width: 40, height: 40)])
    }
}

@MainActor
@Suite struct HairlineTests {

    /// A fill thinner than a pixel, which snapping its edges would round
    /// away, is one pixel thick.
    @Test func aHairlineStaysAPixelThick() {
        let backend = RecordingBackend()
        let compositor = Compositor(backend: backend, textEngine: SilicaTextEngine())
        let gray = ResolvedColor(red: 0.5, green: 0.5, blue: 0.5)
        let list = DisplayList(items: [
            // Half a point at 1.25 pixels a point: from 243.75 to 244.375
            // pixels, whose edges both snap to 244.
            DisplayList.Item(frame: CGRect(x: 0, y: 195, width: 40, height: 0.5), identity: 1, version: 0, value: .content(.color(gray))),
            DisplayList.Item(frame: CGRect(x: 10.1, y: 0, width: 0.3, height: 20), identity: 2, version: 0, value: .content(.color(gray))),
        ])
        compositor.render(list, size: CGSize(width: 100, height: 300), scale: 1.25)
        let fills = backend.commands.compactMap { if case let .fill(rect) = $0 { rect } else { nil } }
        #expect(fills == [CGRect(x: 0, y: 244, width: 50, height: 1), CGRect(x: 12, y: 0, width: 1, height: 25)])
    }
}
