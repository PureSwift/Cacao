//
//  ResolvedColor.swift
//  CacaoRender
//
//  Created by Alsey Coleman Miller on 11/13/26.
//

import Foundation
#if canImport(CoreGraphics)
import CoreGraphics
#endif

/// A concrete color value, with components in the sRGB color space.
public struct ResolvedColor: Hashable, Sendable, CustomStringConvertible {

    public var red: Float

    public var green: Float

    public var blue: Float

    public var opacity: Float

    public init(red: Float, green: Float, blue: Float, opacity: Float = 1) {
        self.red = red
        self.green = green
        self.blue = blue
        self.opacity = opacity
    }

    public var description: String {
        func hex(_ value: Float) -> String {
            let byte = Int((max(0, min(1, value)) * 255).rounded())
            let digits = String(byte, radix: 16, uppercase: true)
            return digits.count == 1 ? "0" + digits : digits
        }
        return "#\(hex(red))\(hex(green))\(hex(blue))\(hex(opacity))"
    }

    /// The components as numbers, for animating.
    package var components: [Double] {
        [Double(red), Double(green), Double(blue), Double(opacity)]
    }

    package init(components: [Double]) {
        self.init(red: Float(components[0]), green: Float(components[1]), blue: Float(components[2]), opacity: Float(components[3]))
    }

    package init(_ r: Int, _ g: Int, _ b: Int, _ opacity: Float = 1) {
        self.init(red: Float(r) / 255, green: Float(g) / 255, blue: Float(b) / 255, opacity: opacity)
    }
}
