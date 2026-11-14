//
//  Gradient.swift
//  Cacao
//
//  Created by Alsey Coleman Miller on 11/13/26.
//

import Foundation
#if canImport(CoreGraphics)
import CoreGraphics
#endif

// MARK: - Gradient

/// A color gradient represented as an array of color stops, each having a
/// parametric location value.
public struct Gradient: Hashable, Sendable {

    /// One color stop in the gradient.
    public struct Stop: Hashable, Sendable {

        /// The color for the stop.
        public var color: Color

        /// The parametric location of the stop.
        public var location: CGFloat

        public init(color: Color, location: CGFloat) {
            self.color = color
            self.location = location
        }
    }

    /// The array of color stops.
    public var stops: [Stop]

    /// Creates a gradient from an array of color stops.
    public init(stops: [Stop]) {
        self.stops = stops
    }

    /// Creates a gradient from an array of colors, spaced evenly.
    public init(colors: [Color]) {
        let last = CGFloat(max(colors.count - 1, 1))
        self.stops = colors.enumerated().map { index, color in
            Stop(color: color, location: CGFloat(index) / last)
        }
    }

    internal func resolve(in environment: EnvironmentValues) -> [ResolvedGradientStop] {
        stops
            .map { ResolvedGradientStop(color: $0.color.resolve(in: environment), location: Double($0.location)) }
            .sorted { $0.location < $1.location }
    }
}

/// A color gradient, type-erased.
public struct AnyGradient: Hashable, Sendable, ShapeStyle {

    internal let gradient: Gradient

    /// Creates a type-erased gradient.
    public init(_ gradient: Gradient) {
        self.gradient = gradient
    }
}

extension Color {

    /// A standard gradient for the color: a little lighter at the top and
    /// darker at the bottom.
    public var gradient: AnyGradient {
        AnyGradient(Gradient(colors: [
            self.mix(with: .white, by: 0.12),
            self.mix(with: .black, by: 0.06)
        ]))
    }
}

extension AnyGradient: ResolvableShapeStyle {

    func resolveColor(in environment: EnvironmentValues) -> Color.Resolved {
        GradientStyle.averageColor(of: gradient.resolve(in: environment))
    }

    func resolveGradient(in environment: EnvironmentValues) -> GradientStyle? {
        LinearGradient(gradient: gradient, startPoint: .top, endPoint: .bottom).resolveGradient(in: environment)
    }
}

// MARK: - Linear

/// A linear gradient.
public struct LinearGradient: ShapeStyle, Hashable {

    internal let gradient: Gradient

    internal let startPoint: UnitPoint

    internal let endPoint: UnitPoint

    /// Creates a linear gradient from a base gradient.
    public init(gradient: Gradient, startPoint: UnitPoint, endPoint: UnitPoint) {
        self.gradient = gradient
        self.startPoint = startPoint
        self.endPoint = endPoint
    }

    /// Creates a linear gradient from a collection of colors.
    public init(colors: [Color], startPoint: UnitPoint, endPoint: UnitPoint) {
        self.init(gradient: Gradient(colors: colors), startPoint: startPoint, endPoint: endPoint)
    }

    /// Creates a linear gradient from a collection of color stops.
    public init(stops: [Gradient.Stop], startPoint: UnitPoint, endPoint: UnitPoint) {
        self.init(gradient: Gradient(stops: stops), startPoint: startPoint, endPoint: endPoint)
    }
}

extension LinearGradient: ResolvableShapeStyle {

    func resolveColor(in environment: EnvironmentValues) -> Color.Resolved {
        GradientStyle.averageColor(of: gradient.resolve(in: environment))
    }

    func resolveGradient(in environment: EnvironmentValues) -> GradientStyle? {
        GradientStyle(stops: gradient.resolve(in: environment), kind: .linear(start: startPoint, end: endPoint))
    }
}

// MARK: - Radial

/// A radial gradient.
public struct RadialGradient: ShapeStyle, Hashable {

    internal let gradient: Gradient

    internal let center: UnitPoint

    internal let startRadius: CGFloat

    internal let endRadius: CGFloat

    /// Creates a radial gradient from a base gradient.
    public init(gradient: Gradient, center: UnitPoint, startRadius: CGFloat, endRadius: CGFloat) {
        self.gradient = gradient
        self.center = center
        self.startRadius = startRadius
        self.endRadius = endRadius
    }

    /// Creates a radial gradient from a collection of colors.
    public init(colors: [Color], center: UnitPoint, startRadius: CGFloat, endRadius: CGFloat) {
        self.init(gradient: Gradient(colors: colors), center: center, startRadius: startRadius, endRadius: endRadius)
    }

