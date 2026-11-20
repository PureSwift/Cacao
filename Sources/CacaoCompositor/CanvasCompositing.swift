//
//  CanvasCompositing.swift
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

// MARK: - Flattening

extension DrawingContent {

    /// The drawing with views' drawings (canvas symbols) as plain
    /// operations, in the coordinates of the operations' transforms.
    package func flattened() -> DrawingContent {
        DrawingContent(operations: operations.flatMap { operation -> [Operation] in
            switch operation {
            case let .items(items, state):
                return items.flatMap { DrawingContent.operations(of: $0, state: state) }
            case let .layer(content, state):
                return [.layer(content.flattened(), state)]
            default:
                return [operation]
            }
        })
    }

    /// The operations that draw a display list item.
    private static func operations(of item: DisplayList.Item, state: DrawingState) -> [Operation] {
        let frame = item.frame
        var local = state
        local.transform = Transform2D.translation(frame.minX, frame.minY).concatenating(state.transform)
        switch item.value {
        case let .content(.color(color)):
            let shape = ShapeContent(path: Path(CGRect(origin: CGPoint(x: 0, y: 0), size: frame.size)), color: color, drawing: .fill(FillStyle()))
            return [.shape(shape, local)]
        case let .content(.text(text)):
            return [.text(text, CGRect(origin: CGPoint(x: 0, y: 0), size: frame.size), local)]
        case let .content(.shape(shape)):
            return [.shape(shape, local)]
        case let .content(.image(image)):
            return [.image(image, CGRect(origin: CGPoint(x: 0, y: 0), size: frame.size), local)]
        case let .content(.drawing(drawing)):
            return drawing.flattened().operations.map { $0.composed(with: local) }
        case .content(.external):
            // A canvas symbol is drawn once, in software; frames drawn
            // outside the compositor aren't part of it.
            return []
        case let .effect(.opacity(opacity), nested):
            var faded = state
            faded.opacity *= opacity
            return nested.items.flatMap { operations(of: $0, state: faded) }
        case let .effect(.transform(transform), nested):
            var moved = state
            moved.transform = transform.concatenating(state.transform)
            return nested.items.flatMap { operations(of: $0, state: moved) }
        case let .effect(.clip(clip), nested):
            var clipped = state
            clipped.clips.append(DrawingClip(path: clip.path, transform: local.transform, isEOFilled: clip.isEOFilled))
            return nested.items.flatMap { operations(of: $0, state: clipped) }
        case let .effect(.colorMatrix(matrix), nested):
            return nested.items.flatMap { operations(of: $0.applying(matrix), state: state) }
        case let .effect(.scroll(scroll), nested):
            var clipped = state
            clipped.clips.append(DrawingClip(path: Path(scroll.viewport), transform: state.transform, isEOFilled: false))
            clipped.transform = Transform2D.translation(-scroll.offset.x, -scroll.offset.y).concatenating(state.transform)
            return nested.items.flatMap { operations(of: $0, state: clipped) }
        case let .effect(.shadow(shadow), nested):
            var shadowed = state
            shadowed.filters.append(.shadow(color: shadow.color, radius: shadow.radius, offset: shadow.offset, blendMode: .normal, placement: .below, invertsAlpha: false))
            return [.layer(DrawingContent(operations: nested.items.flatMap { operations(of: $0, state: state.stripped) }), shadowed)]
        case let .effect(.blur(blur), nested):
            var blurred = state
            blurred.filters.append(.blur(radius: blur.radius, isOpaque: blur.isOpaque))
            return [.layer(DrawingContent(operations: nested.items.flatMap { operations(of: $0, state: state.stripped) }), blurred)]
        case let .effect(_, nested):
            return nested.items.flatMap { operations(of: $0, state: state) }
        }
    }

    /// Whether any operation composites on its own.
    var needsCompositing: Bool {
        operations.contains { operation in
            if case .layer = operation { return true }
            return operation.state.isComposited
        }
    }
}

extension DrawingContent.Operation {

    /// The operation drawn within another state: transforms concatenated,
    /// opacities multiplied, clips and filters added.
    func composed(with outer: DrawingState) -> DrawingContent.Operation {
        var state = self.state
        state.transform = state.transform.concatenating(outer.transform)
        state.opacity *= outer.opacity
        state.clips = outer.clips + state.clips.map { clip in
            var clip = clip
            clip.transform = clip.transform.concatenating(outer.transform)
            return clip
        }
        return replacingState(state)
    }

