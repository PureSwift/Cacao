//
//  Shape.swift
//  Cacao
//
//  Created by Alsey Coleman Miller on 11/13/26.
//

import CacaoRender
import Foundation
#if canImport(CoreGraphics)
import CoreGraphics
#endif

// MARK: - Shape

/// A 2D shape that you can use when drawing a view.
///
/// Shapes without an explicit fill or stroke get a default fill based on the
/// foreground style.
public protocol Shape: Sendable, View {

    /// Describes this shape as a path within a rectangular frame of reference.
    nonisolated func path(in rect: CGRect) -> Path

    /// Returns the size of the view that will render the shape, given a
    /// proposed size.
    nonisolated func sizeThatFits(_ proposal: ProposedViewSize) -> CGSize
}

extension Shape {

    /// Shapes take the proposed size, and 10 points along unspecified dimensions.
    public nonisolated func sizeThatFits(_ proposal: ProposedViewSize) -> CGSize {
        proposal.replacingUnspecifiedDimensions()
    }

    public var body: _ShapeView<Self, ForegroundStyle> {
        _ShapeView(shape: self, style: ForegroundStyle(), drawing: .fill(FillStyle()))
    }

    /// Fills this shape with a color or gradient.
    public func fill<S: ShapeStyle>(_ content: S = .foreground, style: FillStyle = FillStyle()) -> _ShapeView<Self, S> {
        _ShapeView(shape: self, style: content, drawing: .fill(style))
    }

    /// Traces the outline of this shape with a color or gradient.
    public func stroke<S: ShapeStyle>(_ content: S, style: StrokeStyle) -> _ShapeView<Self, S> {
        _ShapeView(shape: self, style: content, drawing: .stroke(style))
    }

    /// Traces the outline of this shape with a color or gradient.
    public func stroke<S: ShapeStyle>(_ content: S, lineWidth: CGFloat = 1) -> _ShapeView<Self, S> {
        stroke(content, style: StrokeStyle(lineWidth: lineWidth))
    }

    /// Traces the outline of this shape with the foreground style.
    public func stroke(style: StrokeStyle) -> _ShapeView<Self, ForegroundStyle> {
        stroke(ForegroundStyle(), style: style)
    }

    /// Traces the outline of this shape with the foreground style.
    public func stroke(lineWidth: CGFloat = 1) -> _ShapeView<Self, ForegroundStyle> {
        stroke(ForegroundStyle(), style: StrokeStyle(lineWidth: lineWidth))
    }
}

/// A shape type that is able to inset itself to produce another shape.
public protocol InsettableShape: Shape {

    /// The type of the inset shape.
    associatedtype InsetShape: InsettableShape

    /// Returns `self` inset by `amount`.
    nonisolated func inset(by amount: CGFloat) -> InsetShape
}

extension InsettableShape {

    /// Returns a view that is the result of insetting `self` by
    /// `style.lineWidth / 2`, stroking the resulting shape with `style`, and
    /// then filling with `content`.
    public func strokeBorder<S: ShapeStyle>(_ content: S, style: StrokeStyle) -> _ShapeView<InsetShape, S> {
        inset(by: style.lineWidth / 2).stroke(content, style: style)
    }

    /// Strokes the border of this shape inside its frame.
    public func strokeBorder<S: ShapeStyle>(_ content: S, lineWidth: CGFloat = 1) -> _ShapeView<InsetShape, S> {
        strokeBorder(content, style: StrokeStyle(lineWidth: lineWidth))
    }

    /// Strokes the border of this shape inside its frame with the foreground style.
    public func strokeBorder(lineWidth: CGFloat = 1) -> _ShapeView<InsetShape, ForegroundStyle> {
        strokeBorder(ForegroundStyle(), lineWidth: lineWidth)
    }
}

// MARK: - Shape view

/// A view that draws a shape with a style.
public struct _ShapeView<Content: Shape, Style: ShapeStyle>: View, PrimitiveView {

    public var shape: Content

    public var style: Style

    internal let drawing: ShapeDrawing