    /// Creates a radial gradient from a collection of color stops.
    public init(stops: [Gradient.Stop], center: UnitPoint, startRadius: CGFloat, endRadius: CGFloat) {
        self.init(gradient: Gradient(stops: stops), center: center, startRadius: startRadius, endRadius: endRadius)
    }
}

extension RadialGradient: ResolvableShapeStyle {

    func resolveColor(in environment: EnvironmentValues) -> Color.Resolved {
        GradientStyle.averageColor(of: gradient.resolve(in: environment))
    }

    func resolveGradient(in environment: EnvironmentValues) -> GradientStyle? {
        GradientStyle(stops: gradient.resolve(in: environment), kind: .radial(center: center, startRadius: startRadius, endRadius: endRadius))
    }
}

// MARK: - Elliptical

/// A radial gradient that draws an ellipse filling the shape it's drawn in.
public struct EllipticalGradient: ShapeStyle, Hashable {

    internal let gradient: Gradient

    internal let center: UnitPoint

    internal let startRadiusFraction: CGFloat

    internal let endRadiusFraction: CGFloat

    /// Creates an elliptical gradient. The radius fractions are of the
    /// shape's size: 0.5 reaches its edges.
    public init(gradient: Gradient, center: UnitPoint = .center, startRadiusFraction: CGFloat = 0, endRadiusFraction: CGFloat = 0.5) {
        self.gradient = gradient
        self.center = center
        self.startRadiusFraction = startRadiusFraction
        self.endRadiusFraction = endRadiusFraction
    }

    public init(colors: [Color], center: UnitPoint = .center, startRadiusFraction: CGFloat = 0, endRadiusFraction: CGFloat = 0.5) {
        self.init(gradient: Gradient(colors: colors), center: center, startRadiusFraction: startRadiusFraction, endRadiusFraction: endRadiusFraction)
    }

    public init(stops: [Gradient.Stop], center: UnitPoint = .center, startRadiusFraction: CGFloat = 0, endRadiusFraction: CGFloat = 0.5) {
        self.init(gradient: Gradient(stops: stops), center: center, startRadiusFraction: startRadiusFraction, endRadiusFraction: endRadiusFraction)
    }
}

extension EllipticalGradient: ResolvableShapeStyle {

    func resolveColor(in environment: EnvironmentValues) -> Color.Resolved {
        GradientStyle.averageColor(of: gradient.resolve(in: environment))
    }

    func resolveGradient(in environment: EnvironmentValues) -> GradientStyle? {
        GradientStyle(stops: gradient.resolve(in: environment), kind: .elliptical(center: center, startFraction: startRadiusFraction, endFraction: endRadiusFraction))
    }
}

// MARK: - Angular

/// An angular (conic) gradient.
public struct AngularGradient: ShapeStyle, Hashable {

    internal let gradient: Gradient

    internal let center: UnitPoint

    internal let startAngle: Angle

    internal let endAngle: Angle

    /// Creates an angular gradient from a base gradient.
    public init(gradient: Gradient, center: UnitPoint, startAngle: Angle = .zero, endAngle: Angle = .zero) {
        self.gradient = gradient
        self.center = center
        self.startAngle = startAngle
        // Equal angles mean a full turn.
        self.endAngle = endAngle == startAngle ? Angle(radians: startAngle.radians + 2 * .pi) : endAngle
    }

    public init(colors: [Color], center: UnitPoint, startAngle: Angle, endAngle: Angle) {
        self.init(gradient: Gradient(colors: colors), center: center, startAngle: startAngle, endAngle: endAngle)
    }

    public init(stops: [Gradient.Stop], center: UnitPoint, startAngle: Angle, endAngle: Angle) {
        self.init(gradient: Gradient(stops: stops), center: center, startAngle: startAngle, endAngle: endAngle)
    }

    /// Creates a conic gradient that completes a full turn.
    public init(gradient: Gradient, center: UnitPoint, angle: Angle = .zero) {
        self.init(gradient: gradient, center: center, startAngle: angle, endAngle: Angle(radians: angle.radians + 2 * .pi))
    }

    public init(colors: [Color], center: UnitPoint, angle: Angle = .zero) {
        self.init(gradient: Gradient(colors: colors), center: center, angle: angle)
    }

    public init(stops: [Gradient.Stop], center: UnitPoint, angle: Angle = .zero) {
        self.init(gradient: Gradient(stops: stops), center: center, angle: angle)
    }
}

