import Testing
import Foundation
@testable import CacaoSDL

@MainActor
@Suite struct CacaoSDLTests {

    @Test func linksSDL3() {
        #expect(SDLHost.sdlVersion.hasPrefix("3."))
    }

    /// Starts SDL's video subsystem with the offscreen driver, which works on
    /// CI machines without a display.
    @Test func offscreenVideo() throws {
        setenv("SDL_VIDEO_DRIVER", "offscreen", 1)
        let started = try SDLHost.withVideo { true }
        #expect(started)
    }
}
