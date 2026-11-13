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
import Cacao
import Silica
#if canImport(SilicaCoreGraphics)
import SilicaCoreGraphics
#elseif canImport(SilicaCairo)
import SilicaCairo
#endif

/// Draws a layer's content into a bitmap with the platform's Silica backend:
/// CoreGraphics on macOS, Cairo on Linux.
///
/// The compositor calls this only when a layer's content changes; the
/// resulting pixels are uploaded to a GPU texture and reused every frame.
package enum Rasterizer {

    /// The name of the Silica backend in use.
    package static var backendName: String {
        #if canImport(SilicaCoreGraphics)
        return "CoreGraphics"
        #elseif canImport(SilicaCairo)
        return "Cairo"
        #else
        return "None"
        #endif
    }

    /// Draws into a new bitmap of `size` pixels and returns the image, whose
    /// pixels are premultiplied RGBA, rows top to bottom.
    package static func draw(
        size: CGSize,
        _ body: (Silica.CGContext) throws -> Void
    ) throws -> Silica.CGImage? {
        #if canImport(SilicaCoreGraphics)
        let context = try CoreGraphicsContext(bitmap: size)
        #elseif canImport(SilicaCairo)
        let context = try CairoContext(bitmap: size)
        #else
        #error("No Silica backend for this platform")
        #endif
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
    /// into a bitmap enlarged by the content's outset on every side.
    @MainActor
    package static func rasterize(
        _ content: DisplayList.Content,
        size: CGSize,
        scale: CGFloat,
        textEngine: SilicaTextEngine
    ) -> Silica.CGImage? {
        let outset = outset(of: content)
        let pixels = CGSize(
            width: max(1, ((size.width + 2 * outset) * scale).rounded(.up)),
            height: max(1, ((size.height + 2 * outset) * scale).rounded(.up))
        )
        return try? draw(size: pixels) { context in
            context.scaleBy(x: scale, y: scale)
            context.translateBy(x: outset, y: outset)
            switch content {
            case let .text(text):
                textEngine.draw(text, size: size, in: context)
            case let .shape(shape):
                draw(shape, in: context)
            case .color, .image:
                break
            }
        }
    }

    private static func draw(_ shape: ShapeContent, in context: Silica.CGContext) {
        context.beginPath()
        shape.path.forEach { element in
            switch element {
            case let .move(to):
                context.move(to: to)
            case let .line(to):
                context.addLine(to: to)
            case let .quadCurve(to, control):
                context.addQuadCurve(to: to, control: control)
            case let .curve(to, control1, control2):
                context.addCurve(to: to, control1: control1, control2: control2)
            case .closeSubpath:
                context.closePath()
            }
        }
        let color = shape.color
        switch shape.drawing {
        case let .fill(style):
            context.setFillColor(
                red: CGFloat(color.red), green: CGFloat(color.green),
                blue: CGFloat(color.blue), alpha: CGFloat(color.opacity)
            )
            context.fillPath(using: style.isEOFilled ? .evenOdd : .winding)
        case let .stroke(style):
            context.setStrokeColor(
                red: CGFloat(color.red), green: CGFloat(color.green),
                blue: CGFloat(color.blue), alpha: CGFloat(color.opacity)
            )
            context.lineWidth = style.lineWidth
            context.lineCap = Silica.CGLineCap(style.lineCap)
            context.lineJoin = Silica.CGLineJoin(style.lineJoin)
            context.miterLimit = style.miterLimit
            context.lineDash = (style.dashPhase, style.dash)
            context.strokePath()
        }
    }

    /// Encodes premultiplied RGBA pixels, rows top to bottom, as PNG.
    package static func encodePNG(width: Int, height: Int, bytesPerRow: Int, pixels: Data) -> Data? {
        let image = Silica.CGImage(width: width, height: height, bytesPerRow: bytesPerRow, data: pixels)
        #if canImport(SilicaCoreGraphics)
        return CoreGraphicsBackend.encodePNG(image)
        #elseif canImport(SilicaCairo)
        return CairoBackend.encodePNG(image)
        #else
        return nil
        #endif
    }

    /// Decodes an image's PNG data, replacing its color with `tint` if set.
    package static func decode(_ content: ImageContent) -> Silica.CGImage? {
        guard let image = CGImageSourcePNG(data: content.source.data)?.createImage(at: 0) else {
            return nil
        }
        guard let tint = content.tint else {
            return image
        }
        // Keep each pixel's alpha, with the tint's premultiplied color.
        var data = image.data
        data.withUnsafeMutableBytes { bytes in
            let pixels = bytes.bindMemory(to: UInt8.self)
            for row in 0..<image.height {
                for column in 0..<image.width {
                    let offset = row * image.bytesPerRow + column * 4
                    let alpha = Float(pixels[offset + 3]) / 255 * tint.opacity
                    pixels[offset] = UInt8(max(0, min(255, (tint.red * alpha * 255).rounded())))
                    pixels[offset + 1] = UInt8(max(0, min(255, (tint.green * alpha * 255).rounded())))
                    pixels[offset + 2] = UInt8(max(0, min(255, (tint.blue * alpha * 255).rounded())))
                    pixels[offset + 3] = UInt8(max(0, min(255, (alpha * 255).rounded())))
                }
            }
        }
        return Silica.CGImage(width: image.width, height: image.height, bytesPerRow: image.bytesPerRow, data: data)
    }
}

#if canImport(CoreGraphics)
private typealias StrokeLineCap = CoreGraphics.CGLineCap
private typealias StrokeLineJoin = CoreGraphics.CGLineJoin
#else
private typealias StrokeLineCap = Cacao.CGLineCap
private typealias StrokeLineJoin = Cacao.CGLineJoin
#endif

private extension Silica.CGLineCap {

    init(_ cap: StrokeLineCap) {
        switch cap {
        case .round: self = .round
        case .square: self = .square
        default: self = .butt
        }
    }
}

private extension Silica.CGLineJoin {

    init(_ join: StrokeLineJoin) {
        switch join {
        case .round: self = .round
        case .bevel: self = .bevel
        default: self = .miter
        }
    }
}