    internal init(shape: Content, style: Style, drawing: ShapeDrawing) {
        self.shape = shape
        self.style = style
        self.drawing = drawing
    }

    public typealias Body = Never

    func resolve(in context: ResolveContext) -> Resolution {
        let style = AnyShapeStyle(style)
        // A material fills a shape with what's behind it, blurred, under
        // its tint.
        if let material = style.style as? Material, case .fill = drawing {
            return Resolution(children: [
                ChildView(key: "material", view: _MaterialView(shape: shape, material: material)),
            ])
        }
        return Resolution(behavior: ShapeBehavior(
            shape: shape,
            color: style.resolveColor(in: context.environment),
            gradient: style.resolveGradient(in: context.environment),
            drawing: drawing
        ))
    }
}

/// The corner radius of a rounded rectangle with round corners, or of a
/// capsule, that fills `bounds`; nil for any other shape. Cacao draws both
/// styles of corner as circular arcs.
internal func circularCornerRadius(of shape: some Shape, in bounds: CGRect) -> CGFloat? {
    if let rounded = shape as? RoundedRectangle, rounded.insetAmount == 0, rounded.cornerSize.width == rounded.cornerSize.height {
        return rounded.cornerSize.width
    }
    if let capsule = shape as? Capsule, capsule.insetAmount == 0 {
        return min(bounds.width, bounds.height) / 2
    }
    return nil
}

internal struct ShapeBehavior<S: Shape>: AnimatableBehavior {

    var shape: S

    var color: Color.Resolved

    var gradient: GradientStyle? = nil

    let drawing: ShapeDrawing

    func sizeThatFits(_ proposal: ProposedViewSize, node: ViewNode) -> CGSize {
        shape.sizeThatFits(proposal)
    }

    /// The color, then the shape's animatable data, if it has any.
    var animatableValues: [Double] {
        color.components + (Self.shapeData(shape) ?? [])
    }

    func applying(_ values: [Double]) -> any NodeBehavior {
        var behavior = self
        behavior.color = Color.Resolved(components: Array(values.prefix(4)))
        if values.count > 4 {
            behavior.shape = (AnimatableViews.view(shape, with: Array(values.dropFirst(4))) as? S) ?? shape
        }
        return behavior
    }

    private static func shapeData(_ shape: S) -> [Double]? {
        AnimatableViews.components(of: shape)
    }

    func displayContent(node: ViewNode) -> DisplayList.Content? {
        let bounds = CGRect(origin: CGPoint(x: 0, y: 0), size: node.graph.presentationFrame(of: node).size)
        // A filled rounded rectangle or capsule in a color is drawn on the
        // GPU, without rasterizing it.
        if case .fill = drawing, gradient == nil, let radius = circularCornerRadius(of: shape, in: bounds) {
            return .roundedRectangle(RoundedRectangleContent(color: color, cornerRadius: radius))
        }
        return .shape(ShapeContent(
            path: shape.path(in: bounds),
            color: color,
            drawing: drawing,
            gradient: gradient?.paint(in: bounds)
        ))
    }

    func hitTest(_ point: CGPoint, node: ViewNode) -> Bool {
        let local = CGPoint(x: point.x - node.frame.minX, y: point.y - node.frame.minY)
        let path = shape.path(in: CGRect(origin: CGPoint(x: 0, y: 0), size: node.frame.size))
        switch drawing {
        case let .fill(style):
            return path.contains(local, eoFill: style.isEOFilled)
        case let .stroke(style):
            return path.strokeContains(local, lineWidth: style.lineWidth)
        }
    }
}

// MARK: - Built-in shapes

/// A rectangular shape aligned inside the frame of the view containing it.
public struct Rectangle: InsettableShape {

    internal var insetAmount: CGFloat = 0

    public init() { }

    public nonisolated func path(in rect: CGRect) -> Path {
        Path(rect.insetBy(dx: insetAmount, dy: insetAmount))
    }

    public nonisolated func inset(by amount: CGFloat) -> Rectangle {
        var shape = self
        shape.insetAmount += amount
        return shape
    }
}

