import CacaoRender
import Foundation
#if canImport(CoreGraphics)
import CoreGraphics
#endif
import Testing
@testable import CacaoCompositor

@MainActor
@Suite struct BackdropTests {

    private func list(_ backdrop: BackdropContent, frame: CGRect) -> DisplayList {
        DisplayList(items: [
            DisplayList.Item(frame: frame, identity: 1, version: 0, value: .content(.backdrop(backdrop))),
        ])
    }

    private func make() -> (Compositor, RecordingBackend) {
        let backend = RecordingBackend()
        return (Compositor(backend: backend, textEngine: SilicaTextEngine()), backend)
    }

    // MARK: Blur

    /// Left half black, right half white.
    private func halves(width: Int, height: Int) -> Data {
        var pixels = Data(count: width * height * 4)
        for y in 0..<height {
            for x in 0..<width {
                let value: UInt8 = x < width / 2 ? 0 : 255
                let at = (y * width + x) * 4
                pixels[at] = value
                pixels[at + 1] = value
                pixels[at + 2] = value
                pixels[at + 3] = 255
            }
        }
        return pixels
    }

    @Test func blurringSpreadsAnEdge() {
        let blurred = BackdropBlur.blur(
            pixels: halves(width: 64, height: 16), width: 64, height: 16, bytesPerRow: 64 * 4,
            origin: (0, 0), sigma: 6, saturation: 1, rounding: nil
        )
        #expect(blurred.shrink == 1)
        #expect(blurred.width == 64)
        let row = (0..<blurred.width).map { blurred.pixels[(8 * blurred.width + $0) * 4] }
        // Black at one end, white at the other, and gray between, rising.
        #expect(row[0] == 0)
        #expect(row[63] == 255)
        #expect(row[31] > 60)
        #expect(row[31] < 200)
        #expect(zip(row, row.dropFirst()).allSatisfy { $0 <= $1 })
        // Opaque.
        #expect(blurred.pixels[3] == 255)
    }

    @Test func aWideBlurShrinksThePixels() {
        let blurred = BackdropBlur.blur(
            pixels: halves(width: 64, height: 16), width: 64, height: 16, bytesPerRow: 64 * 4,
            origin: (0, 0), sigma: 24, saturation: 1, rounding: nil
        )
        #expect(blurred.shrink == 4)
        #expect(blurred.width == 16)
        #expect(blurred.height == 4)
        #expect(blurred.pixels.count == 16 * 4 * 4)
    }

    @Test func saturationZeroMakesGray() {
        var pixels = Data(count: 8 * 8 * 4)
        for index in 0..<64 {
            pixels[index * 4] = 255
            pixels[index * 4 + 3] = 255
        }
        let blurred = BackdropBlur.blur(
            pixels: pixels, width: 8, height: 8, bytesPerRow: 32,
            origin: (0, 0), sigma: 2, saturation: 0, rounding: nil
        )
        let (r, g, b) = (blurred.pixels[0], blurred.pixels[1], blurred.pixels[2])
        #expect(r == g)
        #expect(g == b)
        // Red's luminance.
        #expect(abs(Int(r) - 54) <= 1)
    }

    @Test func roundedCornersAreTransparent() {
        let pixels = Data(repeating: 255, count: 40 * 40 * 4)
        let frame = CGRect(x: 0, y: 0, width: 40, height: 40)
        let blurred = BackdropBlur.blur(
            pixels: pixels, width: 40, height: 40, bytesPerRow: 160,
            origin: (0, 0), sigma: 2, saturation: 1, rounding: (frame, 12, [.topLeading])
        )
        func alpha(_ x: Int, _ y: Int) -> UInt8 { blurred.pixels[(y * blurred.width + x) * 4 + 3] }
        // The rounded corner is cut away, premultiplied; the others aren't.
        #expect(alpha(0, 0) == 0)
        #expect(blurred.pixels[0] == 0)
        #expect(alpha(39, 0) == 255)
        #expect(alpha(0, 39) == 255)
        #expect(alpha(20, 20) == 255)
    }

    // MARK: Compositing

    @Test func aBackdropReadsWhatIsBehindItAndDrawsItInItsFrame() {
        let (compositor, backend) = make()
        backend.readback = { x, _ in x < 100 ? (0, 0, 0) : (255, 255, 255) }
        let frame = CGRect(x: 50, y: 20, width: 100, height: 60)
        compositor.render(list(BackdropContent(blurRadius: 8), frame: frame), size: CGSize(width: 200, height: 100), scale: 1)
        #expect(compositor.lastFrame.backdrops == 1)
        // It read past the frame, as far as the blur reaches, within the window.
        let read = try! #require(backend.reads.first)
        #expect(read.minX <= 50 - 12)
        #expect(read.maxX >= 150 + 12)
        #expect(read.minY >= 0)
        #expect(read.maxY <= 100)
        // Drawn where it was read, clipped to the frame.
        let draws = backend.commands.compactMap { command -> CGRect? in
            if case let .draw(_, rect) = command { rect } else { nil }
        }
        #expect(draws == [read])
        #expect(backend.commands.contains(.clip(frame)))
    }

    @Test func itsTextureLastsOneFrame() {
        let (compositor, backend) = make()
        backend.readback = { _, _ in (10, 20, 30) }
        let frame = CGRect(x: 0, y: 0, width: 100, height: 100)
        let size = CGSize(width: 100, height: 100)
        compositor.render(list(BackdropContent(blurRadius: 8), frame: frame), size: size, scale: 1)
        #expect(backend.liveTextures.count == 1)
        compositor.render(list(BackdropContent(blurRadius: 8), frame: frame), size: size, scale: 1)
        #expect(backend.liveTextures.count == 1)
        compositor.render(DisplayList(), size: size, scale: 1)
        #expect(backend.liveTextures.isEmpty)
    }

    @Test func aBackendThatCannotReadBackDrawsNothing() {
        let (compositor, backend) = make()
        compositor.render(
            list(BackdropContent(blurRadius: 8), frame: CGRect(x: 0, y: 0, width: 50, height: 50)),
            size: CGSize(width: 100, height: 100), scale: 1
        )
        #expect(compositor.lastFrame.backdrops == 0)
        #expect(backend.liveTextures.isEmpty)
    }

    @Test func aBlurTooSmallToSeeIsSkipped() {
        let (compositor, backend) = make()
        backend.readback = { _, _ in (0, 0, 0) }
        compositor.render(
            list(BackdropContent(blurRadius: 0.4), frame: CGRect(x: 0, y: 0, width: 50, height: 50)),
            size: CGSize(width: 100, height: 100), scale: 1
        )
        #expect(backend.reads.isEmpty)
    }
}