extension AngularGradient: ResolvableShapeStyle {

    func resolveColor(in environment: EnvironmentValues) -> Color.Resolved {
        GradientStyle.averageColor(of: gradient.resolve(in: environment))
    }

    func resolveGradient(in environment: EnvironmentValues) -> GradientStyle? {
        GradientStyle(stops: gradient.resolve(in: environment), kind: .angular(center: center, start: startAngle.radians, end: endAngle.radians))
    }
}

// MARK: - Static members

extension ShapeStyle where Self == LinearGradient {

    public static func linearGradient(_ gradient: Gradient, startPoint: UnitPoint, endPoint: UnitPoint) -> LinearGradient {
        LinearGradient(gradient: gradient, startPoint: startPoint, endPoint: endPoint)
    }

    public static func linearGradient(colors: [Color], startPoint: UnitPoint, endPoint: UnitPoint) -> LinearGradient {
        LinearGradient(colors: colors, startPoint: startPoint, endPoint: endPoint)
    }

    public static func linearGradient(stops: [Gradient.Stop], startPoint: UnitPoint, endPoint: UnitPoint) -> LinearGradient {
        LinearGradient(stops: stops, startPoint: startPoint, endPoint: endPoint)
    }
}

extension ShapeStyle where Self == RadialGradient {

    public static func radialGradient(_ gradient: Gradient, center: UnitPoint, startRadius: CGFloat, endRadius: CGFloat) -> RadialGradient {
        RadialGradient(gradient: gradient, center: center, startRadius: startRadius, endRadius: endRadius)
    }

    public static func radialGradient(colors: [Color], center: UnitPoint, startRadius: CGFloat, endRadius: CGFloat) -> RadialGradient {
        RadialGradient(colors: colors, center: center, startRadius: startRadius, endRadius: endRadius)
    }

    public static func radialGradient(stops: [Gradient.Stop], center: UnitPoint, startRadius: CGFloat, endRadius: CGFloat) -> RadialGradient {
        RadialGradient(stops: stops, center: center, startRadius: startRadius, endRadius: endRadius)
    }
}

extension ShapeStyle where Self == EllipticalGradient {

    public static func ellipticalGradient(_ gradient: Gradient, center: UnitPoint = .center, startRadiusFraction: CGFloat = 0, endRadiusFraction: CGFloat = 0.5) -> EllipticalGradient {
        EllipticalGradient(gradient: gradient, center: center, startRadiusFraction: startRadiusFraction, endRadiusFraction: endRadiusFraction)
    }

    public static func ellipticalGradient(colors: [Color], center: UnitPoint = .center, startRadiusFraction: CGFloat = 0, endRadiusFraction: CGFloat = 0.5) -> EllipticalGradient {
        EllipticalGradient(colors: colors, center: center, startRadiusFraction: startRadiusFraction, endRadiusFraction: endRadiusFraction)
    }
}

extension ShapeStyle where Self == AngularGradient {

    public static func angularGradient(_ gradient: Gradient, center: UnitPoint, startAngle: Angle, endAngle: Angle) -> AngularGradient {
        AngularGradient(gradient: gradient, center: center, startAngle: startAngle, endAngle: endAngle)
    }

    public static func angularGradient(colors: [Color], center: UnitPoint, startAngle: Angle, endAngle: Angle) -> AngularGradient {
        AngularGradient(colors: colors, center: center, startAngle: startAngle, endAngle: endAngle)
    }

    public static func conicGradient(_ gradient: Gradient, center: UnitPoint, angle: Angle = .zero) -> AngularGradient {
        AngularGradient(gradient: gradient, center: center, angle: angle)
    }

    public static func conicGradient(colors: [Color], center: UnitPoint, angle: Angle = .zero) -> AngularGradient {
        AngularGradient(colors: colors, center: center, angle: angle)
    }
}

// MARK: - Resolved

/// A gradient stop with a concrete color.
package struct ResolvedGradientStop: Hashable, Sendable {

    package var color: Color.Resolved

    package var location: Double
}

/// A gradient resolved in an environment, with its geometry in unit points
/// of the shape it fills.
internal struct GradientStyle: Hashable, Sendable {

    enum Kind: Hashable, Sendable {
        case linear(start: UnitPoint, end: UnitPoint)
        case radial(center: UnitPoint, startRadius: CGFloat, endRadius: CGFloat)
        case elliptical(center: UnitPoint, startFraction: CGFloat, endFraction: CGFloat)
        case angular(center: UnitPoint, start: Double, end: Double)
    }