/// A rectangular shape with rounded corners, aligned inside the frame of the
/// view containing it.
public struct RoundedRectangle: InsettableShape {

    public var cornerSize: CGSize

    public var style: RoundedCornerStyle

    internal var insetAmount: CGFloat = 0

    public init(cornerSize: CGSize, style: RoundedCornerStyle = .continuous) {
        self.cornerSize = cornerSize
        self.style = style
    }

    public init(cornerRadius: CGFloat, style: RoundedCornerStyle = .continuous) {
        self.init(cornerSize: CGSize(width: cornerRadius, height: cornerRadius), style: style)
    }

    public nonisolated func path(in rect: CGRect) -> Path {
        Path(
            roundedRect: rect.insetBy(dx: insetAmount, dy: insetAmount),
            cornerSize: CGSize(
                width: max(cornerSize.width - insetAmount, 0),
                height: max(cornerSize.height - insetAmount, 0)
            ),
            style: style
        )
    }

    public nonisolated func inset(by amount: CGFloat) -> RoundedRectangle {
        var shape = self
        shape.insetAmount += amount
        return shape
    }
}

/// Describes the corner radius values of a rounded rectangle with uneven
/// corners.
public struct RectangleCornerRadii: Equatable, Animatable, Sendable {

    public var topLeading: CGFloat

    public var bottomLeading: CGFloat

    public var bottomTrailing: CGFloat

    public var topTrailing: CGFloat

    public init(topLeading: CGFloat = 0, bottomLeading: CGFloat = 0, bottomTrailing: CGFloat = 0, topTrailing: CGFloat = 0) {
        self.topLeading = topLeading
        self.bottomLeading = bottomLeading
        self.bottomTrailing = bottomTrailing
        self.topTrailing = topTrailing
    }

    public var animatableData: AnimatablePair<AnimatablePair<CGFloat, CGFloat>, AnimatablePair<CGFloat, CGFloat>> {
        get { AnimatablePair(AnimatablePair(topLeading, bottomLeading), AnimatablePair(bottomTrailing, topTrailing)) }
        set {
            topLeading = newValue.first.first
            bottomLeading = newValue.first.second
            bottomTrailing = newValue.second.first
            topTrailing = newValue.second.second
        }
    }
}

/// A rectangular shape with rounded corners with different values, aligned
/// inside the frame of the view containing it.
public struct UnevenRoundedRectangle: InsettableShape {

    public var cornerRadii: RectangleCornerRadii

    public var style: RoundedCornerStyle

    internal var insetAmount: CGFloat = 0

    public init(cornerRadii: RectangleCornerRadii, style: RoundedCornerStyle = .continuous) {
        self.cornerRadii = cornerRadii
        self.style = style
    }

    public init(
        topLeadingRadius: CGFloat = 0,
        bottomLeadingRadius: CGFloat = 0,
        bottomTrailingRadius: CGFloat = 0,
        topTrailingRadius: CGFloat = 0,
        style: RoundedCornerStyle = .continuous
    ) {
        self.init(
            cornerRadii: RectangleCornerRadii(
                topLeading: topLeadingRadius,
                bottomLeading: bottomLeadingRadius,
                bottomTrailing: bottomTrailingRadius,
                topTrailing: topTrailingRadius
            ),
            style: style
        )
    }

    public nonisolated var animatableData: RectangleCornerRadii.AnimatableData {
        get { cornerRadii.animatableData }
        set { cornerRadii.animatableData = newValue }
    }

