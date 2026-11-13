//
//  CacaoSDL.swift
//  CacaoSDL
//
//  Created by Alsey Coleman Miller on 11/13/26.
//

@_exported import Cacao
import CacaoCompositor
import CacaoScrollPhysics
import SDL3Swift
import CSDL3

/// The SDL3 host: windows, the main loop and frame clock, input, and the
/// SDL3 renderer backend of the compositor.
///
/// `App.main()` lands here in Phase 2 (see `Documentation/Plan.md` §2.6).
public enum CacaoSDL {

    /// The version of the SDL library loaded at run time, as `major.minor.micro`.
    public static var sdlVersion: String {
        let version = Int(SDL_GetVersion())
        return "\(version / 1_000_000).\(version / 1_000 % 1_000).\(version % 1_000)"
    }

    /// Initializes SDL's video subsystem, runs `body`, then shuts SDL down.
    public static func withVideo<T>(_ body: () throws -> T) throws -> T {
        try SDL.initialize(subSystems: [.video])
        defer { SDL.quit() }
        return try body()
    }
}
