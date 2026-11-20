//
//  ImageContent.swift
//  CacaoRender
//
//  Created by Alsey Coleman Miller on 11/13/26.
//

import Foundation
#if canImport(CoreGraphics)
import CoreGraphics
#endif

/// The encoded data of an image, or its pixels, and its size.
///
/// Sources are shared by identity: a renderer decodes a source once and
/// keeps the result for as long as the source is used.
public final class ImageSource: Hashable, @unchecked Sendable {

    /// Decoded pixels: 8-bit RGBA, premultiplied, rows top to bottom.
    public struct Pixels: Sendable {
        public var data: Data
        public var bytesPerRow: Int

        public init(data: Data, bytesPerRow: Int) {
            self.data = data
            self.bytesPerRow = bytesPerRow
        }
    }

    /// The encoded PNG data; empty for an image made from pixels.
    public let data: Data

    /// The pixels of an image made from them, which needs no decoding.
    public let pixels: Pixels?

    /// The image's size in pixels, read from its header.
    public let pixelSize: CGSize

    /// The pixels per point the image was made for.
    public let scale: CGFloat

    public init(data: Data, scale: CGFloat) {
        self.data = data
        self.pixels = nil
        self.scale = scale
        self.pixelSize = Self.pngSize(data) ?? .zero
    }

    public init(pixels: Pixels, width: Int, height: Int, scale: CGFloat) {
        self.data = Data()
        self.pixels = pixels
        self.scale = scale
        self.pixelSize = CGSize(width: CGFloat(width), height: CGFloat(height))
    }

    /// The image's size in points.
    public var size: CGSize {
        CGSize(width: pixelSize.width / scale, height: pixelSize.height / scale)
    }

    public static func == (lhs: ImageSource, rhs: ImageSource) -> Bool {
        lhs === rhs
    }

    public func hash(into hasher: inout Hasher) {
        hasher.combine(ObjectIdentifier(self))
    }

    /// The width and height from a PNG's IHDR chunk.
    private static func pngSize(_ data: Data) -> CGSize? {
        let signature: [UInt8] = [0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A]
        guard data.count >= 24, Array(data.prefix(8)) == signature else {
            return nil
        }
        func uint32(at offset: Int) -> UInt32 {
            let bytes = data.dropFirst(offset).prefix(4)
            return bytes.reduce(0) { $0 << 8 | UInt32($1) }
        }
        return CGSize(width: CGFloat(uint32(at: 16)), height: CGFloat(uint32(at: 20)))
    }

    // MARK: Named images

    nonisolated(unsafe) private static var cache: [String: ImageSource] = [:]

    private static let lock = NSLock()

    /// Loads a named PNG from a bundle, preferring the variant for `scale`.
    public static func named(_ name: String, bundlePath: String?, scale: CGFloat) -> ImageSource? {
        let key = "\(bundlePath ?? "main")/\(name)@\(scale)"
        lock.lock()
        defer { lock.unlock() }
        if let source = cache[key] {
            return source
        }
        let bundle = bundlePath.flatMap(Bundle.init(path:)) ?? .main
        let preferred = max(1, min(3, Int(scale.rounded(.up))))
        let candidates = (1...3).sorted { abs($0 - preferred) < abs($1 - preferred) || (abs($0 - preferred) == abs($1 - preferred) && $0 > $1) }
        for variant in candidates {
            let resource = variant == 1 ? name : "\(name)@\(variant)x"
            if let url = bundle.url(forResource: resource, withExtension: "png")
                ?? bundle.url(forResource: resource, withExtension: nil),
               let data = try? Data(contentsOf: url) {
                let source = ImageSource(data: data, scale: CGFloat(variant))
                cache[key] = source
                return source
            }
        }
        return nil
    }
}

/// An image's pixels and how to draw them in its frame.
public struct ImageContent: Equatable, Sendable {

    public var source: ImageSource

    /// A color that replaces the image's color, keeping its alpha.
    public var tint: ResolvedColor?

    public var interpolation: ImageInterpolation

    /// A transformation of the image's colors, after the tint.
    public var colorMatrix: ColorMatrix? = nil

    public init(
        source: ImageSource,
        tint: ResolvedColor? = nil,
        interpolation: ImageInterpolation = .low,
        colorMatrix: ColorMatrix? = nil
    ) {
        self.source = source
        self.tint = tint
        self.interpolation = interpolation
        self.colorMatrix = colorMatrix
    }
}

/// The level of quality for rendering an image that requires
/// interpolation, such as a scaled image.
public enum ImageInterpolation: Hashable, Sendable {
    case none
    case low
    case medium
    case high
}
