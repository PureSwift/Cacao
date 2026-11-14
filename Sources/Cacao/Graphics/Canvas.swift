//
//  Canvas.swift
//  Cacao
//
//  Created by Alsey Coleman Miller on 11/13/26.
//

import Foundation
import Observation
#if canImport(CoreGraphics)
import CoreGraphics
#endif

// MARK: - Drawing content

/// Drawing commands recorded by a canvas, rasterized like a shape.
package struct DrawingContent: Equatable, Sendable {

    package var operations: [Operation]

    package enum Operation: Equatable, Sendable {
        /// A filled or stroked path.
        case shape(ShapeContent, DrawingState)
        /// Text laid out in a rectangle.
        case text(ResolvedText, CGRect, DrawingState)
        /// An image scaled to a rectangle.
        case image(ImageContent, CGRect, DrawingState)
    }
}

/// The transform, opacity and clip a drawing command is drawn with.
package struct DrawingState: Equatable, Sendable {

    package var transform = Transform2D.identity

    package var opacity = 1.0

    /// Paths the drawing is clipped to, each in the coordinates of its
    /// transform.
    package var clips: [(path: Path, transform: Transform2D, isEOFilled: Bool)] = []

    package static func == (lhs: DrawingState, rhs: DrawingState) -> Bool {
        lhs.transform == rhs.transform
            && lhs.opacity == rhs.opacity
            && lhs.clips.count == rhs.clips.count
            && zip(lhs.clips, rhs.clips).allSatisfy { $0.path == $1.path && $0.transform == $1.transform && $0.isEOFilled == $1.isEOFilled }
    }
}

// MARK: - GraphicsContext

/// An immediate mode drawing destination, and its current state.
@MainActor
public struct GraphicsContext {

    /// Collects the commands of a canvas and its layers.
    final class Recorder {
        var operations: [DrawingContent.Operation] = []
        let textEngine: any TextEngine

        init(textEngine: any TextEngine) {
            self.textEngine = textEngine
        }
    }

    let recorder: Recorder

    var state = DrawingState()

    /// The environment of the canvas.
    public let environment: EnvironmentValues

    init(recorder: Recorder, environment: EnvironmentValues) {
        self.recorder = recorder
        self.environment = environment
    }

    /// The opacity of drawing operations in the context.
    public var opacity: Double {
        get { state.opacity }
        set { state.opacity = newValue }
    }

    /// The blend mode used by drawing operations in the context.
    public var blendMode = BlendMode.normal

    /// Moves subsequent drawing operations by an amount in each dimension.
    public mutating func translateBy(x: CGFloat, y: CGFloat) {
        state.transform = Transform2D.translation(x, y).concatenating(state.transform)
    }

    /// Scales subsequent drawing operations by an amount in each dimension.
    public mutating func scaleBy(x: CGFloat, y: CGFloat) {
        state.transform = Transform2D.scale(x, y).concatenating(state.transform)
    }

    /// Rotates subsequent drawing operations by an angle.
    public mutating func rotate(by angle: Angle) {
        state.transform = Transform2D.rotation(CGFloat(angle.radians)).concatenating(state.transform)
    }

    #if canImport(CoreGraphics)
    /// The current transform matrix, defining user space coordinates.
    public var transform: CGAffineTransform {
        get {
            let t = state.transform
            return CGAffineTransform(a: t.a, b: t.b, c: t.c, d: t.d, tx: t.tx, ty: t.ty)
        }
        set {
            state.transform = Transform2D(a: newValue.a, b: newValue.b, c: newValue.c, d: newValue.d, tx: newValue.tx, ty: newValue.ty)
        }
    }

    /// Appends the given transform to the context's existing transform.
    public mutating func concatenate(_ matrix: CGAffineTransform) {
        let t = Transform2D(a: matrix.a, b: matrix.b, c: matrix.c, d: matrix.d, tx: matrix.tx, ty: matrix.ty)
        state.transform = t.concatenating(state.transform)
    }
    #endif

    /// Options that affect the use of clip shapes.
    public struct ClipOptions: OptionSet, Sendable {
        public let rawValue: UInt32
        public init(rawValue: UInt32) { self.rawValue = rawValue }
        /// An option to invert the shape or layer alpha as the clip mask.
        public static let inverse = ClipOptions(rawValue: 1)
    }

    /// Adds a path to the context's array of clip shapes.
    public mutating func clip(to path: Path, style: FillStyle = FillStyle(), options: ClipOptions = ClipOptions()) {
        state.clips.append((path, state.transform, style.isEOFilled))
    }

    /// Draws a new layer, created by drawing code that you provide, into
    /// the context.
    public func drawLayer(content: (inout GraphicsContext) throws -> Void) rethrows {
        var layer = self
        try content(&layer)
    }

