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
import CacaoRender
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
    func beginFrame(width: Int, height: Int, clearColor: ResolvedColor)

    /// Makes a layer the target of drawing, cleared to transparent.
    func beginLayer(_ layer: TextureID)

    /// Returns drawing to the previous target.
    func endLayer()

    /// Fills a rectangle with a color, its opacity already applied.
    func fill(_ rect: CGRect, color: ResolvedColor)

    /// Draws a texture stretched to a rectangle.
    func draw(_ texture: TextureID, in rect: CGRect, opacity: Double, smooth: Bool)

    /// Draws a layer in a rectangle, inside a convex polygon if given.
    func drawLayer(_ layer: TextureID, in rect: CGRect, opacity: Double, mask: [CGPoint]?)

    /// Keeps the target's pixels inside a rectangle only as much as a
    /// layer drawn there is opaque (destination-in), for silhouettes.
    func mask(with layer: TextureID, in rect: CGRect)

    /// Draws a layer stretched to a quadrilateral: its top-leading,
    /// top-trailing, bottom-trailing and bottom-leading corners.
    func drawLayer(_ layer: TextureID, corners: [CGPoint], opacity: Double)

    /// Limits drawing to a rectangle, or removes the limit.
    func setClip(_ rect: CGRect?)

    /// Creates a texture for an external surface's frames of pixels, which
    /// `updateExternalTexture` fills.
    func makeExternalTexture(width: Int, height: Int, format: ExternalSurface.PixelFormat) -> TextureID?

    /// Replaces an external texture's pixels with a frame of its size.
    func updateExternalTexture(_ texture: TextureID, bytesPerRow: Int, pixels: Data)

    /// Imports a shared GPU buffer as a texture, without copying it; `nil`
    /// where the backend can't.
    func importExternalBuffer(_ buffer: ExternalSurface.Buffer) -> TextureID?

    /// Reads back what is drawn so far in a rectangle of the current
    /// target: RGBA pixels, rows top first. `nil` where the backend can't,
    /// or the rectangle is outside the target.
    func readPixels(_ rect: CGRect) -> (pixels: Data, width: Int, height: Int, bytesPerRow: Int)?

    /// Draws an external texture stretched to a rectangle, upside down if
    /// its rows are bottom first, and without blending if it's opaque.
    func drawExternal(_ texture: TextureID, in rect: CGRect, opacity: Double, isOpaque: Bool, isFlipped: Bool, smooth: Bool)

    /// Shows the frame.
    func endFrame()
}

extension CompositorBackend {

    package func importExternalBuffer(_ buffer: ExternalSurface.Buffer) -> TextureID? {
        nil
    }

    package func readPixels(_ rect: CGRect) -> (pixels: Data, width: Int, height: Int, bytesPerRow: Int)? {
        nil
    }
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

        /// External surfaces' frames shown for the first time.
        package var externalFrames = 0