    public nonisolated func path(in rect: CGRect) -> Path {
        let rect = rect.insetBy(dx: insetAmount, dy: insetAmount)
        let limit = min(rect.width, rect.height) / 2
        func radius(_ value: CGFloat) -> CGFloat { min(max(value - insetAmount, 0), limit) }
        let topLeading = radius(cornerRadii.topLeading), topTrailing = radius(cornerRadii.topTrailing)
        let bottomLeading = radius(cornerRadii.bottomLeading), bottomTrailing = radius(cornerRadii.bottomTrailing)
        // Quarter circles as cubic curves.
        let k: CGFloat = 0.5523
        return Path { path in
            path.move(to: CGPoint(x: rect.minX + topLeading, y: rect.minY))
            path.addLine(to: CGPoint(x: rect.maxX - topTrailing, y: rect.minY))
            path.addCurve(
                to: CGPoint(x: rect.maxX, y: rect.minY + topTrailing),
                control1: CGPoint(x: rect.maxX - topTrailing * (1 - k), y: rect.minY),
                control2: CGPoint(x: rect.maxX, y: rect.minY + topTrailing * (1 - k))
            )
            path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY - bottomTrailing))
            path.addCurve(
                to: CGPoint(x: rect.maxX - bottomTrailing, y: rect.maxY),
                control1: CGPoint(x: rect.maxX, y: rect.maxY - bottomTrailing * (1 - k)),
                control2: CGPoint(x: rect.maxX - bottomTrailing * (1 - k), y: rect.maxY)
            )
            path.addLine(to: CGPoint(x: rect.minX + bottomLeading, y: rect.maxY))
            path.addCurve(
                to: CGPoint(x: rect.minX, y: rect.maxY - bottomLeading),
                control1: CGPoint(x: rect.minX + bottomLeading * (1 - k), y: rect.maxY),
                control2: CGPoint(x: rect.minX, y: rect.maxY - bottomLeading * (1 - k))
            )
            path.addLine(to: CGPoint(x: rect.minX, y: rect.minY + topLeading))
            path.addCurve(
                to: CGPoint(x: rect.minX + topLeading, y: rect.minY),
                control1: CGPoint(x: rect.minX, y: rect.minY + topLeading * (1 - k)),
                control2: CGPoint(x: rect.minX + topLeading * (1 - k), y: rect.minY)
            )
            path.closeSubpath()
        }
    }

    public nonisolated func inset(by amount: CGFloat) -> UnevenRoundedRectangle {
        var shape = self
        shape.insetAmount += amount
        return shape
    }
}

/// A capsule shape aligned inside the frame of the view containing it.
public struct Capsule: InsettableShape {

    public var style: RoundedCornerStyle

    internal var insetAmount: CGFloat = 0

    public init(style: RoundedCornerStyle = .continuous) {
        self.style = style
    }

    public nonisolated func path(in rect: CGRect) -> Path {
        let rect = rect.insetBy(dx: insetAmount, dy: insetAmount)
        let radius = min(rect.width, rect.height) / 2
        return Path(roundedRect: rect, cornerRadius: radius, style: style)
    }

    public nonisolated func inset(by amount: CGFloat) -> Capsule {
        var shape = self
        shape.insetAmount += amount
        return shape
    }
}

/// An ellipse aligned inside the frame of the view containing it.
public struct Ellipse: InsettableShape {

    internal var insetAmount: CGFloat = 0

    public init() { }

    public nonisolated func path(in rect: CGRect) -> Path {
        Path(ellipseIn: rect.insetBy(dx: insetAmount, dy: insetAmount))
    }

    public nonisolated func inset(by amount: CGFloat) -> Ellipse {
        var shape = self
        shape.insetAmount += amount
        return shape
    }
}

/// A circle centered on the frame of the view containing it.
public struct Circle: InsettableShape {

    internal var insetAmount: CGFloat = 0

    public init() { }

    public nonisolated func path(in rect: CGRect) -> Path {
        let side = min(rect.width, rect.height)
        let square = CGRect(x: rect.midX - side / 2, y: rect.midY - side / 2, width: side, height: side)
        return Path(ellipseIn: square.insetBy(dx: insetAmount, dy: insetAmount))
    }

    public nonisolated func inset(by amount: CGFloat) -> Circle {
        var shape = self
        shape.insetAmount += amount
        return shape
    }
}

// MARK: - Path as a shape

extension Path: Shape {

    public nonisolated func path(in rect: CGRect) -> Path {
        self
    }
}
