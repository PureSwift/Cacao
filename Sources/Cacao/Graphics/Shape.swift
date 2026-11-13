//
//  Shape.swift
//  Cacao
//
//  Created by Alsey Coleman Miller on 11/13/26.
//

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

// MARK: - Styles

/// A style for rasterizing vector shapes.
public struct FillStyle: Equatable, Sendable {

    /// A Boolean value that indicates whether to use the even-odd rule.
    public var isEOFilled: Bool

    /// A Boolean value that indicates whether to apply antialiasing.
    public var isAntialiased: Bool

    public init(eoFill: Bool = false, antialiased: Bool = true) {
        self.isEOFilled = eoFill
        self.isAntialiased = antialiased
    }
}

#if !canImport(CoreGraphics)

/// Styles of rendering the endpoint of a stroked line.
public enum CGLineCap: Int32, Sendable {
    case butt
    case round
    case square
}

/// Junction types for stroked lines.
public enum CGLineJoin: Int32, Sendable {
    case miter
    case round
    case bevel
}

#endif

/// The characteristics of a stroke that traces a path.
public struct StrokeStyle: Equatable, Sendable {

    /// The width of the stroked path.
    public var lineWidth: CGFloat

    /// The endpoint style of a line.
    public var lineCap: CGLineCap

    /// The join type of a line.
    public var lineJoin: CGLineJoin

    /// A threshold used to determine whether to use a bevel instead of a
    /// miter at a join.
    public var miterLimit: CGFloat

    /// The lengths of painted and unpainted segments used to make a dashed line.
    public var dash: [CGFloat]

    /// How far into the dash pattern the line starts.
    public var dashPhase: CGFloat

    public init(
        lineWidth: CGFloat = 1,
        lineCap: CGLineCap = .butt,
        lineJoin: CGLineJoin = .miter,
        miterLimit: CGFloat = 10,
        dash: [CGFloat] = [CGFloat](),
        dashPhase: CGFloat = 0
    ) {
        self.lineWidth = lineWidth
        self.lineCap = lineCap
        self.lineJoin = lineJoin
        self.miterLimit = miterLimit
        self.dash = dash
        self.dashPhase = dashPhase
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
        Resolution(behavior: ShapeBehavior(
            shape: shape,
            color: AnyShapeStyle(style).resolveColor(in: context.environment),
            drawing: drawing
        ))
    }
}

/// Whether a shape is filled or stroked.
package enum ShapeDrawing: Equatable, Sendable {
    case fill(FillStyle)
    case stroke(StrokeStyle)
}

/// A shape's path, paint and drawing, in its frame's coordinate space.
package struct ShapeContent: Equatable, Sendable {

    package var path: Path

    package var color: Color.Resolved

    package var drawing: ShapeDrawing
}

internal struct ShapeBehavior<S: Shape>: NodeBehavior {

    let shape: S

    let color: Color.Resolved

    let drawing: ShapeDrawing

    func sizeThatFits(_ proposal: ProposedViewSize, node: ViewNode) -> CGSize {
        shape.sizeThatFits(proposal)
    }

    func displayContent(node: ViewNode) -> DisplayList.Content? {
        .shape(ShapeContent(
            path: shape.path(in: CGRect(origin: CGPoint(x: 0, y: 0), size: node.frame.size)),
            color: color,
            drawing: drawing
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
