//
//  SDLBackend.swift
//  CacaoHost
//
//  Created by Alsey Coleman Miller on 11/13/26.
//

import CacaoRender
import Foundation
#if canImport(CoreGraphics)
import CoreGraphics
#endif
import CacaoCompositor
import CSDL3

/// The compositor's GPU backend: the SDL3 renderer, which draws with Metal
/// on macOS and Vulkan or OpenGL on Linux.
@MainActor
final class SDLBackend: CompositorBackend {

    let renderer: OpaquePointer

    private var textures: [Int: UnsafeMutablePointer<SDL_Texture>] = [:]

    private var nextTexture = 0

    /// The EGL images behind textures imported from shared buffers.
    private var images: [Int: UnsafeMutableRawPointer] = [:]

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
        pixels.withUnsafeBytes { (bytes: UnsafeRawBufferPointer) in
            _ = SDL_UpdateTexture(texture, nil, bytes.baseAddress, Int32(bytesPerRow))
        }
        SDL_SetTextureBlendMode(texture, Self.premultipliedBlend)
        nextTexture += 1
        textures[nextTexture] = texture
        return TextureID(rawValue: nextTexture)
    }

    func makeLayer(width: Int, height: Int) -> TextureID? {
        guard let texture = SDL_CreateTexture(
            renderer,
            SDL_PIXELFORMAT_ABGR8888,
            SDL_TEXTUREACCESS_TARGET,
            Int32(width),
            Int32(height)
        ) else {
            return nil
        }
        SDL_SetTextureBlendMode(texture, Self.premultipliedBlend)
        // Layers drawn smaller or larger than their pixels, as blurring
        // does, average their pixels.
        SDL_SetTextureScaleMode(texture, SDL_SCALEMODE_LINEAR)
        nextTexture += 1
        textures[nextTexture] = texture
        return TextureID(rawValue: nextTexture)
    }

    // MARK: External surfaces

    func makeExternalTexture(width: Int, height: Int, format: ExternalSurface.PixelFormat) -> TextureID? {
        // SDL names formats by the order in a 32-bit value: the bytes
        // R, G, B, A are ABGR8888 on little-endian machines.
        guard let texture = SDL_CreateTexture(
            renderer,
            format == .bgra ? SDL_PIXELFORMAT_ARGB8888 : SDL_PIXELFORMAT_ABGR8888,
            SDL_TEXTUREACCESS_STREAMING,
            Int32(width),
            Int32(height)
        ) else {
            return nil
        }
        nextTexture += 1
        textures[nextTexture] = texture
        return TextureID(rawValue: nextTexture)
    }

    func updateExternalTexture(_ texture: TextureID, bytesPerRow: Int, pixels: Data) {
        guard let texture = textures[texture.rawValue] else { return }
        pixels.withUnsafeBytes { (bytes: UnsafeRawBufferPointer) in
            _ = SDL_UpdateTexture(texture, nil, bytes.baseAddress, Int32(bytesPerRow))
        }
    }

    func importExternalBuffer(_ buffer: ExternalSurface.Buffer) -> TextureID? {
        guard let texture = SharedBuffers.importBuffer(buffer, renderer: renderer) else { return nil }
        nextTexture += 1
        textures[nextTexture] = texture.texture
        if let image = texture.image {
            images[nextTexture] = image
        }
        return TextureID(rawValue: nextTexture)
    }

    func readPixels(_ rect: CGRect) -> (pixels: Data, width: Int, height: Int, bytesPerRow: Int)? {
        var area = SDL_Rect(x: Int32(rect.minX), y: Int32(rect.minY), w: Int32(rect.width), h: Int32(rect.height))
        guard area.w > 0, area.h > 0, let read = SDL_RenderReadPixels(renderer, &area) else { return nil }
        defer { SDL_DestroySurface(read) }
        // R, G, B, A bytes, whatever the target's format is.
        guard let surface = SDL_ConvertSurface(read, SDL_PIXELFORMAT_ABGR8888) else { return nil }
        defer { SDL_DestroySurface(surface) }
        let width = Int(surface.pointee.w), height = Int(surface.pointee.h), pitch = Int(surface.pointee.pitch)
        guard width > 0, height > 0, let pixels = surface.pointee.pixels else { return nil }
        return (Data(bytes: pixels, count: pitch * height), width, height, pitch)
    }

    func drawExternal(_ texture: TextureID, in rect: CGRect, opacity: Double, isOpaque: Bool, isFlipped: Bool, smooth: Bool) {
        guard let texture = textures[texture.rawValue] else { return }
        let alpha = Float(opacity)
        SDL_SetTextureBlendMode(texture, isOpaque && alpha >= 1 ? SDL_BlendMode(0) : Self.premultipliedBlend)
        SDL_SetTextureScaleMode(texture, smooth ? SDL_SCALEMODE_LINEAR : SDL_SCALEMODE_NEAREST)
        SDL_SetTextureColorModFloat(texture, alpha, alpha, alpha)
        SDL_SetTextureAlphaModFloat(texture, alpha)
        var frame = SDL_FRect(rect)
        SDL_RenderTextureRotated(renderer, texture, nil, &frame, 0, nil, isFlipped ? SDL_FLIP_VERTICAL : SDL_FLIP_NONE)
    }

    /// The layers being drawn into, innermost last.
    private var targets: [UnsafeMutablePointer<SDL_Texture>] = []

    func beginLayer(_ layer: TextureID) {
        guard let texture = textures[layer.rawValue] else { return }
        targets.append(texture)
        SDL_SetRenderTarget(renderer, texture)
        SDL_SetRenderClipRect(renderer, nil)
        SDL_SetRenderDrawColorFloat(renderer, 0, 0, 0, 0)
        SDL_RenderClear(renderer)
    }

    func endLayer() {
        targets.removeLast()
        SDL_SetRenderTarget(renderer, targets.last)
    }

    func drawLayer(_ layer: TextureID, in rect: CGRect, opacity: Double, mask: [CGPoint]?) {
        guard let texture = textures[layer.rawValue] else { return }
        let alpha = Float(opacity)
        guard let mask, mask.count >= 3, rect.width > 0, rect.height > 0 else {
            // Premultiplied colors scale with the opacity too.
            SDL_SetTextureColorModFloat(texture, alpha, alpha, alpha)
            SDL_SetTextureAlphaModFloat(texture, alpha)
            var frame = SDL_FRect(rect)
            SDL_RenderTexture(renderer, texture, nil, &frame)
            return
        }
        // A triangle fan around the polygon's centroid, sampling the layer.
        SDL_SetTextureColorModFloat(texture, 1, 1, 1)
        SDL_SetTextureAlphaModFloat(texture, 1)
        let count = CGFloat(mask.count)
        let center = CGPoint(x: mask.reduce(0) { $0 + $1.x } / count, y: mask.reduce(0) { $0 + $1.y } / count)
        func vertex(_ point: CGPoint) -> SDL_Vertex {
            SDL_Vertex(
                position: SDL_FPoint(x: Float(point.x), y: Float(point.y)),
                color: SDL_FColor(r: alpha, g: alpha, b: alpha, a: alpha),
                tex_coord: SDL_FPoint(
                    x: Float((point.x - rect.minX) / rect.width),
                    y: Float((point.y - rect.minY) / rect.height)
                )
            )
        }
        var vertices = [vertex(center)] + mask.map(vertex)
        var indices: [Int32] = []
        for index in 1...mask.count {
            indices.append(0)
            indices.append(Int32(index))
            indices.append(Int32(index % mask.count + 1))
        }
        SDL_RenderGeometry(renderer, texture, &vertices, Int32(vertices.count), &indices, Int32(indices.count))
    }

    /// Keeps the destination where the source is opaque.
    private static let destinationIn = SDL_ComposeCustomBlendMode(
        SDL_BLENDFACTOR_ZERO, SDL_BLENDFACTOR_SRC_ALPHA, SDL_BLENDOPERATION_ADD,
        SDL_BLENDFACTOR_ZERO, SDL_BLENDFACTOR_SRC_ALPHA, SDL_BLENDOPERATION_ADD
    )

    func mask(with layer: TextureID, in rect: CGRect) {
        guard let texture = textures[layer.rawValue] else { return }
        SDL_SetTextureColorModFloat(texture, 1, 1, 1)
        SDL_SetTextureAlphaModFloat(texture, 1)
        SDL_SetTextureBlendMode(texture, Self.destinationIn)
        var frame = SDL_FRect(rect)
        SDL_RenderTexture(renderer, texture, nil, &frame)
        SDL_SetTextureBlendMode(texture, Self.premultipliedBlend)
    }

    func drawLayer(_ layer: TextureID, corners: [CGPoint], opacity: Double) {
        guard let texture = textures[layer.rawValue], corners.count == 4 else { return }
        SDL_SetTextureColorModFloat(texture, 1, 1, 1)
        SDL_SetTextureAlphaModFloat(texture, 1)
        SDL_SetTextureScaleMode(texture, SDL_SCALEMODE_LINEAR)
        let alpha = Float(opacity)
        let coordinates = [(0, 0), (1, 0), (1, 1), (0, 1)]
        var vertices = zip(corners, coordinates).map { corner, coordinate in
            SDL_Vertex(
                position: SDL_FPoint(x: Float(corner.x), y: Float(corner.y)),
                color: SDL_FColor(r: alpha, g: alpha, b: alpha, a: alpha),
                tex_coord: SDL_FPoint(x: Float(coordinate.0), y: Float(coordinate.1))
            )
        }
        var indices: [Int32] = [0, 1, 2, 0, 2, 3]
        SDL_RenderGeometry(renderer, texture, &vertices, 4, &indices, 6)
    }

    func destroyTexture(_ texture: TextureID) {
        if let pointer = textures.removeValue(forKey: texture.rawValue) {
            SDL_DestroyTexture(pointer)
        }
        if let image = images.removeValue(forKey: texture.rawValue) {
            SharedBuffers.destroyImage(image)
        }
    }

    func beginFrame(width: Int, height: Int, clearColor: ResolvedColor) {
        targets.removeAll()
        SDL_SetRenderTarget(renderer, nil)
        SDL_SetRenderClipRect(renderer, nil)
        SDL_SetRenderDrawColorFloat(renderer, clearColor.red, clearColor.green, clearColor.blue, 1)
        SDL_RenderClear(renderer)
    }

    func fill(_ rect: CGRect, color: ResolvedColor) {
        SDL_SetRenderDrawBlendMode(renderer, Self.blend)
        SDL_SetRenderDrawColorFloat(renderer, color.red, color.green, color.blue, color.opacity)
        var frame = SDL_FRect(rect)
        SDL_RenderFillRect(renderer, &frame)
    }

    func draw(_ texture: TextureID, in rect: CGRect, opacity: Double, smooth: Bool) {
        guard let pointer = textures[texture.rawValue] else { return }
        // Premultiplied colors scale with the opacity too.
        SDL_SetTextureColorModFloat(pointer, Float(opacity), Float(opacity), Float(opacity))
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
        for image in images.values {
            SharedBuffers.destroyImage(image)
        }
        images.removeAll()
    }
}

extension SDL_FRect {

    init(_ rect: CGRect) {
        self.init(x: Float(rect.minX), y: Float(rect.minY), w: Float(rect.width), h: Float(rect.height))
    }
}