    // MARK: Shading

    /// A color or pattern that you can use to outline or fill a path.
    public struct Shading: Sendable {

        let style: any ShapeStyle

        /// A gradient with its geometry in the context's coordinates.
        var absoluteGradient: (Gradient, GradientPaint.Geometry)? = nil

        init(style: any ShapeStyle) {
            self.style = style
        }

        /// Options that affect the rendering of color gradients.
        public struct GradientOptions: OptionSet, Sendable {
            public let rawValue: UInt32
            public init(rawValue: UInt32) { self.rawValue = rawValue }
            public static let `repeat` = GradientOptions(rawValue: 1 << 0)
            public static let mirror = GradientOptions(rawValue: 1 << 1)
            public static let linearColor = GradientOptions(rawValue: 1 << 2)
        }

        /// Returns a shading instance that fills a linear (axial) gradient.
        public static func linearGradient(_ gradient: Gradient, startPoint: CGPoint, endPoint: CGPoint, options: GradientOptions = GradientOptions()) -> Shading {
            var shading = Shading(style: AnyGradient(gradient))
            shading.absoluteGradient = (gradient, .axial(start: startPoint, end: endPoint))
            return shading
        }

        /// Returns a shading instance that fills a radial gradient.
        public static func radialGradient(_ gradient: Gradient, center: CGPoint, startRadius: CGFloat, endRadius: CGFloat, options: GradientOptions = GradientOptions()) -> Shading {
            var shading = Shading(style: AnyGradient(gradient))
            shading.absoluteGradient = (gradient, .radial(center: center, startRadius: startRadius, endRadius: endRadius, scaleY: 1))
            return shading
        }

        /// Returns a shading instance that fills a conic (angular) gradient.
        public static func conicGradient(_ gradient: Gradient, center: CGPoint, angle: Angle = Angle(), options: GradientOptions = GradientOptions()) -> Shading {
            var shading = Shading(style: AnyGradient(gradient))
            shading.absoluteGradient = (gradient, .conic(center: center, startAngle: angle.radians, endAngle: angle.radians + 2 * .pi))
            return shading
        }

        /// The gradient to paint a path with, if the shading is one.
        func resolveGradient(for path: Path, in environment: EnvironmentValues) -> GradientPaint? {
            if let (gradient, geometry) = absoluteGradient {
                return GradientPaint(stops: gradient.resolve(in: environment), geometry: geometry)
            }
            return (style as? ResolvableShapeStyle)?.resolveGradient(in: environment)?.paint(in: path.boundingRect)
        }

        /// A shading instance that draws a copy of the current background.
        public static var backdrop: Shading { Shading(style: Color.clear) }

        /// A shading instance that fills with the foreground style from the
        /// graphics context's environment.
        public static var foreground: Shading { Shading(style: ForegroundStyle()) }

        /// Returns a shading instance that fills with a color.
        public static func color(_ color: Color) -> Shading {
            Shading(style: color)
        }

        /// Returns a shading instance that fills with a color.
        public static func color(red: Double, green: Double, blue: Double, opacity: Double = 1) -> Shading {
            Shading(style: Color(red: red, green: green, blue: blue, opacity: opacity))
        }

        /// Returns a shading instance that fills with the given shape style.
        public static func style<S: ShapeStyle>(_ style: S) -> Shading {
            Shading(style: style)
        }

        func resolve(in environment: EnvironmentValues) -> Color.Resolved {
            if let resolvable = style as? ResolvableShapeStyle {
                return resolvable.resolveColor(in: environment)
            }
            return environment.resolvedForeground
        }
    }

    // MARK: Drawing

    /// Draws a path into the context and fills the outlined region.
    public func fill(_ path: Path, with shading: Shading, style: FillStyle = FillStyle()) {
        let content = ShapeContent(path: path, color: shading.resolve(in: environment), drawing: .fill(style), gradient: shading.resolveGradient(for: path, in: environment))
        recorder.operations.append(.shape(content, state))
    }

    /// Draws a path into the context with a specified stroke style.
    public func stroke(_ path: Path, with shading: Shading, style: StrokeStyle) {
        let content = ShapeContent(path: path, color: shading.resolve(in: environment), drawing: .stroke(style), gradient: shading.resolveGradient(for: path, in: environment))
        recorder.operations.append(.shape(content, state))
    }

    /// Draws a path into the context with a specified line width.
    public func stroke(_ path: Path, with shading: Shading, lineWidth: CGFloat = 1) {
        stroke(path, with: shading, style: StrokeStyle(lineWidth: lineWidth))
    }

