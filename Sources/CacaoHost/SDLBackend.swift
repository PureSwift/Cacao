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
import SDL3Swift

/// The compositor's GPU backend: the SDL3 renderer, which draws with Metal
/// on macOS and Vulkan or OpenGL on Linux.
///
/// A drawing call that fails draws nothing: the next frame draws again.
@MainActor
final class SDLBackend: CompositorBackend {

    let renderer: SDLRenderer

    private var textures: [Int: SDLTexture] = [:]

    private var nextTexture = 0

    /// The EGL images behind textures imported from shared buffers.
    private var images: [Int: UnsafeMutableRawPointer] = [:]

    /// Premultiplied alpha blending, for textures drawn by Silica.
    private static let premultipliedBlend: BitMaskOptionSet<SDLBlendMode> = [.alphaPremultiplied]

    /// A color component at full strength: a texture's colors as they are.
    private static let full: Float = 1

    init(renderer: SDLRenderer) {
        self.renderer = renderer
    }

    private func add(_ texture: SDLTexture) -> TextureID {
        nextTexture += 1
        textures[nextTexture] = texture
        return TextureID(rawValue: nextTexture)
    }

    func makeTexture(width: Int, height: Int, bytesPerRow: Int, pixels: Data) -> TextureID? {
        guard let texture = try? SDLTexture(renderer: renderer, format: .abgr8888, access: .static, width: width, height: height) else {
            return nil
        }
        pixels.withUnsafeBytes { (bytes: UnsafeRawBufferPointer) in
            guard let base = bytes.baseAddress else { return }
            try? texture.update(pixels: base, pitch: bytesPerRow)
        }
        try? texture.setBlendMode(Self.premultipliedBlend)
        return add(texture)
    }

    func makeLayer(width: Int, height: Int) -> TextureID? {
        guard let texture = try? SDLTexture(renderer: renderer, format: .abgr8888, access: .target, width: width, height: height) else {
            return nil
        }
        try? texture.setBlendMode(Self.premultipliedBlend)
        // Layers drawn smaller or larger than their pixels, as blurring
        // does, average their pixels.
        try? texture.setScaleMode(.linear)
        return add(texture)
    }

    // MARK: External surfaces

    func makeExternalTexture(width: Int, height: Int, format: ExternalSurface.PixelFormat) -> TextureID? {
        // SDL names formats by the order in a 32-bit value: the bytes
        // R, G, B, A are ABGR8888 on little-endian machines.
        guard let texture = try? SDLTexture(
            renderer: renderer,
            format: format == .bgra ? .argb8888 : .abgr8888,
            access: .streaming,
            width: width,
            height: height
        ) else {
            return nil
        }
        return add(texture)
    }

    func updateExternalTexture(_ texture: TextureID, bytesPerRow: Int, pixels: Data) {
        guard let texture = textures[texture.rawValue] else { return }
        pixels.withUnsafeBytes { (bytes: UnsafeRawBufferPointer) in
            guard let base = bytes.baseAddress else { return }
            try? texture.update(pixels: base, pitch: bytesPerRow)
        }
    }

    func importExternalBuffer(_ buffer: ExternalSurface.Buffer) -> TextureID? {
        guard let imported = SharedBuffers.importBuffer(buffer, renderer: renderer) else { return nil }
        let id = add(imported.texture)
        if let image = imported.image {
            images[id.rawValue] = image
        }
        return id
    }

    func readPixels(_ rect: CGRect) -> (pixels: Data, width: Int, height: Int, bytesPerRow: Int)? {
        let area = SDLRect(x: Int32(rect.minX), y: Int32(rect.minY), width: Int32(rect.width), height: Int32(rect.height))
        // R, G, B, A bytes, whatever the target's format is.
        guard area.width > 0, area.height > 0,
              let surface = try? renderer.readPixels(area).converted(to: .abgr8888) else {
            return nil
        }
        let width = surface.width, height = surface.height, pitch = surface.pitch
        guard width > 0, height > 0,
              let pixels = try? surface.withUnsafeMutableBytes({ Data(bytes: $0, count: pitch * height) }) else {
            return nil
        }
        return (pixels, width, height, pitch)
    }

    func drawExternal(_ texture: TextureID, in rect: CGRect, opacity: Double, isOpaque: Bool, isFlipped: Bool, smooth: Bool) {
        guard let texture = textures[texture.rawValue] else { return }
        let alpha = Float(opacity)
        try? texture.setBlendMode(isOpaque && alpha >= 1 ? [] : Self.premultipliedBlend)
        try? texture.setScaleMode(smooth ? .linear : .nearest)
        try? texture.setColorModulation(red: alpha, green: alpha, blue: alpha)
        try? texture.setAlphaModulation(alpha)
        try? renderer.copy(texture, to: SDLFRect(rect), angle: 0, flip: isFlipped ? [.vertical] : [])
    }

    /// The layers being drawn into, innermost last.
    private var targets: [SDLTexture] = []

    func beginLayer(_ layer: TextureID) {
        guard let texture = textures[layer.rawValue] else { return }
        targets.append(texture)
        try? renderer.setTarget(texture)
        try? renderer.setClipRect(nil)
        try? renderer.setDrawColorFloat(red: 0, green: 0, blue: 0, alpha: 0)
        try? renderer.clear()
    }

    func endLayer() {
        targets.removeLast()
        try? renderer.setTarget(targets.last)
    }

