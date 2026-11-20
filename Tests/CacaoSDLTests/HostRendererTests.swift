import CacaoRender
import CacaoSDLRenderer
import CSDL3
import Foundation
#if canImport(CoreGraphics)
import CoreGraphics
#endif
import Testing

@MainActor
@Suite struct HostRendererTests {

    /// A display list drawn with a renderer the test owns, onto a surface
    /// in memory, without a window.
    @Test func drawsWithARendererItDoesNotOwn() throws {
        let surface = try #require(SDL_CreateSurface(8, 8, SDL_PIXELFORMAT_ABGR8888))
        defer { SDL_DestroySurface(surface) }
        let sdlRenderer = try #require(SDL_CreateSoftwareRenderer(surface))
        defer { SDL_DestroyRenderer(sdlRenderer) }

        let renderer = HostRenderer(renderer: sdlRenderer)
        renderer.backgroundColor = ResolvedColor(red: 0, green: 0, blue: 1)
        let list = DisplayList(items: [
            DisplayList.Item(
                frame: CGRect(x: 0, y: 0, width: 4, height: 8),
                identity: 1,
                version: 1,
                value: .content(.color(ResolvedColor(red: 1, green: 0, blue: 0)))
            )
        ])
        renderer.render(list, size: CGSize(width: 8, height: 8), scale: 1)
        SDL_RenderPresent(sdlRenderer)

        let row = surface.pointee.pixels!.assumingMemoryBound(to: UInt8.self)
        // Red on the left half, the background's blue on the right.
        #expect([row[0], row[1], row[2]] == [255, 0, 0])
        #expect([row[7 * 4], row[7 * 4 + 1], row[7 * 4 + 2]] == [0, 0, 255])
    }
}
