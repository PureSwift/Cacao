//
//  Gradient.swift
//  CacaoTokens
//
//  Created by Alsey Coleman Miller on 11/23/26.
//

import CacaoRender
import Foundation
#if canImport(CoreGraphics)
import CoreGraphics
#endif

public extension StyleTokens {

    /// A fill that runs from the top of a shape to its bottom. Surfaces
    /// that aren't shaded are flat: both ends the same color.
    struct Gradient: Hashable, Sendable {

        /// The stops, from the top (0) to the bottom (1).
        public var stops: [ResolvedGradientStop]

        public init(stops: [ResolvedGradientStop]) {
            self.stops = stops
        }

        /// A gradient from one color at the top to another at the bottom.
        public init(top: ResolvedColor, bottom: ResolvedColor) {
            self.init(stops: [
                ResolvedGradientStop(color: top, location: 0),
                ResolvedGradientStop(color: bottom, location: 1)
            ])
        }

        /// A flat fill.
        public init(_ color: ResolvedColor) {
            self.init(top: color, bottom: color)
        }

        /// The color at the top.
        public var top: ResolvedColor {
            stops.first?.color ?? ResolvedColor(red: 0, green: 0, blue: 0, opacity: 0)
        }

        /// The color at the bottom.
        public var bottom: ResolvedColor {
            stops.last?.color ?? top
        }

        /// Whether every stop is the same color, so a solid fill draws it.
        public var isFlat: Bool {
            stops.allSatisfy { $0.color == top }
        }

        /// The gradient as paint for a shape whose top and bottom edges are
        /// at `minY` and `maxY`.
        public func paint(minY: CGFloat, maxY: CGFloat) -> GradientPaint {
            GradientPaint(stops: stops, geometry: .axial(start: CGPoint(x: 0, y: minY), end: CGPoint(x: 0, y: maxY)))
        }
    }

    /// A shadow cast below a surface.
    struct Shadow: Hashable, Sendable {

        public var color: ResolvedColor

        /// The blur radius.
        public var radius: CGFloat

        /// How far down the shadow falls. Shadows fall straight down, as if
        /// lit from above.
        public var offsetY: CGFloat

        public init(color: ResolvedColor, radius: CGFloat, offsetY: CGFloat) {
            self.color = color
            self.radius = radius
            self.offsetY = offsetY
        }

        /// The shadow as an effect for a display list.
        public var effect: ShadowEffect {
            ShadowEffect(color: color, radius: radius, offset: CGSize(width: 0, height: offsetY))
        }
    }
}
