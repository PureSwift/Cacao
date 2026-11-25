//
//  SilicaInterop.swift
//  CacaoCompositor
//
//  Silica's drawing API as Cacao uses it: its context and image by names
//  apart from Cacao's own, the platform's backend, and Cacao's geometry in
//  Silica's.
//

import Foundation
#if canImport(CoreGraphics)
import CoreGraphics
#endif
import CacaoRender
import Silica
#if canImport(SilicaQuartz)
import SilicaQuartz
#elseif canImport(SilicaCairo)
import SilicaCairo
#endif

/// Silica's drawing context, named apart from Cacao's `GraphicsContext`.
package typealias SilicaContext = Silica.GraphicsContext

/// Premultiplied RGBA pixels, rows from the top, drawn or decoded by Silica.
package typealias SilicaImage = Silica.Image

/// The platform's Silica backend: Quartz on macOS, Cairo on Linux.
package enum SilicaPlatform {

    /// The backend's name.
    package static var backendName: String {
        #if canImport(SilicaQuartz)
        return "Quartz"
        #elseif canImport(SilicaCairo)
        return "Cairo"
        #else
        return "None"
        #endif
    }

    /// Makes the platform's backend Silica's default, which draws bitmaps,
    /// loads fonts by name and codes PNG.
    package static func register() {
        #if canImport(SilicaQuartz)
        QuartzBackend.register()
        #elseif canImport(SilicaCairo)
        CairoBackend.register()
        #endif
    }
}

extension Silica.Point {

    init(_ point: CGPoint) {
        self.init(x: Double(point.x), y: Double(point.y))
    }
}

extension Silica.Size {

    init(_ size: CGSize) {
        self.init(width: Double(size.width), height: Double(size.height))
    }
}

extension Silica.Rect {

    init(_ rect: CGRect) {
        self.init(x: Double(rect.minX), y: Double(rect.minY), width: Double(rect.width), height: Double(rect.height))
    }
}

extension Silica.AffineTransform {

    init(_ transform: Transform2D) {
        self.init(
            a: Double(transform.a), b: Double(transform.b),
            c: Double(transform.c), d: Double(transform.d),
            tx: Double(transform.tx), ty: Double(transform.ty)
        )
    }
}

extension Silica.Color {

    init(_ color: ResolvedColor) {
        self.init(red: Double(color.red), green: Double(color.green), blue: Double(color.blue), alpha: Double(color.opacity))
    }
}