        /// Backdrops read back from the frame and blurred.
        package var backdrops = 0
    }

    /// Items with more pixels than this along either axis are drawn in tiles.
    package static let tilingThreshold = 2048

    /// The side of a tile, in pixels.
    package static let tileSize = 1024

    package let backend: any CompositorBackend

    package let textEngine: SilicaTextEngine

    /// The window's background color.
    package var backgroundColor = ResolvedColor(red: 1, green: 1, blue: 1)

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
        let tint: ResolvedColor?
        let colorMatrix: ColorMatrix?

        init(_ image: ImageContent) {
            self.source = image.source
            self.tint = image.tint
            self.colorMatrix = image.colorMatrix
        }
    }

    private struct Offscreen {
        var texture: TextureID
        var width: Int
        var height: Int
    }

    private var layers: [Int: CachedLayer] = [:]

    private var images: [ImageKey: TextureID?] = [:]

    /// An offscreen layer of an item: its content, at level 0, or a
    /// step of blurring it.
    private struct OffscreenKey: Hashable {
        let identity: Int
        let level: Int
    }

    private var offscreens: [OffscreenKey: Offscreen] = [:]

    /// The texture an external surface's frames of pixels are copied to,
    /// and the frame it holds.
    private struct ExternalTexture {
        var texture: TextureID
        var width: Int
        var height: Int
        var format: ExternalSurface.PixelFormat
        var generation: Int
    }

    private var externalTextures: [ExternalSurface: ExternalTexture] = [:]

    /// The textures an external surface's shared buffers were imported as.
    private var externalBuffers: [ExternalSurface: [TextureID?]] = [:]

    private var presentExternals: Set<ExternalSurface> = []

    /// Textures made for one frame, as backdrops' are: destroyed when the
    /// next frame starts.
    private var transientTextures: [TextureID] = []

    /// The size of the window being drawn, in pixels.
    private var framePixelSize = CGSize.zero

    /// The external surfaces the last frame drew.
    package var externalSurfaces: Set<ExternalSurface> {
        presentExternals
    }

    /// Whether a surface the last frame drew has a newer frame to show.
    package var hasNewExternalFrames: Bool {
        presentExternals.contains { $0.hasNewFrame }
    }

    private var scale: CGFloat = 1

    private var frameStatistics = Statistics()

    private var presentLayers: Set<Int> = []

    private var presentImages: Set<ImageKey> = []

    private var presentOffscreens: Set<OffscreenKey> = []

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
        presentExternals.removeAll(keepingCapacity: true)
        targetOrigins = [CGPoint(x: 0, y: 0)]
        for texture in transientTextures {
            backend.destroyTexture(texture)
        }
        transientTextures.removeAll(keepingCapacity: true)
        framePixelSize = CGSize(width: (size.width * scale).rounded(), height: (size.height * scale).rounded())
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
                    presentImages.insert(ImageKey(image))
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
            case let .effect(.shadow(effect), nested):
                drawShadowed(nested.items, identity: item.identity, shadow: effect, translation: translation, clip: clip, opacity: opacity)
            case let .effect(.blur(effect), nested):
                if effect.radius > 0 {
                    drawBlurred(nested.items, identity: item.identity, effect: effect, translation: translation, clip: clip, opacity: opacity)
                } else {
                    draw(nested.items, translation: translation, clip: clip, opacity: opacity)
                }
            case let .effect(.colorMatrix(matrix), nested):
                draw(nested.items.map { $0.applying(matrix) }, translation: translation, clip: clip, opacity: opacity)
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
                    // The clip shape, drawn anti-aliased, masks the content.
                    let mask = DisplayList.Item(frame: item.frame, identity: Self.maskIdentity(item.identity), version: 0, value: .content(effect.mask))
                    drawMasked(nested.items, identity: item.identity, mask: [mask], translation: translation, clip: clip.intersection(frame), outerClip: clip, opacity: opacity)
                }
            case let .effect(.mask(mask), nested):
                drawMasked(nested.items, identity: item.identity, mask: mask.items, translation: translation, clip: clip, outerClip: clip, opacity: opacity)
            case let .effect(.transform(transform), nested):
                if transform.isTranslation {
                    // Moving only shifts the drawing.
                    draw(nested.items, translation: CGPoint(x: translation.x - transform.tx, y: translation.y - transform.ty), clip: clip, opacity: opacity)
                } else {
                    drawTransformed(nested.items, identity: item.identity, transform: transform, translation: translation, clip: clip, opacity: opacity)
                }
            case let .effect(.scroll(effect), nested):
                let viewport = effect.viewport.offsetBy(dx: -translation.x, dy: -translation.y)
                let visible = clip.intersection(viewport)
                guard !visible.isNull, !visible.isEmpty else {
                    markPresent(nested.items)
                    continue
                }
                // Content that isn't clipped draws wherever its container does.
                let innerClip = effect.isClipDisabled ? clip : visible
                setClip(innerClip)
                draw(
                    nested.items,
                    translation: CGPoint(x: translation.x + effect.offset.x, y: translation.y + effect.offset.y),
                    clip: innerClip,
                    opacity: opacity
                )
                if effect.showsIndicators, effect.indicatorOpacity > 0 {
                    drawIndicators(effect, viewport: viewport, opacity: opacity * effect.indicatorOpacity)
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

    /// The identity of the drawing of a clip's shape, apart from any node's.
    package static func maskIdentity(_ identity: Int) -> Int {
        -identity - 1
    }

    /// Draws the mask's items into one offscreen layer and the items into
    /// another, keeps the items' layer only where the mask's is opaque,
    /// then draws it.
    private func drawMasked(
        _ items: [DisplayList.Item],
        identity: Int,
        mask: [DisplayList.Item],
        translation: CGPoint,
        clip: CGRect,
        outerClip: CGRect,
        opacity: Double
    ) {
        let content = Self.bounds(of: items).offsetBy(dx: -translation.x, dy: -translation.y)
        let maskBounds = Self.bounds(of: mask).offsetBy(dx: -translation.x, dy: -translation.y)
        let visible = content.intersection(maskBounds).intersection(clip)
        guard !visible.isNull, !visible.isEmpty, opacity > 0 else {
            markPresent(items)
            markPresent(mask)
            return
        }
        let pixels = absolutePixelRect(visible)
        let width = Int(pixels.width), height = Int(pixels.height)
        guard width > 0, height > 0, width <= 8192, height <= 8192,
              let layer = offscreen(identity: identity, width: width, height: height),
              let maskLayer = offscreen(identity: identity, level: 1, width: width, height: height) else {
            markPresent(items)
            markPresent(mask)
            return
        }
        let full = CGRect(x: 0, y: 0, width: width, height: height)
        targetOrigins.append(pixels.origin)
        backend.beginLayer(maskLayer)
        draw(mask, translation: translation, clip: visible, opacity: 1)
        backend.setClip(nil)
        backend.endLayer()
        backend.beginLayer(layer)
        draw(items, translation: translation, clip: visible, opacity: 1)
        backend.setClip(nil)
        backend.mask(with: maskLayer, in: full)
        backend.endLayer()
        targetOrigins.removeLast()
        setClip(outerClip)
        backend.drawLayer(layer, in: relative(pixels), opacity: opacity, mask: nil)
        frameStatistics.layers += 2
        frameStatistics.draws += 2
    }

    /// Draws items into an offscreen layer, then its silhouette in the
    /// shadow's color, blurred and moved by the shadow's offset, then the
    /// layer over it.
    private func drawShadowed(
        _ items: [DisplayList.Item],
        identity: Int,
        shadow: ShadowEffect,
        translation: CGPoint,
        clip: CGRect,
        opacity: Double
    ) {
        let spread = Self.blurExtent(shadow.radius)
        let content = Self.bounds(of: items).offsetBy(dx: -translation.x, dy: -translation.y)
        // What shows of the content, or of its moved, blurred shadow.
        let reach = clip.union(clip.offsetBy(dx: -shadow.offset.width, dy: -shadow.offset.height))
            .insetBy(dx: -spread, dy: -spread)
        let visible = content.insetBy(dx: -spread, dy: -spread).intersection(reach)
        guard !visible.isNull, !visible.isEmpty, opacity > 0 else {
            markPresent(items)
            return
        }
        let pixels = absolutePixelRect(visible)
        let width = Int(pixels.width), height = Int(pixels.height)
        guard width > 0, height > 0, width <= 8192, height <= 8192,
              let layer = offscreen(identity: identity, width: width, height: height),
              let silhouette = offscreen(identity: identity, level: 1, width: width, height: height) else {
            markPresent(items)
            return
        }
        let full = CGRect(x: 0, y: 0, width: width, height: height)
        backend.beginLayer(layer)
        targetOrigins.append(pixels.origin)
        draw(items, translation: translation, clip: visible, opacity: 1)
        backend.setClip(nil)
        targetOrigins.removeLast()
        backend.endLayer()
        // The shadow's color, where the content is.
        backend.beginLayer(silhouette)
        var tint = shadow.color
        tint.opacity *= Float(opacity)
        backend.fill(full, color: tint)
        backend.mask(with: layer, in: full)
        backend.endLayer()
        let blurred = blur(silhouette, identity: identity, firstLevel: 2, width: width, height: height, radius: shadow.radius * scale)
        setClip(clip)
        let shadowRect = relative(pixels.offsetBy(dx: shadow.offset.width * scale, dy: shadow.offset.height * scale))
        backend.drawLayer(blurred, in: shadowRect, opacity: 1, mask: nil)
        backend.drawLayer(layer, in: relative(pixels), opacity: opacity, mask: nil)
        frameStatistics.layers += 2
        frameStatistics.draws += 2
    }

    /// Draws items into an offscreen layer, blurs it, then draws it.
    private func drawBlurred(
        _ items: [DisplayList.Item],
        identity: Int,
        effect: BlurEffect,
        translation: CGPoint,
        clip: CGRect,
        opacity: Double
    ) {
        let spread = effect.isOpaque ? 0 : Self.blurExtent(effect.radius)
        let content = Self.bounds(of: items).offsetBy(dx: -translation.x, dy: -translation.y)
        let visible = content.insetBy(dx: -spread, dy: -spread)
            .intersection(clip.insetBy(dx: -spread, dy: -spread))
        guard !visible.isNull, !visible.isEmpty, opacity > 0 else {
            markPresent(items)
            return
        }
        let pixels = absolutePixelRect(visible)
        let width = Int(pixels.width), height = Int(pixels.height)
        guard width > 0, height > 0, width <= 8192, height <= 8192,
              let layer = offscreen(identity: identity, width: width, height: height) else {
            markPresent(items)
            return
        }
        backend.beginLayer(layer)
        targetOrigins.append(pixels.origin)
        draw(items, translation: translation, clip: visible, opacity: 1)
        backend.setClip(nil)
        targetOrigins.removeLast()
        backend.endLayer()
        let blurred = blur(layer, identity: identity, firstLevel: 1, width: width, height: height, radius: effect.radius * scale)
        setClip(effect.isOpaque ? clip.intersection(content) : clip)
        backend.drawLayer(blurred, in: relative(pixels), opacity: opacity, mask: nil)
        if effect.isOpaque {
            setClip(clip)
        }
        frameStatistics.layers += 1
        frameStatistics.draws += 1
    }

    /// How far a blur of a radius spreads content, in points.
    package static func blurExtent(_ radius: CGFloat) -> CGFloat {
        radius > 0 ? (radius * 2).rounded(.up) : 0
    }

    /// Blurs a layer on the GPU: draws it at half its size again and
    /// again, each step averaging pixels by linear filtering, then back up
    /// through the same steps. Returns the layer that ends a step at half
    /// the size, to draw stretched, or the layer itself for no blur.
    private func blur(_ layer: TextureID, identity: Int, firstLevel: Int, width: Int, height: Int, radius: CGFloat) -> TextureID {
        // Each halving widens the blur about twofold.
        var steps = 0
        var reach = radius
        while reach > 1, steps < 7 {
            reach /= 2
            steps += 1
        }
        guard steps > 0 else { return layer }
        var sizes: [(width: Int, height: Int)] = [(width, height)]
        var chain: [TextureID] = [layer]
        for step in 1...steps {
            let size = (width: max(1, (sizes[step - 1].width + 1) / 2), height: max(1, (sizes[step - 1].height + 1) / 2))
            guard let next = offscreen(identity: identity, level: firstLevel + step - 1, width: size.width, height: size.height) else {
                break
            }
            backend.beginLayer(next)
            backend.drawLayer(chain[step - 1], in: CGRect(x: 0, y: 0, width: size.width, height: size.height), opacity: 1, mask: nil)
            backend.endLayer()
            sizes.append(size)
            chain.append(next)
        }
        // Back up to half the size, smoothing the blocks of each step.
        var index = chain.count - 1
        while index > 1 {
            let target = chain[index - 1], size = sizes[index - 1]
            backend.beginLayer(target)
            backend.drawLayer(chain[index], in: CGRect(x: 0, y: 0, width: size.width, height: size.height), opacity: 1, mask: nil)
            backend.endLayer()
            index -= 1
        }
        frameStatistics.layers += 2 * (chain.count - 1) - 1
        return chain.count > 1 ? chain[1] : layer
    }

    /// Draws items into an offscreen layer, untransformed, then draws the
    /// layer through the transform.
    private func drawTransformed(
        _ items: [DisplayList.Item],
        identity: Int,
        transform: Transform2D,
        translation: CGPoint,
        clip: CGRect,
        opacity: Double
    ) {
        let rootBounds = Self.bounds(of: items)
        guard !rootBounds.isNull, !rootBounds.isEmpty, opacity > 0 else {
            markPresent(items)
            return
        }
        let bounds = rootBounds.offsetBy(dx: -translation.x, dy: -translation.y)
        let pixels = absolutePixelRect(bounds)
        let width = Int(pixels.width), height = Int(pixels.height)
        guard width > 0, height > 0, width <= 8192, height <= 8192,
              let layer = offscreen(identity: identity, width: width, height: height) else {
            markPresent(items)
            return
        }
        backend.beginLayer(layer)
        targetOrigins.append(pixels.origin)
        draw(items, translation: translation, clip: bounds, opacity: 1)
        backend.setClip(nil)
        targetOrigins.removeLast()
        backend.endLayer()
        setClip(clip)
        // The layer's corners, transformed in the root's space, on screen.
        let rootPixels = CGRect(
            x: pixels.minX / scale + translation.x,
            y: pixels.minY / scale + translation.y,
            width: pixels.width / scale,
            height: pixels.height / scale
        )
        let corners = [
            CGPoint(x: rootPixels.minX, y: rootPixels.minY),
            CGPoint(x: rootPixels.maxX, y: rootPixels.minY),
            CGPoint(x: rootPixels.maxX, y: rootPixels.maxY),
            CGPoint(x: rootPixels.minX, y: rootPixels.maxY),
        ].map { corner -> CGPoint in
            let moved = transform.apply(corner)
            return relative(CGPoint(x: (moved.x - translation.x) * scale, y: (moved.y - translation.y) * scale))
        }
        backend.drawLayer(layer, corners: corners, opacity: opacity)
        frameStatistics.layers += 1
        frameStatistics.draws += 1
    }

    /// Keeps the textures of items that are present but not drawn.
    private func markPresent(_ items: [DisplayList.Item]) {
        for item in items {
            switch item.value {
            case let .content(.image(image)):
                presentLayers.insert(item.identity)
                presentImages.insert(ImageKey(image))
            case let .content(.external(external)):
                presentExternals.insert(external.surface)
            case .content:
                presentLayers.insert(item.identity)
            case let .effect(.clip(effect), nested):
                if !effect.isRectangle {
                    presentLayers.insert(Self.maskIdentity(item.identity))
                }
                markPresent(nested.items)
            case let .effect(.mask(mask), nested):
                markPresent(mask.items)
                markPresent(nested.items)
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
        case .text, .shape, .drawing:
            drawRasterized(content, identity: identity, frame: frame, clip: clip, opacity: opacity)
        case let .image(image):
            let key = ImageKey(image)
            guard let texture = imageTexture(key, content: image) else {
                return
            }
            backend.draw(texture, in: pixelRect(frame), opacity: opacity, smooth: image.interpolation != .none)
            frameStatistics.draws += 1
        case let .external(external):
            drawExternal(external, frame: frame, opacity: opacity)
        case let .backdrop(backdrop):
            drawBackdrop(backdrop, frame: frame, clip: clip, opacity: opacity)
        }
    }

    /// Draws what the frame shows so far behind a rectangle, blurred: read
    /// back from the backend, blurred small on the CPU, and drawn as a
    /// texture the GPU scales up.
    private func drawBackdrop(_ content: BackdropContent, frame: CGRect, clip: CGRect, opacity: Double) {
        let sigma = content.blurRadius * scale
        let shown = frame.intersection(clip)
        guard sigma >= 1, !shown.isNull, shown.width > 0, shown.height > 0 else { return }
        let pixelFrame = pixelRect(frame)
        var visible = pixelRect(shown)
        // The window's edges, when drawing to the window; a layer's are the
        // backend's to know.
        var limit = CGSize(width: CGFloat.infinity, height: CGFloat.infinity)
        if targetOrigins.count == 1 {
            limit = framePixelSize
            visible = visible.intersection(CGRect(origin: CGPoint(x: 0, y: 0), size: limit))
        }
        guard !visible.isNull, visible.width >= 1, visible.height >= 1 else { return }
        // What the blur reads past the edges, with the edges aligned to the
        // shrinking.
        let shrink = BackdropBlur.shrink(sigma: sigma)
        let reach = BackdropBlur.reach(sigma: sigma)
        let left = max(Int(visible.minX) - reach, 0) / shrink * shrink
        let top = max(Int(visible.minY) - reach, 0) / shrink * shrink
        let right = Int(min(visible.maxX.rounded(.up) + CGFloat(reach), limit.width))
        let bottom = Int(min(visible.maxY.rounded(.up) + CGFloat(reach), limit.height))
        guard right > left, bottom > top else { return }
        backend.setClip(nil)
        defer { setClip(clip) }
        guard let read = backend.readPixels(CGRect(x: left, y: top, width: right - left, height: bottom - top)) else {
            return
        }
        let blurred = BackdropBlur.blur(
            pixels: read.pixels,
            width: read.width,
            height: read.height,
            bytesPerRow: read.bytesPerRow,
            origin: (left, top),
            sigma: sigma,
            saturation: content.saturation,
            rounding: content.cornerRadius > 0
                ? (pixelFrame, content.cornerRadius * scale, content.corners)
                : nil
        )
        guard let texture = backend.makeTexture(
            width: blurred.width, height: blurred.height, bytesPerRow: blurred.width * 4, pixels: blurred.pixels
        ) else {
            return
        }
        transientTextures.append(texture)
        frameStatistics.backdrops += 1
        frameStatistics.uploads += 1
        // Only inside the frame, though the blur read past it.
        backend.setClip(visible)
        backend.draw(
            texture,
            in: CGRect(x: left, y: top, width: blurred.width * blurred.shrink, height: blurred.height * blurred.shrink),
            opacity: opacity,
            smooth: true
        )
        frameStatistics.draws += 1
    }

    /// Draws an external surface's newest frame: from a shared buffer,
    /// imported once, or from its pixels, copied into one texture.
    private func drawExternal(_ content: ExternalContent, frame: CGRect, opacity: Double) {
        let surface = content.surface
        presentExternals.insert(surface)
        let rect = pixelRect(frame)
        if surface.usesBuffers {
            // Until the first frame is finished, there's nothing to show.
            guard let taken = surface.takeBuffer(), taken.index < surface.buffers.count else { return }
            var textures = externalBuffers[surface] ?? Array(repeating: nil, count: surface.buffers.count)
            if textures[taken.index] == nil {
                textures[taken.index] = backend.importExternalBuffer(surface.buffers[taken.index])
            }
            if let texture = textures[taken.index] {
                externalBuffers[surface] = textures
                frameStatistics.externalFrames += taken.frames
                backend.drawExternal(
                    texture, in: rect, opacity: opacity, isOpaque: surface.isOpaque,
                    isFlipped: surface.bufferRowOrder == .bottomFirst, smooth: content.isSmooth
                )
                frameStatistics.draws += 1
                return
            }
            // The buffers can't be imported: the producer publishes pixels
            // from now on.
            for texture in textures.compactMap({ $0 }) { backend.destroyTexture(texture) }
            externalBuffers[surface] = nil
            surface.failBuffers()
        }
        guard let pixels = surface.takeFrame(), pixels.width > 0, pixels.height > 0 else { return }
        var entry = externalTextures[surface]
        if let current = entry, current.width != pixels.width || current.height != pixels.height || current.format != pixels.format {
            backend.destroyTexture(current.texture)
            entry = nil
        }
        if entry == nil {
            guard let texture = backend.makeExternalTexture(width: pixels.width, height: pixels.height, format: pixels.format) else {
                externalTextures[surface] = nil
                return
            }
            entry = ExternalTexture(
                texture: texture, width: pixels.width, height: pixels.height,
                format: pixels.format, generation: pixels.generation &- 1
            )
        }
        guard var current = entry else { return }
        if current.generation != pixels.generation {
            backend.updateExternalTexture(current.texture, bytesPerRow: pixels.bytesPerRow, pixels: pixels.pixels)
            frameStatistics.uploads += 1
            frameStatistics.externalFrames += 1
            current.generation = pixels.generation
        }
        externalTextures[surface] = current
        backend.drawExternal(
            current.texture, in: rect, opacity: opacity, isOpaque: pixels.isOpaque,
            isFlipped: pixels.rowOrder == .bottomFirst, smooth: content.isSmooth
        )
        frameStatistics.draws += 1
    }

    private func drawIndicators(_ effect: ScrollEffect, viewport: CGRect, opacity: Double) {
        let thickness: CGFloat = 3
        let inset: CGFloat = 2
        let color = ResolvedColor(red: 0.5, green: 0.5, blue: 0.5, opacity: Float(0.6 * opacity))
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

    private func offscreen(identity: Int, level: Int = 0, width: Int, height: Int) -> TextureID? {
        let key = OffscreenKey(identity: identity, level: level)
        presentOffscreens.insert(key)
        if let existing = offscreens[key], existing.width == width, existing.height == height {
            return existing.texture
        }
        if let existing = offscreens[key] {
            backend.destroyTexture(existing.texture)
        }
        guard let texture = backend.makeLayer(width: width, height: height) else {
            offscreens[key] = nil
            return nil
        }
        offscreens[key] = Offscreen(texture: texture, width: width, height: height)
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
        for (key, offscreen) in offscreens where !presentOffscreens.contains(key) {
            backend.destroyTexture(offscreen.texture)
            offscreens[key] = nil
        }
        for (surface, external) in externalTextures where !presentExternals.contains(surface) {
            backend.destroyTexture(external.texture)
            externalTextures[surface] = nil
        }
        for (surface, textures) in externalBuffers where !presentExternals.contains(surface) {
            for texture in textures.compactMap({ $0 }) { backend.destroyTexture(texture) }
            externalBuffers[surface] = nil
        }
    }

    private func removeAllTextures() {
        for layer in layers.values {
            for texture in layer.tiles.values.compactMap({ $0 }) { backend.destroyTexture(texture) }
        }
        for texture in images.values.compactMap({ $0 }) { backend.destroyTexture(texture) }
        for offscreen in offscreens.values { backend.destroyTexture(offscreen.texture) }
        for external in externalTextures.values { backend.destroyTexture(external.texture) }
        for textures in externalBuffers.values {
            for texture in textures.compactMap({ $0 }) { backend.destroyTexture(texture) }
        }
        for texture in transientTextures { backend.destroyTexture(texture) }
        transientTextures.removeAll()
        externalTextures.removeAll()
        externalBuffers.removeAll()
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
            case let .effect(.shadow(shadow), nested):
                let content = bounds(of: nested.items)
                let spread = blurExtent(shadow.radius)
                result = result.union(content).union(content.offsetBy(dx: shadow.offset.width, dy: shadow.offset.height).insetBy(dx: -spread, dy: -spread))
            case let .effect(.blur(effect), nested):
                let spread = effect.isOpaque ? 0 : blurExtent(effect.radius)
                result = result.union(bounds(of: nested.items).insetBy(dx: -spread, dy: -spread))
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