    func replacingState(_ state: DrawingState) -> DrawingContent.Operation {
        switch self {
        case let .shape(shape, _): .shape(shape, state)
        case let .text(text, rect, _): .text(text, rect, state)
        case let .image(image, rect, _): .image(image, rect, state)
        case let .tiledImage(path, isEOFilled, image, origin, scale, _): .tiledImage(path, isEOFilled: isEOFilled, image, origin: origin, scale: scale, state)
        case let .items(items, _): .items(items, state)
        case let .layer(content, _): .layer(content, state)
        }
    }
}

extension DrawingState {

    /// The state without what composites the command on its own, nor
    /// opacity: what draws its pixels.
    var stripped: DrawingState {
        var state = self
        state.blendMode = .normal
        state.filters = []
        state.masks = []
        state.opacity = 1
        return state
    }
}

// MARK: - Pixels

/// Premultiplied RGBA pixels, from 0 to 1.
struct PixelBuffer {

    let width: Int

    let height: Int

    var pixels: [Float]

    init(width: Int, height: Int) {
        self.width = width
        self.height = height
        self.pixels = [Float](repeating: 0, count: width * height * 4)
    }

    init?(_ image: Silica.CGImage?, width: Int, height: Int) {
        self.init(width: width, height: height)
        guard let image else { return nil }
        image.data.withUnsafeBytes { (bytes: UnsafeRawBufferPointer) in
            for row in 0..<min(height, image.height) {
                for column in 0..<min(width, image.width) {
                    let source = row * image.bytesPerRow + column * 4
                    let target = (row * width + column) * 4
                    for channel in 0..<4 {
                        pixels[target + channel] = Float(bytes[source + channel]) / 255
                    }
                }
            }
        }
    }

    var image: Silica.CGImage {
        var data = Data(count: width * height * 4)
        data.withUnsafeMutableBytes { (bytes: UnsafeMutableRawBufferPointer) in
            for index in 0..<(width * height * 4) {
                bytes[index] = UInt8(max(0, min(255, (pixels[index] * 255).rounded())))
            }
        }
        return Silica.CGImage(width: width, height: height, bytesPerRow: width * 4, data: data)
    }
}

// MARK: - Compositing

extension Rasterizer {

    /// Draws a drawing into a bitmap of `pixels`, compositing commands with
    /// blend modes, filters and masks, and layers, on their own: each into
    /// its own bitmap, processed, then blended into the result. Runs of
    /// plain commands draw together with Silica. `base` sets up a context's
    /// transform from the drawing's coordinates to pixels.
    @MainActor
    static func composite(
        _ drawing: DrawingContent,
        pixels: CGSize,
        scale: CGFloat,
        textEngine: SilicaTextEngine,
        base: @escaping (Silica.CGContext) -> Void
    ) -> Silica.CGImage? {
        compositeBuffer(drawing, width: Int(pixels.width), height: Int(pixels.height), scale: scale, textEngine: textEngine, base: base).image
    }

    @MainActor
    private static func compositeBuffer(
        _ drawing: DrawingContent,
        width: Int,
        height: Int,
        scale: CGFloat,
        textEngine: SilicaTextEngine,
        base: @escaping (Silica.CGContext) -> Void
    ) -> PixelBuffer {
        var result = PixelBuffer(width: width, height: height)
        var plain: [DrawingContent.Operation] = []
        func render(_ operations: [DrawingContent.Operation]) -> PixelBuffer {
            let image = try? draw(size: CGSize(width: width, height: height)) { context in
                base(context)
                draw(DrawingContent(operations: operations), in: context, scale: scale, textEngine: textEngine)
            }
            return PixelBuffer(image, width: width, height: height) ?? PixelBuffer(width: width, height: height)
        }
        func flushPlain() {
            guard !plain.isEmpty else { return }
            blend(render(plain), onto: &result, mode: .normal, opacity: 1)
            plain = []
        }
        for operation in drawing.operations {
            let state = operation.state
            let isLayer: Bool
            if case .layer = operation { isLayer = true } else { isLayer = false }
            guard isLayer || state.isComposited else {
                plain.append(operation)
                continue
            }
            flushPlain()
            guard state.opacity > 0 else { continue }
            var source: PixelBuffer
            if case let .layer(content, _) = operation {
                source = compositeBuffer(content, width: width, height: height, scale: scale, textEngine: textEngine, base: base)
            } else {
                var drawn = state.stripped
                drawn.opacity = state.opacity
                source = render([operation.replacingState(drawn)])
            }
            for mask in state.masks {
                let alpha = compositeBuffer(mask.content, width: width, height: height, scale: scale, textEngine: textEngine, base: base)
                applyMask(alpha, to: &source, opacity: Float(mask.opacity), isInverse: mask.isInverse)
            }
            for filter in state.filters {
                apply(filter, to: &source, scale: scale)
            }
            blend(source, onto: &result, mode: state.blendMode, opacity: isLayer ? Float(state.opacity) : 1)
        }
        flushPlain()
        return result
    }

