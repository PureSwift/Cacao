//
//  Backdrop.swift
//  CacaoCompositor
//
//  Created by Alsey Coleman Miller on 11/20/26.
//

import Foundation
#if canImport(CoreGraphics)
import CoreGraphics
#endif
import CacaoRender

/// Blurs pixels read back from the frame, for a backdrop.
///
/// The pixels are shrunk first, so the blur is cheap, blurred by three box
/// passes in each direction (which make a Gaussian), given a saturation
/// and rounded corners, and come out premultiplied at the shrunk size: the
/// GPU scales them back up smoothly.
package enum BackdropBlur {

    /// How much pixels shrink for a blur of a radius, in pixels: more for
    /// a wider blur, which hides it.
    package static func shrink(sigma: CGFloat) -> Int {
        Int(min(max((sigma / 6).rounded(), 1), 8))
    }

    /// How far past its edges a blur reads, in pixels.
    package static func reach(sigma: CGFloat) -> Int {
        Int(sigma * 1.5)
    }

    /// Blurs RGBA pixels, rows top first.
    ///
    /// - Parameters:
    ///   - origin: Where the pixels' first is, in the frame's pixels.
    ///   - rounding: The rectangle whose corners are rounded, in the
    ///     frame's pixels, with the radius and which corners.
    /// - Returns: Premultiplied RGBA pixels, `1 / shrink` the size.
    package static func blur(
        pixels: Data,
        width: Int,
        height: Int,
        bytesPerRow: Int,
        origin: (x: Int, y: Int),
        sigma: CGFloat,
        saturation: Double,
        rounding: (frame: CGRect, radius: CGFloat, corners: BackdropContent.Corners)?
    ) -> (pixels: Data, width: Int, height: Int, shrink: Int) {
        let shrink = shrink(sigma: sigma)
        let small = (width: (width + shrink - 1) / shrink, height: (height + shrink - 1) / shrink)
        var channels = [UInt8](repeating: 255, count: small.width * small.height * 4)
        // Shrunk: the average of each block.
        pixels.withUnsafeBytes { (source: UnsafeRawBufferPointer) in
            for row in 0..<small.height {
                for column in 0..<small.width {
                    var sums = (0, 0, 0), count = 0
                    for y in (row * shrink)..<min((row + 1) * shrink, height) {
                        for x in (column * shrink)..<min((column + 1) * shrink, width) {
                            let at = y * bytesPerRow + x * 4
                            sums.0 += Int(source[at])
                            sums.1 += Int(source[at + 1])
                            sums.2 += Int(source[at + 2])
                            count += 1
                        }
                    }
                    let at = (row * small.width + column) * 4
                    channels[at] = UInt8(sums.0 / max(count, 1))
                    channels[at + 1] = UInt8(sums.1 / max(count, 1))
                    channels[at + 2] = UInt8(sums.2 / max(count, 1))
                }
            }
        }
        // Three box passes in each direction: a Gaussian of this sigma.
        let box = max(Int((sigma / CGFloat(shrink) - 0.5).rounded()), 1)
        for _ in 0..<3 {
            boxBlur(&channels, width: small.width, height: small.height, radius: box, horizontal: true)
            boxBlur(&channels, width: small.width, height: small.height, radius: box, horizontal: false)
        }
        // Saturated, in the rounded corners, and premultiplied.
        var output = Data(count: small.width * small.height * 4)
        output.withUnsafeMutableBytes { (out: UnsafeMutableRawBufferPointer) in
            for row in 0..<small.height {
                let y = CGFloat(origin.y) + (CGFloat(row) + 0.5) * CGFloat(shrink)
                for column in 0..<small.width {
                    let x = CGFloat(origin.x) + (CGFloat(column) + 0.5) * CGFloat(shrink)
                    let at = (row * small.width + column) * 4
                    var (r, g, b) = (Float(channels[at]), Float(channels[at + 1]), Float(channels[at + 2]))
                    if saturation != 1 {
                        let gray = 0.2126 * r + 0.7152 * g + 0.0722 * b
                        let amount = Float(saturation)
                        r = min(max(gray + (r - gray) * amount, 0), 255)
                        g = min(max(gray + (g - gray) * amount, 0), 255)
                        b = min(max(gray + (b - gray) * amount, 0), 255)
                    }
                    var cover: CGFloat = 1
                    if let rounding, rounding.radius > 0 {
                        cover = cornerCover(
                            x: x, y: y, in: rounding.frame, radius: rounding.radius,
                            corners: rounding.corners, soft: CGFloat(shrink)
                        )
                    }
                    let a = Float(cover)
                    out[at] = UInt8(r * a)
                    out[at + 1] = UInt8(g * a)
                    out[at + 2] = UInt8(b * a)
                    out[at + 3] = UInt8(255 * a)
                }
            }
        }
        return (output, small.width, small.height, shrink)
    }

    /// How much of a point is inside the rounded corners of a rectangle:
    /// 1 away from them.
    package static func cornerCover(
        x: CGFloat, y: CGFloat, in rect: CGRect, radius: CGFloat, corners: BackdropContent.Corners, soft: CGFloat
    ) -> CGFloat {
        let left = x < rect.minX + radius, right = x > rect.maxX - radius
        let above = y < rect.minY + radius, below = y > rect.maxY - radius
        var center: CGPoint?
        if left, above, corners.contains(.topLeading) { center = CGPoint(x: rect.minX + radius, y: rect.minY + radius) }
        if right, above, corners.contains(.topTrailing) { center = CGPoint(x: rect.maxX - radius, y: rect.minY + radius) }
        if left, below, corners.contains(.bottomLeading) { center = CGPoint(x: rect.minX + radius, y: rect.maxY - radius) }
        if right, below, corners.contains(.bottomTrailing) { center = CGPoint(x: rect.maxX - radius, y: rect.maxY - radius) }
        guard let center else { return 1 }
        let distance = ((x - center.x) * (x - center.x) + (y - center.y) * (y - center.y)).squareRoot() - radius
        return min(max(0.5 - distance / soft, 0), 1)
    }

    /// One box blur of the pixels' three color channels along a direction,
    /// the edges repeating.
    private static func boxBlur(_ pixels: inout [UInt8], width: Int, height: Int, radius: Int, horizontal: Bool) {
        let (length, lines) = horizontal ? (width, height) : (height, width)
        let (step, lineStep) = horizontal ? (4, width * 4) : (width * 4, 4)
        let span = radius * 2 + 1
        var source = pixels
        pixels.withUnsafeMutableBufferPointer { out in
            source.withUnsafeMutableBufferPointer { input in
                for line in 0..<lines {
                    let base = line * lineStep
                    for channel in 0..<3 {
                        func value(_ index: Int) -> Int {
                            Int(input[base + min(max(index, 0), length - 1) * step + channel])
                        }
                        var sum = 0
                        for index in -radius...radius { sum += value(index) }
                        for index in 0..<length {
                            out[base + index * step + channel] = UInt8(sum / span)
                            sum += value(index + radius + 1) - value(index - radius)
                        }
                    }
                }
            }
        }
    }
}
