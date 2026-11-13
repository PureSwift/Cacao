//
//  Compositor.swift
//  CacaoCompositor
//
//  Created by Alsey Coleman Miller on 11/13/26.
//

import Foundation
#if canImport(CoreGraphics)
import CoreGraphics
#endif
import Cacao
import Silica

// MARK: - Backend

/// A texture created by a compositor backend.
package struct TextureID: Hashable, Sendable {

    package let rawValue: Int

    package init(rawValue: Int) {
        self.rawValue = rawValue
    }
}

/// The GPU operations the compositor needs, in pixels.
@MainActor
package protocol CompositorBackend: AnyObject {

    /// Creates a texture from premultiplied RGBA pixels, rows top to bottom.
    func makeTexture(width: Int, height: Int, bytesPerRow: Int, pixels: Data) -> TextureID?

    func destroyTexture(_ texture: TextureID)

    /// Starts a frame of the given size, cleared to a color.
    func beginFrame(width: Int, height: Int, clearColor: Color.Resolved)

    /// Fills a rectangle with a color, its opacity already applied.
    func fill(_ rect: CGRect, color: Color.Resolved)

    /// Draws a texture stretched to a rectangle.
    func draw(_ texture: TextureID, in rect: CGRect, opacity: Double, smooth: Bool)

    /// Limits drawing to a rectangle, or removes the limit.
    func setClip(_ rect: CGRect?)

    /// Shows the frame.
    func endFrame()
}

// MARK: - Compositor

