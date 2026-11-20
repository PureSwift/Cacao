//
//  ShapeStyle.swift
//  Cacao
//
//  Created by Alsey Coleman Miller on 11/13/26.
//

import CacaoRender

/// A color or pattern to use when rendering a shape or text.
public protocol ShapeStyle: Sendable { }

/// A style Cacao can resolve to a color in an environment.
internal protocol ResolvableShapeStyle {

    func resolveColor(in environment: EnvironmentValues) -> Color.Resolved

    /// The style's gradient, if it's one.
    func resolveGradient(in environment: EnvironmentValues) -> GradientStyle?
}

extension ResolvableShapeStyle {

    func resolveGradient(in environment: EnvironmentValues) -> GradientStyle? {
        nil
    }
}

extension Color: ShapeStyle, ResolvableShapeStyle {

    func resolveColor(in environment: EnvironmentValues) -> Color.Resolved {
        resolve(in: environment)
    }
}

/// A type-erased shape style.
public struct AnyShapeStyle: ShapeStyle {

    internal let style: any ShapeStyle

    /// Create an instance from `style`.
    public init<S: ShapeStyle>(_ style: S) {
        if let style = style as? AnyShapeStyle {
            self.style = style.style
        } else {
            self.style = style
        }
    }
}

extension AnyShapeStyle: ResolvableShapeStyle {

    func resolveColor(in environment: EnvironmentValues) -> Color.Resolved {
        (style as? any ResolvableShapeStyle)?.resolveColor(in: environment) ?? Color.primary.resolve(in: environment)
    }

    func resolveGradient(in environment: EnvironmentValues) -> GradientStyle? {
        (style as? any ResolvableShapeStyle)?.resolveGradient(in: environment)
    }
}

/// A shape style that maps to one of the numbered content styles.
public struct HierarchicalShapeStyle: ShapeStyle {

    internal let level: Int

    /// A shape style that maps to the first level of the current content style.
    public static let primary = HierarchicalShapeStyle(level: 0)

    /// A shape style that maps to the second level of the current content style.
    public static let secondary = HierarchicalShapeStyle(level: 1)

    /// A shape style that maps to the third level of the current content style.
    public static let tertiary = HierarchicalShapeStyle(level: 2)

    /// A shape style that maps to the fourth level of the current content style.
    public static let quaternary = HierarchicalShapeStyle(level: 3)
}

extension HierarchicalShapeStyle: ResolvableShapeStyle {

    /// The foreground color, at decreasing opacity for each level.
    func resolveColor(in environment: EnvironmentValues) -> Color.Resolved {
        var color = environment.foregroundColor?.resolve(in: environment)
            ?? Color.primary.resolve(in: environment)
        let opacities: [Float] = [1, 0.6, 0.3, 0.18]
        color.opacity *= opacities[min(level, opacities.count - 1)]
        return color
    }
}

/// The foreground style in the current context.
public struct ForegroundStyle: ShapeStyle {

    public init() { }
}

extension ForegroundStyle: ResolvableShapeStyle {

    func resolveColor(in environment: EnvironmentValues) -> Color.Resolved {
        environment.resolvedForeground
    }
}

extension ShapeStyle where Self == ForegroundStyle {

    /// The foreground style in the current context.
    public static var foreground: ForegroundStyle { ForegroundStyle() }
}

extension ShapeStyle where Self == HierarchicalShapeStyle {

    public static var primary: HierarchicalShapeStyle { .primary }

    public static var secondary: HierarchicalShapeStyle { .secondary }

    public static var tertiary: HierarchicalShapeStyle { .tertiary }

    public static var quaternary: HierarchicalShapeStyle { .quaternary }
}

extension ShapeStyle where Self == Color {

    public static var red: Color { Color.red }
    public static var orange: Color { Color.orange }
    public static var yellow: Color { Color.yellow }
    public static var green: Color { Color.green }
    public static var mint: Color { Color.mint }
    public static var teal: Color { Color.teal }
    public static var cyan: Color { Color.cyan }
    public static var blue: Color { Color.blue }
    public static var indigo: Color { Color.indigo }
    public static var purple: Color { Color.purple }
    public static var pink: Color { Color.pink }
    public static var brown: Color { Color.brown }
    public static var gray: Color { Color.gray }
    public static var white: Color { Color.white }
    public static var black: Color { Color.black }
    public static var clear: Color { Color.clear }
}

extension ShapeStyle {

    /// Returns a new style based on this one that multiplies by the
    /// specified opacity when drawing.
    public func opacity(_ opacity: Double) -> some ShapeStyle {
        _OpacityShapeStyle(style: AnyShapeStyle(self), opacity: opacity)
    }
}

internal struct _OpacityShapeStyle: ShapeStyle, ResolvableShapeStyle {

    let style: AnyShapeStyle

    let opacity: Double

    func resolveColor(in environment: EnvironmentValues) -> Color.Resolved {
        var color = style.resolveColor(in: environment)
        color.opacity *= Float(opacity)
        return color
    }

    func resolveGradient(in environment: EnvironmentValues) -> GradientStyle? {
        guard var gradient = style.resolveGradient(in: environment) else { return nil }
        for index in gradient.stops.indices {
            gradient.stops[index].color.opacity *= Float(opacity)
        }
        return gradient
    }
}

extension EnvironmentValues {

    /// The color of foreground content: the foreground style, or the
    /// foreground color, or the primary color.
    internal var resolvedForeground: Color.Resolved {
        if let style = foregroundStyle {
            return style.resolveColor(in: self)
        }
        return (foregroundColor ?? .primary).resolve(in: self)
    }

    /// The gradient of foreground content, if its style is one.
    internal var resolvedForegroundGradient: GradientStyle? {
        foregroundStyle?.resolveGradient(in: self)
    }
}

/// A view that fills the space it's offered with a shape style.
internal struct _ShapeStyleView: View, PrimitiveView {

    let style: any ShapeStyle

    func resolve(in context: ResolveContext) -> Resolution {
        let style = AnyShapeStyle(style)
        if let material = style.style as? Material {
            return Resolution(children: [
                ChildView(key: "material", view: _MaterialView(shape: Rectangle(), material: material)),
            ])
        }
        let color = style.resolveColor(in: context.environment)
        if let gradient = style.resolveGradient(in: context.environment) {
            return Resolution(behavior: ShapeBehavior(shape: Rectangle(), color: color, gradient: gradient, drawing: .fill(FillStyle())))
        }
        return Resolution(behavior: FillBehavior(color: color))
    }

    typealias Body = Never
}

/// A style that reflects the current tint color.
public struct TintShapeStyle: ShapeStyle, ResolvableShapeStyle {

    public init() { }

    func resolveColor(in environment: EnvironmentValues) -> Color.Resolved {
        Color.accentColor.resolve(in: environment)
    }
}

extension ShapeStyle where Self == TintShapeStyle {

    /// A style that reflects the current tint color.
    public static var tint: TintShapeStyle { TintShapeStyle() }
}
