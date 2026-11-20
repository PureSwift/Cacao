//
//  HostRenderer.swift
//  CacaoHost
//
//  Created by Alsey Coleman Miller on 11/20/26.
//

import Foundation
#if canImport(CoreGraphics)
import CoreGraphics
#endif
import CacaoRender
import CacaoCompositor
import SDL3Swift

/// Draws display lists with an SDL renderer that belongs to someone else.
///
/// For a UI framework that has its own windows and its own loop, and only
/// wants the compositor: it makes one of these for each `SDL_Renderer`,
/// draws a display list each frame, and presents the frame itself. A
/// framework without windows of its own uses `HostRuntime` and a
/// `HostScene` instead.
@MainActor
public final class HostRenderer {

    /// The `SDL_Renderer` drawn with, which stays the caller's.
    public let renderer: OpaquePointer

    private let backend: SDLBackend

    private let compositor: Compositor

    /// Creates a renderer drawing with an `SDL_Renderer`, which must
    /// outlive it.
    public init(renderer: OpaquePointer) {
        self.renderer = renderer
        self.backend = SDLBackend(renderer: SDLRenderer(unownedPointer: renderer))
        self.compositor = Compositor(backend: backend, textEngine: SilicaTextEngine())
    }

    /// The color a frame is cleared to before the list is drawn.
    public var backgroundColor: ResolvedColor {
        get { compositor.backgroundColor }
        set { compositor.backgroundColor = newValue }
    }

    /// Draws a display list as a frame of `size` points, at `scale` pixels
    /// a point. The frame isn't presented.
    public func render(_ list: DisplayList, size: CGSize, scale: CGFloat) {
        compositor.render(list, size: size, scale: scale)
    }

    /// Whether an external surface in the last list drawn has a frame that
    /// wasn't shown, so the list is worth drawing again as it is.
    public var hasNewExternalFrames: Bool {
        compositor.hasNewExternalFrames
    }

    /// The external surfaces in the last list drawn, for waking a loop when
    /// one publishes.
    public var externalSurfaces: Set<ExternalSurface> {
        compositor.externalSurfaces
    }

    /// The textures made and draws issued for the last frame.
    public var statistics: String {
        let frame = compositor.lastFrame
        return "layers \(frame.layers) textures \(frame.textures) draws \(frame.draws) "
            + "rasterizations \(frame.rasterizations) uploads \(frame.uploads)"
    }
}