    // MARK: Masks and filters

    private static func applyMask(_ mask: PixelBuffer, to buffer: inout PixelBuffer, opacity: Float, isInverse: Bool) {
        for pixel in 0..<(buffer.width * buffer.height) {
            var coverage = mask.pixels[pixel * 4 + 3] * opacity
            if isInverse { coverage = 1 - coverage }
            for channel in 0..<4 {
                buffer.pixels[pixel * 4 + channel] *= coverage
            }
        }
    }

    private static func apply(_ filter: DrawingFilter, to buffer: inout PixelBuffer, scale: CGFloat) {
        switch filter {
        case let .colorMatrix(matrix):
            transformColors(&buffer) { matrix.apply($0) }
        case let .alphaThreshold(minimum, maximum, color):
            transformColors(&buffer) { pixel in
                let alpha = Double(pixel.opacity)
                return alpha >= minimum && alpha <= maximum ? color : ResolvedColor(red: 0, green: 0, blue: 0, opacity: 0)
            }
        case let .blur(radius, isOpaque):
            blur(&buffer, sigma: Float(radius * scale) / 2, clampsEdges: isOpaque)
        case let .shadow(color, radius, offset, blendMode, placement, invertsAlpha):
            var shadow = PixelBuffer(width: buffer.width, height: buffer.height)
            let dx = Int((offset.width * scale).rounded()), dy = Int((offset.height * scale).rounded())
            for row in 0..<buffer.height {
                for column in 0..<buffer.width {
                    let sourceRow = row - dy, sourceColumn = column - dx
                    var alpha: Float = 0
                    if sourceRow >= 0, sourceRow < buffer.height, sourceColumn >= 0, sourceColumn < buffer.width {
                        alpha = buffer.pixels[(sourceRow * buffer.width + sourceColumn) * 4 + 3]
                    }
                    if invertsAlpha { alpha = 1 - alpha }
                    let coverage = alpha * color.opacity
                    let target = (row * buffer.width + column) * 4
                    shadow.pixels[target] = color.red * coverage
                    shadow.pixels[target + 1] = color.green * coverage
                    shadow.pixels[target + 2] = color.blue * coverage
                    shadow.pixels[target + 3] = coverage
                }
            }
            blur(&shadow, sigma: Float(radius * scale) / 2, clampsEdges: false)
            switch placement {
            case .only:
                buffer = shadow
            case .below:
                var result = shadow
                blend(buffer, onto: &result, mode: .normal, opacity: 1)
                // The shadow's own blend mode applies to the content below.
                if blendMode != .normal {
                    var content = PixelBuffer(width: buffer.width, height: buffer.height)
                    blend(shadow, onto: &content, mode: blendMode, opacity: 1)
                    blend(buffer, onto: &content, mode: .normal, opacity: 1)
                    result = content
                }
                buffer = result
            case .above:
                blend(shadow, onto: &buffer, mode: blendMode, opacity: 1)
            }
        }
    }

