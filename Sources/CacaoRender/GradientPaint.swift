//
//  GradientPaint.swift
//  CacaoRender
//
//  Created by Alsey Coleman Miller on 11/13/26.
//

import Foundation
#if canImport(CoreGraphics)
import CoreGraphics
#endif

/// A gradient stop with a concrete color.
public struct ResolvedGradientStop: Hashable, Sendable {

    public var color: ResolvedColor

    public var location: Double

    public init(color: ResolvedColor, location: Double) {
        self.color = color
        self.location = location
    }
}

/// A gradient with its geometry in a drawing's coordinate space.
public struct GradientPaint: Equatable, Sendable {

    public enum Geometry: Equatable, Sendable {

        /// Along the line from start to end.
        case axial(start: CGPoint, end: CGPoint)

        /// Outward from a center, its vertical distances scaled by `scaleY`
        /// first for ellipses.
        case radial(center: CGPoint, startRadius: CGFloat, endRadius: CGFloat, scaleY: CGFloat)

        /// Around a center, clockwise from the start angle.
        case conic(center: CGPoint, startAngle: Double, endAngle: Double)
    }

    public var stops: [ResolvedGradientStop]

    public var geometry: Geometry

    public init(stops: [ResolvedGradientStop], geometry: Geometry) {
        self.stops = stops
        self.geometry = geometry
    }

    /// The gradient with every stop's opacity multiplied.
    public func multiplyingOpacity(_ opacity: Float) -> GradientPaint {
        var paint = self
        for index in paint.stops.indices {
            paint.stops[index].color.opacity *= opacity
        }
        return paint
    }

    /// Where a point falls along the gradient, from 0 to 1 at its ends.
    public func location(at point: CGPoint) -> Double {
        switch geometry {
        case let .axial(start, end):
            let dx = end.x - start.x, dy = end.y - start.y
            let lengthSquared = dx * dx + dy * dy
            guard lengthSquared > 0 else { return 0 }
            return Double(((point.x - start.x) * dx + (point.y - start.y) * dy) / lengthSquared)
        case let .radial(center, startRadius, endRadius, scaleY):
            let dx = point.x - center.x, dy = (point.y - center.y) * scaleY
            let distance = (dx * dx + dy * dy).squareRoot()
            let span = endRadius - startRadius
            guard span != 0 else { return distance >= endRadius ? 1 : 0 }
            return Double((distance - startRadius) / span)
        case let .conic(center, startAngle, endAngle):
            let span = endAngle - startAngle
            guard span != 0 else { return 0 }
            var angle = atan2(Double(point.y - center.y), Double(point.x - center.x)) - startAngle
            let turn = 2 * Double.pi
            angle = angle.truncatingRemainder(dividingBy: turn)
            if angle < 0 { angle += turn }
            return angle / span
        }
    }

    /// The color at a location, between the stops around it.
    public func color(atLocation location: Double) -> ResolvedColor {
        guard let first = stops.first, let last = stops.last else {
            return ResolvedColor(red: 0, green: 0, blue: 0, opacity: 0)
        }
        if location <= first.location { return first.color }
        if location >= last.location { return last.color }
        for index in 1..<stops.count where location <= stops[index].location {
            let lower = stops[index - 1], upper = stops[index]
            let span = upper.location - lower.location
            let fraction = Float(span > 0 ? (location - lower.location) / span : 1)
            return ResolvedColor(
                red: lower.color.red + (upper.color.red - lower.color.red) * fraction,
                green: lower.color.green + (upper.color.green - lower.color.green) * fraction,
                blue: lower.color.blue + (upper.color.blue - lower.color.blue) * fraction,
                opacity: lower.color.opacity + (upper.color.opacity - lower.color.opacity) * fraction
            )
        }
        return last.color
    }

    /// The color at a point.
    public func color(at point: CGPoint) -> ResolvedColor {
        color(atLocation: location(at: point))
    }
}
