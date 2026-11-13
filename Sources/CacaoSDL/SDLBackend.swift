//
//  SDLBackend.swift
//  CacaoSDL
//
//  Created by Alsey Coleman Miller on 11/13/26.
//

import Foundation
#if canImport(CoreGraphics)
import CoreGraphics
#endif
import Cacao
import CacaoCompositor
import CSDL3

/// The compositor's GPU backend: the SDL3 renderer, which draws with Metal
/// on macOS and Vulkan or OpenGL on Linux.
@MainActor
final class SDLBackend: CompositorBackend {

    let renderer: OpaquePointer

    private var textures: [Int: UnsafeMutablePointer<SDL_Texture>] = [:]

    private var nextTexture = 0

    /// Premultiplied alpha blending, for textures drawn by Silica.
    private static let premultipliedBlend = SDL_BlendMode(0x0000_0010)

    /// Alpha blending, for fills with straight alpha.
    private static let blend = SDL_BlendMode(0x0000_0001)

    init(renderer: OpaquePointer) {
        self.renderer = renderer
    }

    func makeTexture(width: Int, height: Int, bytesPerRow: Int, pixels: Data) -> TextureID? {
        guard let texture = SDL_CreateTexture(
            renderer,
            SDL_PIXELFORMAT_ABGR8888,
            SDL_TEXTUREACCESS_STATIC,
            Int32(width),
            Int32(height)
        ) else {
            return nil
        }
        pixels.withUnsafeBytes { bytes in
            _ = SDL_UpdateTexture(texture, nil, bytes.baseAddress, Int32(bytesPerRow))
        }
        SDL_SetTextureBlendMode(texture, Self.premultipliedBlend)
        nextTexture += 1
        textures[nextTexture] = texture
        return TextureID(rawValue: nextTexture)
    }

    func destroyTexture(_ texture: TextureID) {
        if let pointer = textures.removeValue(forKey: texture.rawValue) {
            SDL_DestroyTexture(pointer)
        }
    }

    func beginFrame(width: Int, height: Int, clearColor: Color.Resolved) {
        SDL_SetRenderClipRect(renderer, nil)
        SDL_SetRenderDrawColorFloat(renderer, clearColor.red, clearColor.green, clearColor.blue, 1)
        SDL_RenderClear(renderer)
    }

    func fill(_ rect: CGRect, color: Color.Resolved) {
        SDL_SetRenderDrawBlendMode(renderer, Self.blend)
        SDL_SetRenderDrawColorFloat(renderer, color.red, color.green, color.blue, color.opacity)
        var frame = SDL_FRect(rect)
        SDL_RenderFillRect(renderer, &frame)
    }

    func draw(_ texture: TextureID, in rect: CGRect, opacity: Double, smooth: Bool) {
        guard let pointer = textures[texture.rawValue] else { return }
        SDL_SetTextureAlphaModFloat(pointer, Float(opacity))
        SDL_SetTextureScaleMode(pointer, smooth ? SDL_SCALEMODE_LINEAR : SDL_SCALEMODE_NEAREST)
        var frame = SDL_FRect(rect)
        SDL_RenderTexture(renderer, pointer, nil, &frame)
    }

    func setClip(_ rect: CGRect?) {
        if let rect {
            var clip = SDL_Rect(
                x: Int32(rect.minX.rounded()),
                y: Int32(rect.minY.rounded()),
                w: Int32(max(0, rect.width.rounded())),
                h: Int32(max(0, rect.height.rounded()))
            )
            SDL_SetRenderClipRect(renderer, &clip)
        } else {
            SDL_SetRenderClipRect(renderer, nil)
        }
    }

    func endFrame() { }

    func destroyAllTextures() {
        for texture in textures.values {
            SDL_DestroyTexture(texture)
        }
        textures.removeAll()
    }
}

extension SDL_FRect {

    init(_ rect: CGRect) {
        self.init(x: Float(rect.minX), y: Float(rect.minY), w: Float(rect.width), h: Float(rect.height))
    }
}