    /// Transforms each pixel's straight color.
    private static func transformColors(_ buffer: inout PixelBuffer, _ transform: (ResolvedColor) -> ResolvedColor) {
        for pixel in 0..<(buffer.width * buffer.height) {
            let index = pixel * 4
            let alpha = buffer.pixels[index + 3]
            let straight = alpha > 0
                ? ResolvedColor(red: buffer.pixels[index] / alpha, green: buffer.pixels[index + 1] / alpha, blue: buffer.pixels[index + 2] / alpha, opacity: alpha)
                : ResolvedColor(red: 0, green: 0, blue: 0, opacity: 0)
            let color = transform(straight)
            buffer.pixels[index] = color.red * color.opacity
            buffer.pixels[index + 1] = color.green * color.opacity
            buffer.pixels[index + 2] = color.blue * color.opacity
            buffer.pixels[index + 3] = color.opacity
        }
    }

    /// An approximate Gaussian blur: three box blurs each way.
    static func blur(_ buffer: inout PixelBuffer, sigma: Float, clampsEdges: Bool) {
        guard sigma > 0.3 else { return }
        // Box widths for three passes approximating the Gaussian.
        let ideal = (12 * sigma * sigma / 3 + 1).squareRoot()
        let radius = max(1, Int(((ideal - 1) / 2).rounded()))
        let width = buffer.width, height = buffer.height
        var scratch = buffer.pixels
        func pass(horizontal: Bool) {
            let lines = horizontal ? height : width
            let length = horizontal ? width : height
            let span = Float(2 * radius + 1)
            for line in 0..<lines {
                func index(_ position: Int) -> Int? {
                    var position = position
                    if position < 0 || position >= length {
                        guard clampsEdges else { return nil }
                        position = min(max(position, 0), length - 1)
                    }
                    return (horizontal ? line * width + position : position * width + line) * 4
                }
                var sums: [Float] = [0, 0, 0, 0]
                for position in -radius...radius {
                    if let source = index(position) {
                        for channel in 0..<4 { sums[channel] += buffer.pixels[source + channel] }
                    }
                }
                for position in 0..<length {
                    let target = index(position)!
                    for channel in 0..<4 { scratch[target + channel] = sums[channel] / span }
                    if let leaving = index(position - radius) {
                        for channel in 0..<4 { sums[channel] -= buffer.pixels[leaving + channel] }
                    }
                    if let entering = index(position + radius + 1) {
                        for channel in 0..<4 { sums[channel] += buffer.pixels[entering + channel] }
                    }
                }
            }
            buffer.pixels = scratch
        }
        for _ in 0..<3 {
            pass(horizontal: true)
            pass(horizontal: false)
        }
    }

    // MARK: Blending

    /// Blends a source over a destination, as the W3C compositing spec
    /// describes for blend modes, on premultiplied pixels.
    static func blend(_ source: PixelBuffer, onto destination: inout PixelBuffer, mode: BlendMode, opacity: Float) {
        for pixel in 0..<(destination.width * destination.height) {
            let index = pixel * 4
            let sa = source.pixels[index + 3] * opacity
            guard sa > 0 || mode == .destinationOut || mode == .sourceAtop else { continue }
            let s = (source.pixels[index] * opacity, source.pixels[index + 1] * opacity, source.pixels[index + 2] * opacity)
            let ba = destination.pixels[index + 3]
            let b = (destination.pixels[index], destination.pixels[index + 1], destination.pixels[index + 2])
            var out: (Float, Float, Float, Float)
            switch mode {
            case .sourceAtop:
                out = (s.0 * ba + b.0 * (1 - sa), s.1 * ba + b.1 * (1 - sa), s.2 * ba + b.2 * (1 - sa), ba)
            case .destinationOver:
                out = (b.0 + s.0 * (1 - ba), b.1 + s.1 * (1 - ba), b.2 + s.2 * (1 - ba), ba + sa * (1 - ba))
            case .destinationOut:
                out = (b.0 * (1 - sa), b.1 * (1 - sa), b.2 * (1 - sa), ba * (1 - sa))
            case .plusLighter:
                out = (min(1, s.0 + b.0), min(1, s.1 + b.1), min(1, s.2 + b.2), min(1, sa + ba))
            case .plusDarker:
                let alpha = min(1, sa + ba)
                out = (max(0, alpha - ((ba - b.0) + (sa - s.0))), max(0, alpha - ((ba - b.1) + (sa - s.1))), max(0, alpha - ((ba - b.2) + (sa - s.2))), alpha)
            default:
                // Straight colors for the blend function.
                let cs = sa > 0 ? (s.0 / sa, s.1 / sa, s.2 / sa) : (0, 0, 0)
                let cb = ba > 0 ? (b.0 / ba, b.1 / ba, b.2 / ba) : (0, 0, 0)
                let mixed = blendColor(cb, cs, mode: mode)
                func channel(_ s: Float, _ b: Float, _ m: Float) -> Float {
                    s * (1 - ba) + b * (1 - sa) + sa * ba * m
                }
                out = (channel(s.0, b.0, mixed.0), channel(s.1, b.1, mixed.1), channel(s.2, b.2, mixed.2), sa + ba * (1 - sa))
            }
            destination.pixels[index] = out.0
            destination.pixels[index + 1] = out.1
            destination.pixels[index + 2] = out.2
            destination.pixels[index + 3] = out.3
        }
    }

