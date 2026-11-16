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

    package init(operations: [Operation]) {
        self.operations = operations
    }

    package enum Operation: Equatable, Sendable {
        /// A filled or stroked path.
        case shape(ShapeContent, DrawingState)
        /// Text laid out in a rectangle.
        case text(ResolvedText, CGRect, DrawingState)
        /// An image scaled to a rectangle.
        case image(ImageContent, CGRect, DrawingState)
        /// A path filled with an image repeated from an origin, at a scale.
        case tiledImage(Path, isEOFilled: Bool, ImageContent, origin: CGPoint, scale: CGFloat, DrawingState)
        /// A view's drawing (a canvas symbol), its frames from its origin.
        case items([DisplayList.Item], DrawingState)
        /// Operations drawn together, then composited with the state's
        /// opacity, blend mode, filters and masks.
        case layer(DrawingContent, DrawingState)

        package var state: DrawingState {
            switch self {
            case let .shape(_, state), let .text(_, _, state), let .image(_, _, state),
                 let .tiledImage(_, _, _, _, _, state), let .items(_, state), let .layer(_, state):
                state
            }
        }
    }
}

/// A clip of drawing commands: a path, in the coordinates of a transform.
package struct DrawingClip: Equatable, Sendable {

    package var path: Path

    package var transform: Transform2D

    package var isEOFilled: Bool

    /// Whether drawing shows outside the path instead.
    package var isInverse = false

    package init(path: Path, transform: Transform2D, isEOFilled: Bool, isInverse: Bool = false) {
        self.path = path
        self.transform = transform
        self.isEOFilled = isEOFilled
        self.isInverse = isInverse
    }
}

/// A filter applied to drawing as it's composited.
package enum DrawingFilter: Equatable, Sendable {
    /// A shadow: the drawing's silhouette in a color, blurred and moved,
    /// below the drawing, above it or alone.
    case shadow(color: Color.Resolved, radius: CGFloat, offset: CGSize, blendMode: BlendMode, placement: ShadowPlacement, invertsAlpha: Bool)
    /// A Gaussian blur.
    case blur(radius: CGFloat, isOpaque: Bool)
    /// A transformation of colors.
    case colorMatrix(ColorMatrix)
    /// Opaque in a color where alpha is in a range, transparent elsewhere.
    case alphaThreshold(min: Double, max: Double, color: Color.Resolved)

    package enum ShadowPlacement: Equatable, Sendable {
        case below, above, only
    }
}

/// A layer whose alpha masks drawing commands.
package struct DrawingMask: Equatable, Sendable {

    package var content: DrawingContent

    package var opacity: Double

    package var isInverse: Bool
}

