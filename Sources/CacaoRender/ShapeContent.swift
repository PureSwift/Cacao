//
//  ShapeContent.swift
//  CacaoRender
//
//  Created by Alsey Coleman Miller on 11/13/26.
//

import Foundation
#if canImport(CoreGraphics)
import CoreGraphics
#endif

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

/// Whether a shape is filled or stroked.
public enum ShapeDrawing: Equatable, Sendable {
    case fill(FillStyle)
    case stroke(StrokeStyle)
}

/// A shape's path, paint and drawing, in its frame's coordinate space.
public struct ShapeContent: Equatable, Sendable {

    public var path: Path

    public var color: ResolvedColor

    public var drawing: ShapeDrawing

    /// A gradient drawn instead of the color.
    public var gradient: GradientPaint?

    public init(path: Path, color: ResolvedColor, drawing: ShapeDrawing, gradient: GradientPaint? = nil) {
        self.path = path
        self.color = color
        self.drawing = drawing
        self.gradient = gradient
    }
}