    /// Draws text into the context, in a rectangle.
    public func draw(_ text: Text, in rect: CGRect) {
        let resolved = text.resolve(in: environment)
        recorder.operations.append(.text(resolved, rect, state))
    }

    /// Draws text into the context, at a point relative to an anchor of the
    /// text's bounds.
    public func draw(_ text: Text, at point: CGPoint, anchor: UnitPoint = .center) {
        let resolved = text.resolve(in: environment)
        let size = recorder.textEngine.layout(resolved, in: .unspecified).size
        let rect = CGRect(
            x: point.x - size.width * anchor.x,
            y: point.y - size.height * anchor.y,
            width: size.width,
            height: size.height
        )
        recorder.operations.append(.text(resolved, rect, state))
    }

    /// Draws an image into the context, scaled to fit a rectangle.
    public func draw(_ image: Image, in rect: CGRect, style: FillStyle = FillStyle()) {
        guard let content = image.content(in: environment) else { return }
        recorder.operations.append(.image(content, rect, state))
    }

    /// Draws an image into the context, at a point relative to an anchor of
    /// the image's bounds.
    public func draw(_ image: Image, at point: CGPoint, anchor: UnitPoint = .center) {
        guard let content = image.content(in: environment) else { return }
        let size = content.source.size
        let rect = CGRect(x: point.x - size.width * anchor.x, y: point.y - size.height * anchor.y, width: size.width, height: size.height)
        recorder.operations.append(.image(content, rect, state))
    }
}

/// Modes for compositing a view with overlapping content.
public enum BlendMode: Sendable {
    case normal, multiply, screen, overlay, darken, lighten, colorDodge, colorBurn, softLight, hardLight
    case difference, exclusion, hue, saturation, color, luminosity, sourceAtop, destinationOver
    case destinationOut, plusDarker, plusLighter
}

extension Image {

    /// What the image draws, if it has data.
    @MainActor
    func content(in environment: EnvironmentValues) -> ImageContent? {
        let source: ImageSource?
        switch self.source {
        case let .named(name, bundlePath):
            source = ImageSource.named(name, bundlePath: bundlePath, scale: environment.displayScale)
        case .systemName:
            source = nil
        case let .data(data):
            source = data
        }
        guard let source else { return nil }
        let tint: Color.Resolved? = renderingMode == .template ? environment.resolvedForeground : nil
        return ImageContent(source: source, tint: tint, interpolation: interpolation)
    }
}

// MARK: - Canvas

/// A view type that supports immediate mode drawing.
public struct Canvas<Symbols: View>: View, PrimitiveView {

    /// The views to use as symbols.
    public var symbols: Symbols

    /// A function that draws in the canvas.
    public var renderer: (inout GraphicsContext, CGSize) -> Void

    /// Whether the canvas is fully opaque.
    public var isOpaque: Bool

    /// Whether the canvas renders asynchronously.
    public var rendersAsynchronously: Bool

    public typealias Body = Never

    func resolve(in context: ResolveContext) -> Resolution {
        Resolution(behavior: CanvasBehavior(renderer: renderer, environment: context.environment))
    }
}

extension Canvas where Symbols == EmptyView {

    /// Creates and configures a canvas.
    public init(
        opaque: Bool = false,
        colorMode: ColorRenderingMode = .nonLinear,
        rendersAsynchronously: Bool = false,
        renderer: @escaping (inout GraphicsContext, CGSize) -> Void
    ) {
        self.symbols = EmptyView()
        self.renderer = renderer
        self.isOpaque = opaque
        self.rendersAsynchronously = rendersAsynchronously
    }
}

/// The set of possible working color spaces for color-compositing operations.
public enum ColorRenderingMode: Equatable, Hashable, Sendable {
    case nonLinear
    case linear
    case extendedLinear
}

internal struct CanvasBehavior: NodeBehavior {

    let renderer: (inout GraphicsContext, CGSize) -> Void

    let environment: EnvironmentValues

    /// A canvas takes the space it's offered.
    func sizeThatFits(_ proposal: ProposedViewSize, node: ViewNode) -> CGSize {
        proposal.replacingUnspecifiedDimensions()
    }

    func displayContent(node: ViewNode) -> DisplayList.Content? {
        let recorder = GraphicsContext.Recorder(textEngine: node.graph.textEngine)
        var context = GraphicsContext(recorder: recorder, environment: environment)
        // Drawing that reads observable values draws again when they change.
        let token = node.observationToken
        withObservationTracking {
            renderer(&context, node.frame.size)
        } onChange: {
            token.invalidate()
        }
        return .drawing(DrawingContent(operations: recorder.operations))
    }

    /// A canvas takes hits anywhere in its frame.
    func hitTest(_ point: CGPoint, node: ViewNode) -> Bool {
        node.frame.contains(point)
    }
}
