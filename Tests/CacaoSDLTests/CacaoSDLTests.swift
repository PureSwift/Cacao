import Testing
import Foundation
@testable import CacaoSDL

@Suite struct CacaoSDLTests {

    @Test func linksSDL3() {
        #expect(CacaoSDL.sdlVersion.hasPrefix("3."))
    }

    /// Starts SDL's video subsystem with the offscreen driver, which works on
    /// CI machines without a display.
    @Test func offscreenVideo() throws {
        setenv("SDL_VIDEO_DRIVER", "offscreen", 1)
        let started = try CacaoSDL.withVideo { true }
        #expect(started)
    }
}