    func drawLayer(_ layer: TextureID, in rect: CGRect, opacity: Double, mask: [CGPoint]?) {
        guard let texture = textures[layer.rawValue] else { return }
        let alpha = Float(opacity)
        guard let mask, mask.count >= 3, rect.width > 0, rect.height > 0 else {
            // Premultiplied colors scale with the opacity too.
            try? texture.setColorModulation(red: alpha, green: alpha, blue: alpha)
            try? texture.setAlphaModulation(alpha)
            try? renderer.copy(texture, to: SDLFRect(rect))
            return
        }
        // A triangle fan around the polygon's centroid, sampling the layer.
        try? texture.setColorModulation(red: Self.full, green: Self.full, blue: Self.full)
        try? texture.setAlphaModulation(Self.full)
        let count = CGFloat(mask.count)
        let center = CGPoint(x: mask.reduce(0) { $0 + $1.x } / count, y: mask.reduce(0) { $0 + $1.y } / count)
        let color = SDLRenderer.VertexColor(red: alpha, green: alpha, blue: alpha, alpha: alpha)
        func vertex(_ point: CGPoint) -> SDLRenderer.Vertex {
            SDLRenderer.Vertex(
                x: Float(point.x),
                y: Float(point.y),
                color: color,
                textureX: Float((point.x - rect.minX) / rect.width),
                textureY: Float((point.y - rect.minY) / rect.height)
            )
        }
        let vertices = [vertex(center)] + mask.map(vertex)
        var indices: [Int32] = []
        for index in 1...mask.count {
            indices.append(0)
            indices.append(Int32(index))
            indices.append(Int32(index % mask.count + 1))
        }
        try? renderer.drawGeometry(texture: texture, vertices: vertices, indices: indices)
    }

    func mask(with layer: TextureID, in rect: CGRect) {
        guard let texture = textures[layer.rawValue] else { return }
        try? texture.setColorModulation(red: Self.full, green: Self.full, blue: Self.full)
        try? texture.setAlphaModulation(Self.full)
        // Keeps the destination where the layer is opaque.
        try? texture.setBlendMode(SDLCustomBlendMode.destinationIn)
        try? renderer.copy(texture, to: SDLFRect(rect))
        try? texture.setBlendMode(Self.premultipliedBlend)
    }

    func drawLayer(_ layer: TextureID, corners: [CGPoint], opacity: Double) {
        guard let texture = textures[layer.rawValue], corners.count == 4 else { return }
        try? texture.setColorModulation(red: Self.full, green: Self.full, blue: Self.full)
        try? texture.setAlphaModulation(Self.full)
        try? texture.setScaleMode(.linear)
        let alpha = Float(opacity)
        let color = SDLRenderer.VertexColor(red: alpha, green: alpha, blue: alpha, alpha: alpha)
        let coordinates: [(Float, Float)] = [(0, 0), (1, 0), (1, 1), (0, 1)]
        let vertices = zip(corners, coordinates).map { corner, coordinate in
            SDLRenderer.Vertex(
                x: Float(corner.x),
                y: Float(corner.y),
                color: color,
                textureX: coordinate.0,
                textureY: coordinate.1
            )
        }
        try? renderer.drawGeometry(texture: texture, vertices: vertices, indices: [0, 1, 2, 0, 2, 3])
    }

    func destroyTexture(_ texture: TextureID) {
        // The texture is destroyed as its last reference goes.
        textures[texture.rawValue] = nil
        if let image = images.removeValue(forKey: texture.rawValue) {
            SharedBuffers.destroyImage(image)
        }
    }

    func beginFrame(width: Int, height: Int, clearColor: ResolvedColor) {
        targets.removeAll()
        try? renderer.setTarget(nil)
        try? renderer.setClipRect(nil)
        try? renderer.setDrawColorFloat(red: clearColor.red, green: clearColor.green, blue: clearColor.blue, alpha: 1)
        try? renderer.clear()
    }

    func fill(_ rect: CGRect, color: ResolvedColor) {
        // Alpha blending, for fills with straight alpha.
        try? renderer.setDrawBlendMode([.alpha])
        try? renderer.setDrawColorFloat(red: color.red, green: color.green, blue: color.blue, alpha: color.opacity)
        try? renderer.fill(SDLFRect(rect))
    }

    func draw(_ texture: TextureID, in rect: CGRect, opacity: Double, smooth: Bool) {
        guard let texture = textures[texture.rawValue] else { return }
        // Premultiplied colors scale with the opacity too.
        try? texture.setColorModulation(red: Float(opacity), green: Float(opacity), blue: Float(opacity))
        try? texture.setAlphaModulation(Float(opacity))
        try? texture.setScaleMode(smooth ? .linear : .nearest)
        try? renderer.copy(texture, to: SDLFRect(rect))
    }

    func setClip(_ rect: CGRect?) {
        guard let rect else {
            try? renderer.setClipRect(nil)
            return
        }
        try? renderer.setClipRect(SDLRect(
            x: Int32(rect.minX.rounded()),
            y: Int32(rect.minY.rounded()),
            width: Int32(max(0, rect.width.rounded())),
            height: Int32(max(0, rect.height.rounded()))
        ))
    }

    func endFrame() { }

    func destroyAllTextures() {
        targets.removeAll()
        textures.removeAll()
        for image in images.values {
            SharedBuffers.destroyImage(image)
        }
        images.removeAll()
    }
}

extension SDLFRect {

    init(_ rect: CGRect) {
        self.init(x: Float(rect.minX), y: Float(rect.minY), width: Float(rect.width), height: Float(rect.height))
    }
}