/// Draws display lists with a GPU backend, keeping each item's rasterized
/// content in a texture until the content changes.
///
/// Text and shapes are drawn with Silica only when an item's content or size
/// changes, or when it first becomes visible; colors are filled directly and
/// images are decoded once. Every frame then only draws textures, moved by
/// scroll offsets and clipped to scroll views, so scrolling never rasterizes
/// content that was already drawn.
@MainActor
package final class Compositor {

    /// Counts of the compositor's work.
    package struct Statistics: Equatable, Sendable {

        /// Items whose content was drawn with Silica.
        package var rasterizations = 0

        /// Textures created.
        package var uploads = 0

        /// Fills and texture draws sent to the backend.
        package var draws = 0

        /// Textures alive after the frame.
        package var textures = 0
    }

    package let backend: any CompositorBackend

    package let textEngine: SilicaTextEngine

    /// The window's background color.
    package var backgroundColor = Color.Resolved(red: 1, green: 1, blue: 1)

    /// The work done by the last frame.
    package private(set) var lastFrame = Statistics()

    /// The work done by all frames.
    package private(set) var total = Statistics()

    private struct CachedLayer {
        var content: DisplayList.Content
        var size: CGSize
        var scale: CGFloat
        var texture: TextureID?
    }

    private struct CachedImage {
        var texture: TextureID?
    }

    private struct ImageKey: Hashable {
        let source: ImageSource
        let tint: Color.Resolved?
    }

    private var layers: [Int: CachedLayer] = [:]

    private var images: [ImageKey: CachedImage] = [:]

    private var scale: CGFloat = 1

    private var frameStatistics = Statistics()

    private var presentLayers: Set<Int> = []

    private var presentImages: Set<ImageKey> = []

    package init(backend: any CompositorBackend, textEngine: SilicaTextEngine) {
        self.backend = backend
        self.textEngine = textEngine
    }

    /// Draws a display list in a window of `size` points at `scale` pixels
    /// a point.
    package func render(_ list: DisplayList, size: CGSize, scale: CGFloat) {
        if scale != self.scale {
            self.scale = scale
            removeAllTextures()
        }
        frameStatistics = Statistics()
        presentLayers.removeAll(keepingCapacity: true)
        presentImages.removeAll(keepingCapacity: true)
        backend.beginFrame(
            width: Int((size.width * scale).rounded()),
            height: Int((size.height * scale).rounded()),
            clearColor: backgroundColor
        )
        let bounds = CGRect(origin: CGPoint(x: 0, y: 0), size: size)
        draw(list.items, translation: CGPoint(x: 0, y: 0), clip: bounds, opacity: 1)
        backend.setClip(nil)
        evictUnused()
        backend.endFrame()
        frameStatistics.textures = layers.values.filter { $0.texture != nil }.count + images.count
        lastFrame = frameStatistics
        total.rasterizations += frameStatistics.rasterizations
        total.uploads += frameStatistics.uploads
        total.draws += frameStatistics.draws
        total.textures = frameStatistics.textures
    }

    // MARK: Drawing

    private func draw(_ items: [DisplayList.Item], translation: CGPoint, clip: CGRect, opacity: Double) {
        for item in items {
            switch item.value {
            case let .content(content):
                presentLayers.insert(item.identity)
                let frame = item.frame.offsetBy(dx: -translation.x, dy: -translation.y)
                guard frame.intersects(clip), opacity > 0 else {
                    if case let .image(image) = content {
                        presentImages.insert(ImageKey(source: image.source, tint: image.tint))
                    }
                    continue
                }
                draw(content, identity: item.identity, frame: frame, opacity: opacity)
            case let .effect(.opacity(value), nested):
                draw(nested.items, translation: translation, clip: clip, opacity: opacity * value)
            case let .effect(.scroll(effect), nested):
                let viewport = effect.viewport.offsetBy(dx: -translation.x, dy: -translation.y)
                let innerClip = clip.intersection(viewport)
                guard !innerClip.isNull, !innerClip.isEmpty else {
                    markPresent(nested.items)
                    continue
                }
                backend.setClip(pixelRect(innerClip))
                draw(
                    nested.items,
                    translation: CGPoint(x: translation.x + effect.offset.x, y: translation.y + effect.offset.y),
                    clip: innerClip,
                    opacity: opacity
                )
                if effect.showsIndicators {
                    drawIndicators(effect, viewport: viewport, opacity: opacity)
                }
                backend.setClip(pixelRect(clip))
            }
        }
    }

    /// Keeps the textures of items that are present but not drawn.
    private func markPresent(_ items: [DisplayList.Item]) {
        for item in items {
            switch item.value {
            case let .content(.image(image)):
                presentLayers.insert(item.identity)
                presentImages.insert(ImageKey(source: image.source, tint: image.tint))
            case .content:
                presentLayers.insert(item.identity)
            case let .effect(_, nested):
                markPresent(nested.items)
            }
        }
    }

    private func draw(_ content: DisplayList.Content, identity: Int, frame: CGRect, opacity: Double) {
        switch content {
        case let .color(color):
            var color = color
            color.opacity *= Float(opacity)
            backend.fill(pixelRect(frame), color: color)
            frameStatistics.draws += 1
        case .text, .shape:
            guard let texture = texture(for: content, identity: identity, size: frame.size) else {
                return
            }
            let outset = Rasterizer.outset(of: content)
            backend.draw(texture, in: texturePixelRect(frame.insetBy(dx: -outset, dy: -outset)), opacity: opacity, smooth: false)
            frameStatistics.draws += 1
        case let .image(image):
            let key = ImageKey(source: image.source, tint: image.tint)
            presentImages.insert(key)
            guard let texture = imageTexture(key, content: image) else {
                return
            }
            backend.draw(texture, in: pixelRect(frame), opacity: opacity, smooth: image.interpolation != .none)
            frameStatistics.draws += 1
        }
    }

    private func drawIndicators(_ effect: ScrollEffect, viewport: CGRect, opacity: Double) {
        let thickness: CGFloat = 3
        let inset: CGFloat = 2
        let color = Color.Resolved(red: 0.5, green: 0.5, blue: 0.5, opacity: Float(0.6 * opacity))
        if effect.contentSize.height > viewport.height, viewport.height > 0 {
            let length = max(viewport.height * viewport.height / effect.contentSize.height, 20)
            let maxOffset = effect.contentSize.height - viewport.height
            let progress = min(max(effect.offset.y / maxOffset, 0), 1)
            let y = viewport.minY + inset + progress * (viewport.height - length - 2 * inset)
            backend.fill(
                pixelRect(CGRect(x: viewport.maxX - thickness - inset, y: y, width: thickness, height: length)),
                color: color
            )
            frameStatistics.draws += 1
        }
        if effect.contentSize.width > viewport.width, viewport.width > 0 {
            let length = max(viewport.width * viewport.width / effect.contentSize.width, 20)
            let maxOffset = effect.contentSize.width - viewport.width
            let progress = min(max(effect.offset.x / maxOffset, 0), 1)
            let x = viewport.minX + inset + progress * (viewport.width - length - 2 * inset)
            backend.fill(
                pixelRect(CGRect(x: x, y: viewport.maxY - thickness - inset, width: length, height: thickness)),
                color: color
            )
            frameStatistics.draws += 1
        }
    }

    // MARK: Textures

    /// The cached texture for an item's content, drawing it if its content
    /// or size changed.
    private func texture(for content: DisplayList.Content, identity: Int, size: CGSize) -> TextureID? {
        if let cached = layers[identity], cached.content == content, cached.size == size, cached.scale == scale {
            return cached.texture
        }
        if let old = layers[identity]?.texture {
            backend.destroyTexture(old)
        }
        var texture: TextureID?
        if size.width > 0, size.height > 0,
           let image = Rasterizer.rasterize(content, size: size, scale: scale, textEngine: textEngine) {
            frameStatistics.rasterizations += 1
            texture = upload(image)
        }
        layers[identity] = CachedLayer(content: content, size: size, scale: scale, texture: texture)
        return texture
    }

    private func imageTexture(_ key: ImageKey, content: ImageContent) -> TextureID? {
        if let cached = images[key] {
            return cached.texture
        }
        let texture = Rasterizer.decode(content).flatMap(upload)
        images[key] = CachedImage(texture: texture)
        return texture
    }

    private func upload(_ image: Silica.CGImage) -> TextureID? {
        frameStatistics.uploads += 1
        return backend.makeTexture(
            width: image.width,
            height: image.height,
            bytesPerRow: image.bytesPerRow,
            pixels: image.data
        )
    }

    private func evictUnused() {
        for (identity, layer) in layers where !presentLayers.contains(identity) {
            if let texture = layer.texture {
                backend.destroyTexture(texture)
            }
            layers[identity] = nil
        }
        for (key, image) in images where !presentImages.contains(key) {
            if let texture = image.texture {
                backend.destroyTexture(texture)
            }
            images[key] = nil
        }
    }

    private func removeAllTextures() {
        for layer in layers.values {
            if let texture = layer.texture { backend.destroyTexture(texture) }
        }
        for image in images.values {
            if let texture = image.texture { backend.destroyTexture(texture) }
        }
        layers.removeAll()
        images.removeAll()
    }

    // MARK: Geometry

    /// A rectangle in points as pixels.
    private func pixelRect(_ rect: CGRect) -> CGRect {
        let minX = (rect.minX * scale).rounded()
        let minY = (rect.minY * scale).rounded()
        let maxX = (rect.maxX * scale).rounded()
        let maxY = (rect.maxY * scale).rounded()
        return CGRect(x: minX, y: minY, width: maxX - minX, height: maxY - minY)
    }

    /// A rasterized item's pixels: at its whole-pixel origin, at its
    /// texture's size, so text stays sharp.
    private func texturePixelRect(_ frame: CGRect) -> CGRect {
        CGRect(
            x: (frame.minX * scale).rounded(),
            y: (frame.minY * scale).rounded(),
            width: max(1, (frame.width * scale).rounded(.up)),
            height: max(1, (frame.height * scale).rounded(.up))
        )
    }
}
