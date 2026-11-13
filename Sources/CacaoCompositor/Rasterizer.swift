//
//  Rasterizer.swift
//  CacaoCompositor
//
//  Created by Alsey Coleman Miller on 11/13/26.
//

import Foundation
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

    /// Draws into a new bitmap of `size` pixels and returns the image.
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
}
