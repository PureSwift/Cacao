//
//  Rasterizer.swift
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

/// Draws a layer's content into a bitmap with the platform's Silica backend:
/// Quartz on macOS, Cairo on Linux.
///
/// The compositor calls this only when a layer's content changes; the
/// resulting pixels are uploaded to a GPU texture and reused every frame.
package enum Rasterizer {

    /// The name of the Silica backend in use.
    package static var backendName: String {
        SilicaPlatform.backendName
    }

    /// The platform's backend, registered once as Silica's default.
    private static let backend: Void = SilicaPlatform.register()

    /// Draws into a new bitmap of `size` pixels and returns the image, whose
    /// pixels are premultiplied RGBA, rows top to bottom.
    package static func draw(
        size: CGSize,
        _ body: (SilicaContext) throws -> Void
    ) throws -> SilicaImage? {
        _ = backend
        guard let context = BitmapContext(width: Double(size.width), height: Double(size.height)) else {
            return nil
        }
        try body(context)
        return context.makeImage()
    }

    /// How far content draws outside its frame: half of a stroke's width,
    /// and more for mitered corners.
    package static func outset(of content: DisplayList.Content) -> CGFloat {
        guard case let .shape(shape) = content, case let .stroke(style) = shape.drawing else {
            return 0
        }
        let miter: CGFloat = style.lineJoin == .miter ? 2 : 1
        return (style.lineWidth / 2 * miter + 1).rounded(.up)
    }

    /// Draws text or a shape of `size` points at `scale` pixels a point,
    /// into a bitmap enlarged by the content's outset on every side, or only
    /// a region (in pixels) of that bitmap, for tiles.
    @MainActor
    package static func rasterize(
        _ content: DisplayList.Content,
        size: CGSize,
        scale: CGFloat,
        region: CGRect? = nil,
        textEngine: SilicaTextEngine
    ) -> SilicaImage? {
        let outset = outset(of: content)
        let full = CGSize(
            width: max(1, ((size.width + 2 * outset) * scale).rounded(.up)),
            height: max(1, ((size.height + 2 * outset) * scale).rounded(.up))
        )
        let pixels = region?.size ?? full
        if case let .drawing(drawing) = content {
            let flattened = drawing.flattened()
            if flattened.needsCompositing {
                // Blend modes, filters, layers and masks composite in software.
                return composite(flattened, pixels: pixels, scale: scale, textEngine: textEngine) { context in
                    if let region {
                        context.translateBy(x: -region.minX, y: -region.minY)
                    }
                    context.scaleBy(x: scale, y: scale)
                    context.translateBy(x: outset, y: outset)
                }
            }
        }
        if case let .shape(shape) = content, let gradient = shape.gradient {
            // The shape drawn in white is the mask for the gradient's colors.
            var mask = shape
            mask.gradient = nil
            mask.color = ResolvedColor(red: 1, green: 1, blue: 1, opacity: 1)
            guard let coverage = rasterize(.shape(mask), size: size, scale: scale, region: region, textEngine: textEngine) else {
                return nil
            }
            let origin = CGPoint(x: region?.minX ?? 0, y: region?.minY ?? 0)
            return paint(gradient, through: coverage) { column, row in
                CGPoint(
                    x: (CGFloat(column) + 0.5 + origin.x) / scale - outset,
                    y: (CGFloat(row) + 0.5 + origin.y) / scale - outset
                )
            }
        }
        return try? draw(size: pixels) { context in
            if let region {
                context.translateBy(x: -region.minX, y: -region.minY)
            }
            context.scaleBy(x: scale, y: scale)
            context.translateBy(x: outset, y: outset)
            switch content {
            case let .text(text):
                textEngine.draw(text, size: size, in: context)
            case let .shape(shape):
                draw(shape, in: context)
            case let .drawing(drawing):
                draw(drawing.flattened(), in: context, scale: scale, textEngine: textEngine)
            case .color, .roundedRectangle, .image, .external, .backdrop:
                break
            }
        }
    }

    /// Draws an image with its first row at the top of a rectangle, as
    /// Silica draws images.
    private static func drawUpright(_ image: SilicaImage, in rect: CGRect, context: SilicaContext) {
        context.draw(image, in: Silica.Rect(rect))
    }

    /// The gradient's colors at each pixel, at the coverage's alpha.
    /// `point` gives the point in the gradient's space of a pixel's center.
    package static func paint(
        _ gradient: GradientPaint,
        through coverage: SilicaImage,
        point: (Int, Int) -> CGPoint
    ) -> SilicaImage {
        var data = coverage.data
        let width = coverage.width, height = coverage.height, bytesPerRow = coverage.bytesPerRow
        data.withUnsafeMutableBytes { (bytes: UnsafeMutableRawBufferPointer) in
            let pixels = bytes.bindMemory(to: UInt8.self)
            for row in 0..<height {
                for column in 0..<width {
                    let offset = row * bytesPerRow + column * 4
                    let covered = pixels[offset + 3]
                    guard covered > 0 else { continue }
                    let color = gradient.color(at: point(column, row))
                    let alpha = Float(covered) / 255 * color.opacity
                    pixels[offset] = UInt8(max(0, min(255, (color.red * alpha * 255).rounded())))
                    pixels[offset + 1] = UInt8(max(0, min(255, (color.green * alpha * 255).rounded())))
                    pixels[offset + 2] = UInt8(max(0, min(255, (color.blue * alpha * 255).rounded())))
                    pixels[offset + 3] = UInt8(max(0, min(255, (alpha * 255).rounded())))
                }
            }
        }
        return SilicaImage(width: width, height: height, bytesPerRow: bytesPerRow, data: data)
    }

    /// A gradient drawn over a rectangle, in pixels of `scale` a point.
    private static func gradientImage(_ gradient: GradientPaint, in rect: CGRect, scale: CGFloat) -> SilicaImage? {
        let width = Int(min(4096, max(1, (rect.width * scale).rounded(.up))))
        let height = Int(min(4096, max(1, (rect.height * scale).rounded(.up))))
        let opaque = Data(repeating: 255, count: width * height * 4)
        let coverage = SilicaImage(width: width, height: height, bytesPerRow: width * 4, data: opaque)
        return paint(gradient, through: coverage) { column, row in
            CGPoint(
                x: rect.minX + (CGFloat(column) + 0.5) * rect.width / CGFloat(width),
                y: rect.minY + (CGFloat(row) + 0.5) * rect.height / CGFloat(height)
            )
        }
    }

    /// Draws a canvas's commands, each with its transform, opacity and clips.
    @MainActor
    static func draw(_ drawing: DrawingContent, in context: SilicaContext, scale: CGFloat, textEngine: SilicaTextEngine) {
        for operation in drawing.operations {
            let state = operation.state
            guard state.opacity > 0 else { continue }
            context.saveGState()
            defer { context.restoreGState() }
            for clip in state.clips {
                context.saveGState()
                context.concatenate(Silica.AffineTransform(clip.transform))
                addPath(clip.path, to: context)
                if clip.isInverse {
                    // Outside the path: the path within a very large rectangle.
                    context.addRect(Silica.Rect(x: -1e5, y: -1e5, width: 2e5, height: 2e5))
                }
                context.restoreGState()
                context.clip(using: clip.isEOFilled || clip.isInverse ? .evenOdd : .winding)
            }
            context.concatenate(Silica.AffineTransform(state.transform))
            // Opacity goes into colors: not every backend applies a
            // context's alpha to fills.
            let opacity = Float(state.opacity)
            switch operation {
            case var .shape(shape, _):
                if let gradient = shape.gradient, case let .fill(style) = shape.drawing {
                    // Gradient fills draw an image of the gradient through
                    // the path as a clip.
                    let bounds = shape.path.boundingRect
                    if !bounds.isEmpty, !bounds.isNull,
                       let image = gradientImage(gradient.multiplyingOpacity(opacity), in: bounds, scale: scale * max(abs(state.transform.a), abs(state.transform.d), 1)) {
                        addPath(shape.path, to: context)
                        context.clip(using: style.isEOFilled ? .evenOdd : .winding)
                        drawUpright(image, in: bounds, context: context)
                    }
                    continue
                }
                if let gradient = shape.gradient, case let .stroke(style) = shape.drawing {
                    // Gradient strokes: the stroke drawn in white over its
                    // bounds, painted with the gradient, drawn there.
                    let outset = style.lineWidth / 2 * (style.lineJoin == .miter ? 2 : 1) + 1
                    let bounds = shape.path.boundingRect.insetBy(dx: -outset, dy: -outset)
                    let pixelScale = scale * max(abs(state.transform.a), abs(state.transform.d), 1)
                    var mask = shape
                    mask.gradient = nil
                    mask.color = ResolvedColor(red: 1, green: 1, blue: 1)
                    let size = CGSize(
                        width: min(4096, max(1, (bounds.width * pixelScale).rounded(.up))),
                        height: min(4096, max(1, (bounds.height * pixelScale).rounded(.up)))
                    )
                    if !bounds.isNull, let coverage = try? Rasterizer.draw(size: size, { maskContext in
                        maskContext.scaleBy(x: size.width / bounds.width, y: size.height / bounds.height)
                        maskContext.translateBy(x: -bounds.minX, y: -bounds.minY)
                        draw(mask, in: maskContext)
                    }) {
                        let painted = paint(gradient.multiplyingOpacity(opacity), through: coverage) { column, row in
                            CGPoint(
                                x: bounds.minX + (CGFloat(column) + 0.5) * bounds.width / size.width,
                                y: bounds.minY + (CGFloat(row) + 0.5) * bounds.height / size.height
                            )
                        }
                        drawUpright(painted, in: bounds, context: context)
                    }
                    continue
                }
                shape.color.opacity *= opacity
                draw(shape, in: context)
            case .text(var text, let rect, _):
                for index in text.runs.indices {
                    text.runs[index].color.opacity *= opacity
                }
                context.translateBy(x: Double(rect.minX), y: Double(rect.minY))
                textEngine.draw(text, size: rect.size, in: context)
            case let .image(image, rect, _):
                context.setAlpha(Double(opacity))
                if let decoded = decode(image) {
                    drawUpright(decoded, in: rect, context: context)
                }
            case let .tiledImage(path, isEOFilled, image, origin, tileScale, _):
                guard let decoded = decode(image) else { continue }
                let tile = CGSize(width: image.source.size.width * tileScale, height: image.source.size.height * tileScale)
                let bounds = path.boundingRect
                guard tile.width > 0.5, tile.height > 0.5, !bounds.isNull else { continue }
                addPath(path, to: context)
                context.clip(using: isEOFilled ? .evenOdd : .winding)
                context.setAlpha(Double(opacity))
                let firstColumn = Int(((bounds.minX - origin.x) / tile.width).rounded(.down))
                let firstRow = Int(((bounds.minY - origin.y) / tile.height).rounded(.down))
                let columns = Int(((bounds.maxX - origin.x) / tile.width).rounded(.up))
                let rows = Int(((bounds.maxY - origin.y) / tile.height).rounded(.up))
                guard (columns - firstColumn) * (rows - firstRow) <= 10_000 else { continue }
                for row in firstRow..<max(rows, firstRow + 1) {
                    for column in firstColumn..<max(columns, firstColumn + 1) {
                        let rect = CGRect(x: origin.x + CGFloat(column) * tile.width, y: origin.y + CGFloat(row) * tile.height, width: tile.width, height: tile.height)
                        drawUpright(decoded, in: rect, context: context)
                    }
                }
            case .items, .layer:
                // Flattened, or composited, before drawing.
                break
            }
        }
    }

    private static func addPath(_ path: CacaoRender.Path, to context: SilicaContext) {
        context.beginPath()
        path.forEach { element in
            switch element {
            case let .move(to):
                context.move(to: Silica.Point(to))
            case let .line(to):
                context.addLine(to: Silica.Point(to))
            case let .quadCurve(to, control):
                context.addQuadCurve(to: Silica.Point(to), control: Silica.Point(control))
            case let .curve(to, control1, control2):
                context.addCurve(to: Silica.Point(to), control1: Silica.Point(control1), control2: Silica.Point(control2))
            case .closeSubpath:
                context.closePath()
            }
        }
    }

    private static func draw(_ shape: ShapeContent, in context: SilicaContext) {
        context.beginPath()
        shape.path.forEach { element in
            switch element {
            case let .move(to):
                context.move(to: Silica.Point(to))
            case let .line(to):
                context.addLine(to: Silica.Point(to))
            case let .quadCurve(to, control):
                context.addQuadCurve(to: Silica.Point(to), control: Silica.Point(control))
            case let .curve(to, control1, control2):
                context.addCurve(to: Silica.Point(to), control1: Silica.Point(control1), control2: Silica.Point(control2))
            case .closeSubpath:
                context.closePath()
            }
        }
        let color = shape.color
        switch shape.drawing {
        case let .fill(style):
            context.setFillColor(Silica.Color(color))
            context.fillPath(using: style.isEOFilled ? .evenOdd : .winding)
        case let .stroke(style):
            context.setStrokeColor(Silica.Color(color))
            context.setLineWidth(Double(style.lineWidth))
            context.setLineCap(Silica.LineCap(style.lineCap))
            context.setLineJoin(Silica.LineJoin(style.lineJoin))
            context.setMiterLimit(Double(style.miterLimit))
            context.setLineDash(phase: Double(style.dashPhase), lengths: style.dash.map { Double($0) })
            context.strokePath()
        }
    }

    /// Encodes premultiplied RGBA pixels, rows top to bottom, as PNG.
    package static func encodePNG(width: Int, height: Int, bytesPerRow: Int, pixels: Data) -> Data? {
        _ = backend
        return SilicaImage(width: width, height: height, bytesPerRow: bytesPerRow, data: pixels).pngData()
    }

    /// Decodes an image's PNG data, or takes its pixels, replacing its color
    /// with `tint` if set, then transforming its colors by its matrix if set.
    /// Decodes PNG data with the platform's backend.
    private static func decodePNG(_ data: Data) -> SilicaImage? {
        _ = backend
        return SilicaImage(png: data)
    }

    package static func decode(_ content: ImageContent) -> SilicaImage? {
        let image: SilicaImage
        if let pixels = content.source.pixels {
            image = SilicaImage(
                width: Int(content.source.pixelSize.width),
                height: Int(content.source.pixelSize.height),
                bytesPerRow: pixels.bytesPerRow,
                data: pixels.data
            )
        } else if let decoded = decodePNG(content.source.data) {
            image = decoded
        } else {
            return nil
        }
        guard content.tint != nil || content.colorMatrix != nil else {
            return image
        }
        let tint = content.tint
        let matrix = content.colorMatrix
        // Keep each pixel's alpha, with the tint's premultiplied color.
        var data = image.data
        data.withUnsafeMutableBytes { (bytes: UnsafeMutableRawBufferPointer) in
            let pixels = bytes.bindMemory(to: UInt8.self)
            for row in 0..<image.height {
                for column in 0..<image.width {
                    let offset = row * image.bytesPerRow + column * 4
                    let storedAlpha = Float(pixels[offset + 3]) / 255
                    var color: ResolvedColor
                    if let tint {
                        color = ResolvedColor(red: tint.red, green: tint.green, blue: tint.blue, opacity: storedAlpha * tint.opacity)
                    } else if storedAlpha > 0 {
                        // Straight colors from premultiplied pixels.
                        color = ResolvedColor(
                            red: Float(pixels[offset]) / 255 / storedAlpha,
                            green: Float(pixels[offset + 1]) / 255 / storedAlpha,
                            blue: Float(pixels[offset + 2]) / 255 / storedAlpha,
                            opacity: storedAlpha
                        )
                    } else {
                        color = ResolvedColor(red: 0, green: 0, blue: 0, opacity: 0)
                    }
                    if let matrix {
                        color = matrix.apply(color)
                    }
                    let alpha = color.opacity
                    pixels[offset] = UInt8(max(0, min(255, (color.red * alpha * 255).rounded())))
                    pixels[offset + 1] = UInt8(max(0, min(255, (color.green * alpha * 255).rounded())))
                    pixels[offset + 2] = UInt8(max(0, min(255, (color.blue * alpha * 255).rounded())))
                    pixels[offset + 3] = UInt8(max(0, min(255, (alpha * 255).rounded())))
                }
            }
        }
        return SilicaImage(width: image.width, height: image.height, bytesPerRow: image.bytesPerRow, data: data)
    }
}

#if canImport(CoreGraphics)
private typealias StrokeLineCap = CoreGraphics.CGLineCap
private typealias StrokeLineJoin = CoreGraphics.CGLineJoin
#else
private typealias StrokeLineCap = CacaoRender.CGLineCap
private typealias StrokeLineJoin = CacaoRender.CGLineJoin
#endif

private extension Silica.LineCap {

    init(_ cap: StrokeLineCap) {
        switch cap {
        case .round: self = .round
        case .square: self = .square
        default: self = .butt
        }
    }
}

private extension Silica.LineJoin {

    init(_ join: StrokeLineJoin) {
        switch join {
        case .round: self = .round
        case .bevel: self = .bevel
        default: self = .miter
        }
    }
}
