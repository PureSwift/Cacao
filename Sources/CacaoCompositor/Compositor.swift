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

/// A texture or layer created by a compositor backend.
package struct TextureID: Hashable, Sendable {

    package let rawValue: Int

    package init(rawValue: Int) {
        self.rawValue = rawValue
    }
}

/// The GPU operations the compositor needs. Rectangles are in pixels, in
/// the coordinate space of the current target: the window, or a layer.
@MainActor
package protocol CompositorBackend: AnyObject {

    /// Creates a texture from premultiplied RGBA pixels, rows top to bottom.
    func makeTexture(width: Int, height: Int, bytesPerRow: Int, pixels: Data) -> TextureID?

    /// Creates an offscreen layer that can be drawn into and then drawn.
    func makeLayer(width: Int, height: Int) -> TextureID?

    /// Destroys a texture or layer.
    func destroyTexture(_ texture: TextureID)

    /// Starts a frame of the given size, cleared to a color.
    func beginFrame(width: Int, height: Int, clearColor: Color.Resolved)

    /// Makes a layer the target of drawing, cleared to transparent.
    func beginLayer(_ layer: TextureID)

    /// Returns drawing to the previous target.
    func endLayer()

    /// Fills a rectangle with a color, its opacity already applied.
    func fill(_ rect: CGRect, color: Color.Resolved)

    /// Draws a texture stretched to a rectangle.
    func draw(_ texture: TextureID, in rect: CGRect, opacity: Double, smooth: Bool)

    /// Draws a layer in a rectangle, inside a convex polygon if given.
    func drawLayer(_ layer: TextureID, in rect: CGRect, opacity: Double, mask: [CGPoint]?)

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
/// content that was already drawn. Items larger than a tile are drawn in
/// tiles, and only the tiles that show.
///
/// Group effects (opacity over several items, shape clips and compositing
/// groups) draw into offscreen layers from the cached textures, then draw
/// the layer: GPU work only.
@MainActor
package final class Compositor {

    /// Counts of the compositor's work.
    package struct Statistics: Equatable, Sendable {

        /// Items (or tiles of items) whose content was drawn with Silica.
        package var rasterizations = 0

        /// Textures created.
        package var uploads = 0

        /// Fills, texture and layer draws sent to the backend.
        package var draws = 0

        /// Offscreen layers drawn.
        package var layers = 0

        /// Textures alive after the frame.
        package var textures = 0
    }

    /// Items with more pixels than this along either axis are drawn in tiles.
    package static let tilingThreshold = 2048

    /// The side of a tile, in pixels.
    package static let tileSize = 1024

    package let backend: any CompositorBackend

    package let textEngine: SilicaTextEngine

    /// The window's background color.
    package var backgroundColor = Color.Resolved(red: 1, green: 1, blue: 1)

    /// The work done by the last frame.
    package private(set) var lastFrame = Statistics()

    /// The work done by all frames.
    package private(set) var total = Statistics()

    private struct TileKey: Hashable {
        let column: Int
        let row: Int
    }

    private struct CachedLayer {
        var content: DisplayList.Content
        var size: CGSize
        var scale: CGFloat
        /// One texture, or one per tile.
        var tiles: [TileKey: TextureID?] = [:]
    }

    private struct ImageKey: Hashable {
        let source: ImageSource
        let tint: Color.Resolved?
    }

    private struct Offscreen {
        var texture: TextureID
        var width: Int
        var height: Int
    }

    private var layers: [Int: CachedLayer] = [:]

    private var images: [ImageKey: TextureID?] = [:]

    private var offscreens: [Int: Offscreen] = [:]

    private var scale: CGFloat = 1

    private var frameStatistics = Statistics()

    private var presentLayers: Set<Int> = []

    private var presentImages: Set<ImageKey> = []

    private var presentOffscreens: Set<Int> = []

    /// The pixel origin of each target, the window first.
    private var targetOrigins: [CGPoint] = [CGPoint(x: 0, y: 0)]

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
        presentOffscreens.removeAll(keepingCapacity: true)
        targetOrigins = [CGPoint(x: 0, y: 0)]
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
        frameStatistics.textures = layers.values.reduce(0) { $0 + $1.tiles.values.compactMap { $0 }.count }
            + images.values.compactMap { $0 }.count
            + offscreens.count
        lastFrame = frameStatistics
        total.rasterizations += frameStatistics.rasterizations
        total.uploads += frameStatistics.uploads
        total.draws += frameStatistics.draws
        total.layers += frameStatistics.layers
        total.textures = frameStatistics.textures
    }

    // MARK: Drawing

    private func draw(_ items: [DisplayList.Item], translation: CGPoint, clip: CGRect, opacity: Double) {
        for item in items {
            switch item.value {
            case let .content(content):
                presentLayers.insert(item.identity)
                if case let .image(image) = content {
                    presentImages.insert(ImageKey(source: image.source, tint: image.tint))
                }
                let frame = item.frame.offsetBy(dx: -translation.x, dy: -translation.y)
                let outset = Rasterizer.outset(of: content)
                guard frame.insetBy(dx: -outset, dy: -outset).intersects(clip), opacity > 0 else {
                    continue
                }
                draw(content, identity: item.identity, frame: frame, clip: clip, opacity: opacity)
            case let .effect(.opacity(value), nested):
                if value >= 1 {
                    draw(nested.items, translation: translation, clip: clip, opacity: opacity)
                } else if Self.isSingleContent(nested.items) {
                    // One item can't overlap itself: no layer needed.
                    draw(nested.items, translation: translation, clip: clip, opacity: opacity * value)
                } else {
                    let bounds = Self.bounds(of: nested.items).offsetBy(dx: -translation.x, dy: -translation.y)
                    drawGroup(nested.items, identity: item.identity, bounds: bounds, translation: translation, clip: clip, opacity: opacity * value, mask: nil)
                }
            case let .effect(.compositingGroup, nested):
                let bounds = Self.bounds(of: nested.items).offsetBy(dx: -translation.x, dy: -translation.y)
                drawGroup(nested.items, identity: item.identity, bounds: bounds, translation: translation, clip: clip, opacity: opacity, mask: nil)
            case let .effect(.clip(effect), nested):
                let frame = item.frame.offsetBy(dx: -translation.x, dy: -translation.y)
                if effect.isRectangle {
                    let innerClip = clip.intersection(frame)
                    guard !innerClip.isNull, !innerClip.isEmpty else {
                        markPresent(nested.items)
                        continue
                    }
                    setClip(innerClip)
                    draw(nested.items, translation: translation, clip: innerClip, opacity: opacity)
                    setClip(clip)
                } else {
                    let mask = Self.polygon(effect.path).map { CGPoint(x: $0.x + frame.minX, y: $0.y + frame.minY) }
                    drawGroup(nested.items, identity: item.identity, bounds: frame, translation: translation, clip: clip, opacity: opacity, mask: mask)
                }
            case let .effect(.scroll(effect), nested):
                let viewport = effect.viewport.offsetBy(dx: -translation.x, dy: -translation.y)
                let innerClip = clip.intersection(viewport)
                guard !innerClip.isNull, !innerClip.isEmpty else {
                    markPresent(nested.items)
                    continue
                }
                setClip(innerClip)
                draw(
                    nested.items,
                    translation: CGPoint(x: translation.x + effect.offset.x, y: translation.y + effect.offset.y),
                    clip: innerClip,
                    opacity: opacity
                )
                if effect.showsIndicators {
                    drawIndicators(effect, viewport: viewport, opacity: opacity)
                }
                setClip(clip)
            }
        }
    }

    /// Draws items into an offscreen layer covering `bounds` (in points on
    /// the window), then draws the layer with an opacity, inside a polygon
    /// mask (in points on the window) if given.
    private func drawGroup(
        _ items: [DisplayList.Item],
        identity: Int,
        bounds: CGRect,
        translation: CGPoint,
        clip: CGRect,
        opacity: Double,
        mask: [CGPoint]?
    ) {
        let visible = bounds.intersection(clip)
        guard !visible.isNull, !visible.isEmpty, opacity > 0 else {
            markPresent(items)
            return
        }
        let pixels = absolutePixelRect(visible)
        let width = Int(pixels.width), height = Int(pixels.height)
        guard width > 0, height > 0, let layer = offscreen(identity: identity, width: width, height: height) else {
            markPresent(items)
            return
        }
        backend.beginLayer(layer)
        targetOrigins.append(pixels.origin)
        draw(items, translation: translation, clip: visible, opacity: 1)
        backend.setClip(nil)
        targetOrigins.removeLast()
        backend.endLayer()
        setClip(clip)
        let maskPixels = mask.map { points in
            points.map { relative(CGPoint(x: $0.x * scale, y: $0.y * scale)) }
        }
        backend.drawLayer(layer, in: relative(pixels), opacity: opacity, mask: maskPixels)
        frameStatistics.layers += 1
        frameStatistics.draws += 1
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

    private func draw(_ content: DisplayList.Content, identity: Int, frame: CGRect, clip: CGRect, opacity: Double) {
        switch content {
        case let .color(color):
            var color = color
            color.opacity *= Float(opacity)
            backend.fill(pixelRect(frame), color: color)
            frameStatistics.draws += 1
        case .text, .shape:
            drawRasterized(content, identity: identity, frame: frame, clip: clip, opacity: opacity)
        case let .image(image):
            let key = ImageKey(source: image.source, tint: image.tint)
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

    /// Draws text or a shape from its cached texture or tiles, rasterizing
    /// those that are missing and visible.
    private func drawRasterized(_ content: DisplayList.Content, identity: Int, frame: CGRect, clip: CGRect, opacity: Double) {
        if let cached = layers[identity], cached.content != content || cached.size != frame.size || cached.scale != scale {
            for texture in cached.tiles.values.compactMap({ $0 }) {
                backend.destroyTexture(texture)
            }
            layers[identity] = nil
        }
        var cached = layers[identity] ?? CachedLayer(content: content, size: frame.size, scale: scale)
        let outset = Rasterizer.outset(of: content)
        let drawn = frame.insetBy(dx: -outset, dy: -outset)
        let origin = CGPoint(x: (drawn.minX * scale).rounded(), y: (drawn.minY * scale).rounded())
        let pixelWidth = max(1, Int((drawn.width * scale).rounded(.up)))
        let pixelHeight = max(1, Int((drawn.height * scale).rounded(.up)))
        let tiled = pixelWidth > Self.tilingThreshold || pixelHeight > Self.tilingThreshold
        let tile = Self.tileSize
        // The tiles that show: those intersecting the clip, in the item's pixels.
        let visible = CGRect(
            x: clip.minX * scale - origin.x,
            y: clip.minY * scale - origin.y,
            width: clip.width * scale,
            height: clip.height * scale
        )
        let columns = tiled
            ? max(0, Int(visible.minX) / tile)...max(0, min((pixelWidth - 1) / tile, Int(visible.maxX) / tile))
            : 0...0
        let rows = tiled
            ? max(0, Int(visible.minY) / tile)...max(0, min((pixelHeight - 1) / tile, Int(visible.maxY) / tile))
            : 0...0
        for row in rows {
            for column in columns {
                let key = TileKey(column: column, row: row)
                let region = tiled
                    ? CGRect(
                        x: column * tile,
                        y: row * tile,
                        width: min(tile, pixelWidth - column * tile),
                        height: min(tile, pixelHeight - row * tile)
                    )
                    : CGRect(x: 0, y: 0, width: pixelWidth, height: pixelHeight)
                guard region.width > 0, region.height > 0 else { continue }
                let texture: TextureID?
                if let existing = cached.tiles[key] {
                    texture = existing
                } else {
                    let image = Rasterizer.rasterize(
                        content,
                        size: frame.size,
                        scale: scale,
                        region: tiled ? region : nil,
                        textEngine: textEngine
                    )
                    if image != nil {
                        frameStatistics.rasterizations += 1
                    }
                    texture = image.flatMap(upload)
                    cached.tiles[key] = texture
                }
                guard let texture else { continue }
                let target = CGRect(x: origin.x + region.minX, y: origin.y + region.minY, width: region.width, height: region.height)
                backend.draw(texture, in: relative(target), opacity: opacity, smooth: false)
                frameStatistics.draws += 1
            }
        }
        layers[identity] = cached
    }

    private func imageTexture(_ key: ImageKey, content: ImageContent) -> TextureID? {
        if let cached = images[key] {
            return cached
        }
        let texture = Rasterizer.decode(content).flatMap(upload)
        images[key] = texture
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

    private func offscreen(identity: Int, width: Int, height: Int) -> TextureID? {
        presentOffscreens.insert(identity)
        if let existing = offscreens[identity], existing.width == width, existing.height == height {
            return existing.texture
        }
        if let existing = offscreens[identity] {
            backend.destroyTexture(existing.texture)
        }
        guard let texture = backend.makeLayer(width: width, height: height) else {
            offscreens[identity] = nil
            return nil
        }
        offscreens[identity] = Offscreen(texture: texture, width: width, height: height)
        return texture
    }

    private func evictUnused() {
        for (identity, layer) in layers where !presentLayers.contains(identity) {
            for texture in layer.tiles.values.compactMap({ $0 }) {
                backend.destroyTexture(texture)
            }
            layers[identity] = nil
        }
        for (key, texture) in images where !presentImages.contains(key) {
            if let texture { backend.destroyTexture(texture) }
            images[key] = nil
        }
        for (identity, offscreen) in offscreens where !presentOffscreens.contains(identity) {
            backend.destroyTexture(offscreen.texture)
            offscreens[identity] = nil
        }
    }

    private func removeAllTextures() {
        for layer in layers.values {
            for texture in layer.tiles.values.compactMap({ $0 }) { backend.destroyTexture(texture) }
        }
        for texture in images.values.compactMap({ $0 }) { backend.destroyTexture(texture) }
        for offscreen in offscreens.values { backend.destroyTexture(offscreen.texture) }
        layers.removeAll()
        images.removeAll()
        offscreens.removeAll()
    }

    // MARK: Geometry

    /// A rectangle in points as pixels on the window, snapped to whole pixels.
    private func absolutePixelRect(_ rect: CGRect) -> CGRect {
        let minX = (rect.minX * scale).rounded()
        let minY = (rect.minY * scale).rounded()
        let maxX = (rect.maxX * scale).rounded()
        let maxY = (rect.maxY * scale).rounded()
        return CGRect(x: minX, y: minY, width: maxX - minX, height: maxY - minY)
    }

    /// A rectangle in points as pixels on the current target.
    private func pixelRect(_ rect: CGRect) -> CGRect {
        relative(absolutePixelRect(rect))
    }

    /// A rectangle in window pixels on the current target.
    private func relative(_ rect: CGRect) -> CGRect {
        let origin = targetOrigins.last!
        return rect.offsetBy(dx: -origin.x, dy: -origin.y)
    }

    private func relative(_ point: CGPoint) -> CGPoint {
        let origin = targetOrigins.last!
        return CGPoint(x: point.x - origin.x, y: point.y - origin.y)
    }

    private func setClip(_ rect: CGRect) {
        backend.setClip(pixelRect(rect))
    }

    /// Whether a list draws exactly one content item, with no effects.
    private static func isSingleContent(_ items: [DisplayList.Item]) -> Bool {
        guard items.count == 1 else { return false }
        if case .content = items[0].value { return true }
        return false
    }

    /// The union of a list's frames, including nested lists, unscrolled.
    private static func bounds(of items: [DisplayList.Item]) -> CGRect {
        var result = CGRect.null
        for item in items {
            switch item.value {
            case let .content(content):
                let outset = Rasterizer.outset(of: content)
                result = result.union(item.frame.insetBy(dx: -outset, dy: -outset))
            case .effect(.scroll, _), .effect(.clip, _):
                result = result.union(item.frame)
            case let .effect(_, nested):
                result = result.union(bounds(of: nested.items))
            }
        }
        return result
    }

    /// A path flattened into a polygon, approximating curves.
    package static func polygon(_ path: Path, segments: Int = 8) -> [CGPoint] {
        var points: [CGPoint] = []
        var last = CGPoint(x: 0, y: 0)
        path.forEach { element in
            switch element {
            case let .move(to), let .line(to):
                points.append(to)
                last = to
            case let .quadCurve(to, control):
                for step in 1...segments {
                    let t = CGFloat(step) / CGFloat(segments), u = 1 - t
                    points.append(CGPoint(
                        x: u * u * last.x + 2 * u * t * control.x + t * t * to.x,
                        y: u * u * last.y + 2 * u * t * control.y + t * t * to.y
                    ))
                }
                last = to
            case let .curve(to, c1, c2):
                for step in 1...segments {
                    let t = CGFloat(step) / CGFloat(segments), u = 1 - t
                    let a = u * u * u, b = 3 * u * u * t, c = 3 * u * t * t, d = t * t * t
                    points.append(CGPoint(
                        x: a * last.x + b * c1.x + c * c2.x + d * to.x,
                        y: a * last.y + b * c1.y + c * c2.y + d * to.y
                    ))
                }
                last = to
            case .closeSubpath:
                break
            }
        }
        return points
    }
}