    var stops: [ResolvedGradientStop]

    var kind: Kind

    /// The gradient's geometry in a rectangle.
    func paint(in rect: CGRect) -> GradientPaint {
        func point(_ unit: UnitPoint) -> CGPoint {
            CGPoint(x: rect.minX + unit.x * rect.width, y: rect.minY + unit.y * rect.height)
        }
        let geometry: GradientPaint.Geometry
        switch kind {
        case let .linear(start, end):
            geometry = .axial(start: point(start), end: point(end))
        case let .radial(center, startRadius, endRadius):
            geometry = .radial(center: point(center), startRadius: startRadius, endRadius: endRadius, scaleY: 1)
        case let .elliptical(center, startFraction, endFraction):
            let width = max(rect.width, 0.001)
            geometry = .radial(
                center: point(center),
                startRadius: startFraction * width,
                endRadius: endFraction * width,
                scaleY: width / max(rect.height, 0.001)
            )
        case let .angular(center, start, end):
            geometry = .conic(center: point(center), startAngle: start, endAngle: end)
        }
        return GradientPaint(stops: stops, geometry: geometry)
    }

    /// The stops' colors averaged, for drawing where a gradient can't be.
    static func averageColor(of stops: [ResolvedGradientStop]) -> Color.Resolved {
        guard !stops.isEmpty else { return Color.Resolved(red: 0, green: 0, blue: 0, opacity: 0) }
        let count = Float(stops.count)
        return Color.Resolved(
            red: stops.reduce(0) { $0 + $1.color.red } / count,
            green: stops.reduce(0) { $0 + $1.color.green } / count,
            blue: stops.reduce(0) { $0 + $1.color.blue } / count,
            opacity: stops.reduce(0) { $0 + $1.color.opacity } / count
        )
    }
}

/// A gradient with its geometry in a drawing's coordinate space.
package struct GradientPaint: Equatable, Sendable {

    package enum Geometry: Equatable, Sendable {

        /// Along the line from start to end.
        case axial(start: CGPoint, end: CGPoint)

        /// Outward from a center, its vertical distances scaled by `scaleY`
        /// first for ellipses.
        case radial(center: CGPoint, startRadius: CGFloat, endRadius: CGFloat, scaleY: CGFloat)

        /// Around a center, clockwise from the start angle.
        case conic(center: CGPoint, startAngle: Double, endAngle: Double)
    }

    package var stops: [ResolvedGradientStop]

    package var geometry: Geometry

    package init(stops: [ResolvedGradientStop], geometry: Geometry) {
        self.stops = stops
        self.geometry = geometry
    }

    /// The gradient with every stop's opacity multiplied.
    package func multiplyingOpacity(_ opacity: Float) -> GradientPaint {
        var paint = self
        for index in paint.stops.indices {
            paint.stops[index].color.opacity *= opacity
        }
        return paint
    }

    /// Where a point falls along the gradient, from 0 to 1 at its ends.
    package func location(at point: CGPoint) -> Double {
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
    package func color(atLocation location: Double) -> Color.Resolved {
        guard let first = stops.first, let last = stops.last else {
            return Color.Resolved(red: 0, green: 0, blue: 0, opacity: 0)
        }
        if location <= first.location { return first.color }
        if location >= last.location { return last.color }
        for index in 1..<stops.count where location <= stops[index].location {
            let lower = stops[index - 1], upper = stops[index]
            let span = upper.location - lower.location
            let fraction = Float(span > 0 ? (location - lower.location) / span : 1)
            return Color.Resolved(
                red: lower.color.red + (upper.color.red - lower.color.red) * fraction,
                green: lower.color.green + (upper.color.green - lower.color.green) * fraction,
                blue: lower.color.blue + (upper.color.blue - lower.color.blue) * fraction,
                opacity: lower.color.opacity + (upper.color.opacity - lower.color.opacity) * fraction
            )
        }
        return last.color
    }

    /// The color at a point.
    package func color(at point: CGPoint) -> Color.Resolved {
        color(atLocation: location(at: point))
    }
}

// MARK: - Views

extension LinearGradient: View {

    public var body: some View {
        Rectangle().fill(self)
    }
}

extension RadialGradient: View {

    public var body: some View {
        Rectangle().fill(self)
    }
}

extension EllipticalGradient: View {

    public var body: some View {
        Rectangle().fill(self)
    }
}

extension AngularGradient: View {

    public var body: some View {
        Rectangle().fill(self)
    }
}