/// The transform, opacity, clips, blend mode, filters and masks a drawing
/// command is drawn with.
package struct DrawingState: Equatable, Sendable {

    package var transform = Transform2D.identity

    package var opacity = 1.0

    /// Paths the drawing is clipped to.
    package var clips: [DrawingClip] = []

    package var blendMode = BlendMode.normal

    package var filters: [DrawingFilter] = []

    package var masks: [DrawingMask] = []

    package init() { }

    /// Whether the command composites on its own, from its own bitmap.
    package var isComposited: Bool {
        blendMode != .normal || !filters.isEmpty || !masks.isEmpty
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
        /// The canvas's symbols by tag: their drawing, and size.
        let symbols: [AnyHashable: (items: [DisplayList.Item], size: CGSize)]

        init(textEngine: any TextEngine, symbols: [AnyHashable: (items: [DisplayList.Item], size: CGSize)] = [:]) {
            self.textEngine = textEngine
            self.symbols = symbols
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
    public var blendMode: BlendMode {
        get { state.blendMode }
        set { state.blendMode = newValue }
    }

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

    /// The bounding rectangle of the intersection of all current clip
    /// shapes in the current user space.
    public var clipBoundingRect: CGRect {
        var result = CGRect(x: -1e6, y: -1e6, width: 2e6, height: 2e6)
        for clip in state.clips where !clip.isInverse {
            result = result.intersection(clip.transform.boundingRect(of: clip.path.boundingRect))
        }
        guard let inverse = state.transform.inverted() else { return result }
        return inverse.boundingRect(of: result)
    }

    /// Adds a path to the context's array of clip shapes.
    public mutating func clip(to path: Path, style: FillStyle = FillStyle(), options: ClipOptions = ClipOptions()) {
        state.clips.append(DrawingClip(path: path, transform: state.transform, isEOFilled: style.isEOFilled, isInverse: options.contains(.inverse)))
    }

    /// Adds a clip shape that you define in a new layer to the context's
    /// array of clip shapes: later drawing shows as much as the layer is
    /// opaque.
    public mutating func clipToLayer(opacity: Double = 1, options: ClipOptions = ClipOptions(), content: (inout GraphicsContext) throws -> Void) rethrows {
        let recorder = Recorder(textEngine: self.recorder.textEngine, symbols: self.recorder.symbols)
        var layer = GraphicsContext(recorder: recorder, environment: environment)
        layer.state.transform = state.transform
        layer.state.clips = state.clips
        try content(&layer)
        state.masks.append(DrawingMask(content: DrawingContent(operations: recorder.operations), opacity: opacity, isInverse: options.contains(.inverse)))
    }

    /// Draws a new layer, created by drawing code that you provide, into
    /// the context. The layer composites as one with the context's opacity,
    /// blend mode and filters.
    public func drawLayer(content: (inout GraphicsContext) throws -> Void) rethrows {
        let recorder = Recorder(textEngine: self.recorder.textEngine, symbols: self.recorder.symbols)
        var layer = GraphicsContext(recorder: recorder, environment: environment)
        layer.state.transform = state.transform
        layer.state.clips = state.clips
        try content(&layer)
        recorder.operations.isEmpty ? () : self.recorder.operations.append(.layer(DrawingContent(operations: recorder.operations), state))
    }

    // MARK: Filters

    /// A type that applies image processing operations to rendered content.
    public struct Filter: Sendable {

        internal let filter: @MainActor (EnvironmentValues) -> DrawingFilter

        /// Returns a filter that adds a shadow.
        public static func shadow(
            color: Color = Color(white: 0, opacity: 0.33),
            radius: CGFloat,
            x: CGFloat = 0,
            y: CGFloat = 0,
            blendMode: BlendMode = .normal,
            options: ShadowOptions = ShadowOptions()
        ) -> Filter {
            Filter { environment in
                let placement: DrawingFilter.ShadowPlacement = options.contains(.shadowOnly) ? .only : options.contains(.shadowAbove) ? .above : .below
                return .shadow(color: color.resolve(in: environment), radius: radius, offset: CGSize(width: x, height: y), blendMode: blendMode, placement: placement, invertsAlpha: options.contains(.invertsAlpha))
            }
        }

        /// Returns a filter that applies a Gaussian blur.
        public static func blur(radius: CGFloat, options: BlurOptions = BlurOptions()) -> Filter {
            Filter { _ in .blur(radius: radius, isOpaque: options.contains(.opaque)) }
        }

        /// Returns a filter that multiplies each color by a color.
        public static func colorMultiply(_ color: Color) -> Filter {
            Filter { .colorMatrix(.multiply(color.resolve(in: $0))) }
        }

        /// Returns a filter that transforms colors by a matrix.
        public static func colorMatrix(_ matrix: ColorMatrix) -> Filter {
            Filter { _ in .colorMatrix(matrix) }
        }

        public static func hueRotation(_ angle: Angle) -> Filter {
            Filter { _ in .colorMatrix(.hueRotation(angle)) }
        }

        public static func saturation(_ amount: Double) -> Filter {
            Filter { _ in .colorMatrix(.saturation(amount)) }
        }

        public static func brightness(_ amount: Double) -> Filter {
            Filter { _ in .colorMatrix(.brightness(amount)) }
        }

        public static func contrast(_ amount: Double) -> Filter {
            Filter { _ in .colorMatrix(.contrast(amount)) }
        }

        public static func colorInvert(_ amount: Double = 1) -> Filter {
            Filter { _ in
                let invert = ColorMatrix.invert.rows, identity = ColorMatrix().rows
                return .colorMatrix(ColorMatrix(rows: (0..<4).map { row in
                    (0..<5).map { identity[row][$0] + (invert[row][$0] - identity[row][$0]) * Float(amount) }
                }))
            }
        }

        public static func grayscale(_ amount: Double) -> Filter {
            Filter { _ in .colorMatrix(.saturation(1 - amount)) }
        }

        public static var luminanceToAlpha: Filter {
            Filter { _ in .colorMatrix(.luminanceToAlpha) }
        }

        /// Returns a filter that makes pixels opaque in a color where their
        /// alpha is between two values, and transparent elsewhere.
        public static func alphaThreshold(min: Double, max: Double = 1, color: Color = Color.black) -> Filter {
            Filter { .alphaThreshold(min: min, max: max, color: color.resolve(in: $0)) }
        }
    }

    /// Options that configure the graphics context filter that creates
    /// shadows.
    public struct ShadowOptions: OptionSet, Sendable {
        public let rawValue: UInt32
        public init(rawValue: UInt32) { self.rawValue = rawValue }
        public static let shadowAbove = ShadowOptions(rawValue: 1 << 0)
        public static let shadowOnly = ShadowOptions(rawValue: 1 << 1)
        public static let invertsAlpha = ShadowOptions(rawValue: 1 << 2)
        public static let disablesGroup = ShadowOptions(rawValue: 1 << 3)
    }

    /// Options that configure the graphics context filter that creates blur.
    public struct BlurOptions: OptionSet, Sendable {
        public let rawValue: UInt32
        public init(rawValue: UInt32) { self.rawValue = rawValue }
        public static let opaque = BlurOptions(rawValue: 1 << 0)
        public static let dithersResult = BlurOptions(rawValue: 1 << 1)
    }

    /// Options that configure a filter that you add to a graphics context.
    public struct FilterOptions: OptionSet, Sendable {
        public let rawValue: UInt32
        public init(rawValue: UInt32) { self.rawValue = rawValue }
        public static let linearColor = FilterOptions(rawValue: 1 << 0)
    }

    /// Adds a filter that applies to subsequent drawing operations.
    public mutating func addFilter(_ filter: Filter, options: FilterOptions = FilterOptions()) {
        state.filters.append(filter.filter(environment))
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

        /// An image repeated from an origin, at a scale.
        var tiledImage: (image: Image, origin: CGPoint, scale: CGFloat)? = nil

        /// Returns a shading instance that tiles an image across the
        /// infinite plane.
        public static func tiledImage(_ image: Image, origin: CGPoint = CGPoint(x: 0, y: 0), sourceRect: CGRect = CGRect(x: 0, y: 0, width: 1, height: 1), scale: CGFloat = 1) -> Shading {
            var shading = Shading(style: Color.clear)
            shading.tiledImage = (image, origin, scale)
            return shading
        }

        /// Returns a multilevel shading instance constructed from an array
        /// of shading instances; Cacao draws with the first.
        public static func palette(_ array: [Shading]) -> Shading {
            array.first ?? .foreground
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
        if let tiled = shading.tiledImage {
            if let image = tiled.image.content(in: environment) {
                recorder.operations.append(.tiledImage(path, isEOFilled: style.isEOFilled, image, origin: tiled.origin, scale: tiled.scale, state))
            }
            return
        }
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

    // MARK: Text

    /// A text view resolved to a particular environment.
    @MainActor
    public struct ResolvedText {

        let text: Cacao.ResolvedText

        let textEngine: any TextEngine

        /// The shading the text draws with.
        public var shading: Shading

        /// Measures the size of the text, as it fits a size.
        public func measure(in size: CGSize) -> CGSize {
            textEngine.layout(text, in: ProposedViewSize(size)).size
        }

        /// The distance from the top of the text to its first baseline.
        public func firstBaseline(in size: CGSize) -> CGFloat {
            textEngine.layout(text, in: ProposedViewSize(size)).firstBaseline
        }

        /// The distance from the top of the text to its last baseline.
        public func lastBaseline(in size: CGSize) -> CGFloat {
            textEngine.layout(text, in: ProposedViewSize(size)).lastBaseline
        }
    }

    /// Gets a version of a text view that's fixed with the current values
    /// of the graphics context's environment.
    public func resolve(_ text: Text) -> ResolvedText {
        ResolvedText(text: text.resolve(in: environment), textEngine: recorder.textEngine, shading: .foreground)
    }

    /// Draws resolved text into the context, in a rectangle.
    public func draw(_ text: ResolvedText, in rect: CGRect) {
        recorder.operations.append(.text(shaded(text), rect, state))
    }

    /// Draws resolved text into the context, at a point relative to an
    /// anchor of the text's bounds.
    public func draw(_ text: ResolvedText, at point: CGPoint, anchor: UnitPoint = .center) {
        let size = text.measure(in: CGSize(width: CGFloat.infinity, height: .infinity))
        draw(text, in: CGRect(x: point.x - size.width * anchor.x, y: point.y - size.height * anchor.y, width: size.width, height: size.height))
    }

    /// The text in its shading's color.
    private func shaded(_ text: ResolvedText) -> Cacao.ResolvedText {
        var resolved = text.text
        if text.shading.tiledImage == nil, !(text.shading.style is ForegroundStyle) {
            let color = text.shading.resolve(in: environment)
            for index in resolved.runs.indices {
                resolved.runs[index].color = color
            }
        }
        return resolved
    }

    /// Draws text into the context, in a rectangle.
    public func draw(_ text: Text, in rect: CGRect) {
        draw(resolve(text), in: rect)
    }

    /// Draws text into the context, at a point relative to an anchor of the
    /// text's bounds.
    public func draw(_ text: Text, at point: CGPoint, anchor: UnitPoint = .center) {
        draw(resolve(text), at: point, anchor: anchor)
    }

    // MARK: Images

    /// An image resolved to a particular environment.
    public struct ResolvedImage {

        let image: Image

        let content: ImageContent?

        /// The size of the image.
        public let size: CGSize

        /// The distance from the top of the image to its baseline.
        public var baseline: CGFloat { size.height }

        /// The shading of a template image.
        public var shading: Shading?
    }

    /// Gets a version of an image that's fixed with the current values of
    /// the graphics context's environment.
    public func resolve(_ image: Image) -> ResolvedImage {
        if case .systemName = image.source {
            let side = (environment.font ?? .body).resolve().size
            return ResolvedImage(image: image, content: nil, size: CGSize(width: side, height: side))
        }
        let content = image.content(in: environment)
        return ResolvedImage(image: image, content: content, size: content?.source.size ?? .zero)
    }

    /// Draws a resolved image into the context, scaled to a rectangle.
    public func draw(_ image: ResolvedImage, in rect: CGRect, style: FillStyle = FillStyle()) {
        if case let .systemName(name) = image.image.source {
            drawSymbol(name, in: rect, shading: image.shading ?? .foreground)
            return
        }
        guard var content = image.content else { return }
        if let shading = image.shading, content.tint != nil || image.image.renderingMode == .template {
            content.tint = shading.resolve(in: environment)
        }
        recorder.operations.append(.image(content, rect, state))
    }

    /// Draws a resolved image into the context, at a point relative to an
    /// anchor of the image's bounds.
    public func draw(_ image: ResolvedImage, at point: CGPoint, anchor: UnitPoint = .center) {
        let size = image.size
        draw(image, in: CGRect(x: point.x - size.width * anchor.x, y: point.y - size.height * anchor.y, width: size.width, height: size.height))
    }

    /// Draws an image into the context, scaled to fit a rectangle.
    public func draw(_ image: Image, in rect: CGRect, style: FillStyle = FillStyle()) {
        draw(resolve(image), in: rect, style: style)
    }

    /// Draws an image into the context, at a point relative to an anchor of
    /// the image's bounds.
    public func draw(_ image: Image, at point: CGPoint, anchor: UnitPoint = .center) {
        draw(resolve(image), at: point, anchor: anchor)
    }

    /// Draws a system symbol's parts, with the context's state.
    private func drawSymbol(_ name: String, in rect: CGRect, shading: Shading) {
        guard let parts = Symbols.parts(name) else { return }
        let symbol = Symbols.drawing(
            parts,
            in: rect,
            color: shading.resolve(in: environment),
            gradient: (shading.style as? ResolvableShapeStyle)?.resolveGradient(in: environment)?.paint(in: rect),
            weight: (environment.font ?? .body).resolve().weight
        )
        for operation in symbol.operations {
            guard case let .shape(shape, partState) = operation else { continue }
            var combined = state
            combined.transform = partState.transform.concatenating(state.transform)
            recorder.operations.append(.shape(shape, combined))
        }
    }

    // MARK: Symbols

    /// A static sequence of drawing operations that may be drawn multiple
    /// times, preserving their resolution independence.
    public struct ResolvedSymbol {

        let items: [DisplayList.Item]

        /// The size of the symbol.
        public let size: CGSize
    }

    /// Returns a resolved symbol for the canvas's view tagged with an
    /// identifier, or `nil` if there isn't one.
    public func resolveSymbol<ID: Hashable>(id: ID) -> ResolvedSymbol? {
        recorder.symbols[AnyHashable(id)].map { ResolvedSymbol(items: $0.items, size: $0.size) }
    }

    /// Draws a resolved symbol into the context, scaled to a rectangle.
    public func draw(_ symbol: ResolvedSymbol, in rect: CGRect) {
        guard symbol.size.width > 0, symbol.size.height > 0 else { return }
        var symbolState = state
        symbolState.transform = Transform2D.scale(rect.width / symbol.size.width, rect.height / symbol.size.height)
            .concatenating(.translation(rect.minX, rect.minY))
            .concatenating(state.transform)
        recorder.operations.append(.items(symbol.items, symbolState))
    }

    /// Draws a resolved symbol into the context, at a point relative to an
    /// anchor of the symbol's bounds.
    public func draw(_ symbol: ResolvedSymbol, at point: CGPoint, anchor: UnitPoint = .center) {
        let size = symbol.size
        draw(symbol, in: CGRect(x: point.x - size.width * anchor.x, y: point.y - size.height * anchor.y, width: size.width, height: size.height))
    }
}

/// Modes for compositing a view with overlapping content.
public enum BlendMode: Hashable, Sendable {
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
        Resolution(
            behavior: CanvasBehavior(renderer: renderer, environment: context.environment),
            children: Symbols.self == EmptyView.self ? [] : [ChildView(key: 0, view: symbols)]
        )
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

extension Canvas {

    /// Creates and configures a canvas that you supply with renderable
    /// child views, tagged to draw with `resolveSymbol(id:)`.
    public init(
        opaque: Bool = false,
        colorMode: ColorRenderingMode = .nonLinear,
        rendersAsynchronously: Bool = false,
        renderer: @escaping (inout GraphicsContext, CGSize) -> Void,
        @ViewBuilder symbols: () -> Symbols
    ) {
        self.symbols = symbols()
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

    /// Symbols take their ideal sizes, at the canvas's origin.
    func placeChildren(in bounds: CGRect, proposal: ProposedViewSize, node: ViewNode) {
        for child in node.layoutChildren {
            child.place(at: bounds.origin, proposal: .unspecified)
        }
    }

    /// Symbols don't show by themselves.
    func displayOrder(of children: [ViewNode]) -> [ViewNode] {
        []
    }

    /// The tagged symbols' drawings, from their origins, and sizes.
    private func symbols(node: ViewNode) -> [AnyHashable: (items: [DisplayList.Item], size: CGSize)] {
        var symbols: [AnyHashable: (items: [DisplayList.Item], size: CGSize)] = [:]
        func collect(_ proxies: [LayoutProxy]) {
            for proxy in proxies {
                switch proxy.storage {
                case let .node(child):
                    guard let tag = proxy.traits[TagKey.self] else { continue }
                    let frame = child.subtreeFrame
                    let items = child.displayItems().map { $0.offsetBy(dx: -frame.minX, dy: -frame.minY) }
                    symbols[tag] = (items, frame.size)
                case let .group(group):
                    collect(group)
                }
            }
        }
        collect(node.layoutChildren)
        return symbols
    }

    func displayContent(node: ViewNode) -> DisplayList.Content? {
        let recorder = GraphicsContext.Recorder(textEngine: node.graph.textEngine, symbols: symbols(node: node))
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

extension DisplayList.Item {

    /// The item, and the items it nests, moved.
    package func offsetBy(dx: CGFloat, dy: CGFloat) -> DisplayList.Item {
        var item = self
        item.frame = frame.offsetBy(dx: dx, dy: dy)
        switch value {
        case .content:
            break
        case let .effect(.scroll(effect), nested):
            var effect = effect
            effect.viewport = effect.viewport.offsetBy(dx: dx, dy: dy)
            item.value = .effect(.scroll(effect), DisplayList(items: nested.items.map { $0.offsetBy(dx: dx, dy: dy) }))
        case let .effect(.transform(transform), nested):
            let moved = Transform2D.translation(-dx, -dy).concatenating(transform).concatenating(.translation(dx, dy))
            item.value = .effect(.transform(moved), DisplayList(items: nested.items.map { $0.offsetBy(dx: dx, dy: dy) }))
        case let .effect(.mask(mask), nested):
            item.value = .effect(.mask(DisplayList(items: mask.items.map { $0.offsetBy(dx: dx, dy: dy) })), DisplayList(items: nested.items.map { $0.offsetBy(dx: dx, dy: dy) }))
        case let .effect(effect, nested):
            item.value = .effect(effect, DisplayList(items: nested.items.map { $0.offsetBy(dx: dx, dy: dy) }))
        }
        return item
    }
}