    typealias RGB = (Float, Float, Float)

    /// A blend mode's function of the backdrop and source colors.
    static func blendColor(_ cb: RGB, _ cs: RGB, mode: BlendMode) -> RGB {
        func each(_ f: (Float, Float) -> Float) -> RGB {
            (f(cb.0, cs.0), f(cb.1, cs.1), f(cb.2, cs.2))
        }
        func hardLight(_ b: Float, _ s: Float) -> Float {
            s <= 0.5 ? b * 2 * s : b + (2 * s - 1) - b * (2 * s - 1)
        }
        switch mode {
        case .multiply: return each { $0 * $1 }
        case .screen: return each { $0 + $1 - $0 * $1 }
        case .overlay: return each { hardLight($1, $0) }
        case .darken: return each { min($0, $1) }
        case .lighten: return each { max($0, $1) }
        case .colorDodge: return each { b, s in b == 0 ? 0 : s >= 1 ? 1 : min(1, b / (1 - s)) }
        case .colorBurn: return each { b, s in b >= 1 ? 1 : s <= 0 ? 0 : 1 - min(1, (1 - b) / s) }
        case .hardLight: return each(hardLight)
        case .softLight:
            return each { b, s in
                if s <= 0.5 { return b - (1 - 2 * s) * b * (1 - b) }
                let d = b <= 0.25 ? ((16 * b - 12) * b + 4) * b : b.squareRoot()
                return b + (2 * s - 1) * (d - b)
            }
        case .difference: return each { abs($0 - $1) }
        case .exclusion: return each { $0 + $1 - 2 * $0 * $1 }
        case .hue: return setLuminosity(setSaturation(cs, saturation(cb)), luminosity(cb))
        case .saturation: return setLuminosity(setSaturation(cb, saturation(cs)), luminosity(cb))
        case .color: return setLuminosity(cs, luminosity(cb))
        case .luminosity: return setLuminosity(cb, luminosity(cs))
        default: return cs
        }
    }

    private static func luminosity(_ c: RGB) -> Float {
        0.3 * c.0 + 0.59 * c.1 + 0.11 * c.2
    }

    private static func clipColor(_ c: RGB) -> RGB {
        let l = luminosity(c)
        let n = min(c.0, c.1, c.2), x = max(c.0, c.1, c.2)
        var c = c
        if n < 0 {
            c = (l + (c.0 - l) * l / (l - n), l + (c.1 - l) * l / (l - n), l + (c.2 - l) * l / (l - n))
        }
        if x > 1 {
            c = (l + (c.0 - l) * (1 - l) / (x - l), l + (c.1 - l) * (1 - l) / (x - l), l + (c.2 - l) * (1 - l) / (x - l))
        }
        return c
    }

    private static func setLuminosity(_ c: RGB, _ l: Float) -> RGB {
        let d = l - luminosity(c)
        return clipColor((c.0 + d, c.1 + d, c.2 + d))
    }

    private static func saturation(_ c: RGB) -> Float {
        max(c.0, c.1, c.2) - min(c.0, c.1, c.2)
    }

    private static func setSaturation(_ c: RGB, _ s: Float) -> RGB {
        let maximum = max(c.0, c.1, c.2), minimum = min(c.0, c.1, c.2)
        guard maximum > minimum else { return (0, 0, 0) }
        func scale(_ value: Float) -> Float { (value - minimum) * s / (maximum - minimum) }
        return (scale(c.0), scale(c.1), scale(c.2))
    }
}
