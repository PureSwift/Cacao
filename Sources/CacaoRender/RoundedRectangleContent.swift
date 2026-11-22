//
//  RoundedRectangleContent.swift
//  CacaoRender
//
//  Created by Alsey Coleman Miller on 11/22/26.
//

import Foundation
#if canImport(CoreGraphics)
import CoreGraphics
#endif

/// A rectangle filled with a color, with circular corners: a card's or a
/// grouped cell's background. A compositor draws it on the GPU, without
/// rasterizing a bitmap the size of the rectangle, as it does a shape.
public struct RoundedRectangleContent: Equatable, Sendable {

    /// The corners of a rectangle.
    public typealias Corners = BackdropContent.Corners

    public var color: ResolvedColor

    /// The corners' radius, in points, at most half the shorter side.
    public var cornerRadius: CGFloat

    /// The corners that are rounded; the others are square.
    public var corners: Corners

    public init(color: ResolvedColor, cornerRadius: CGFloat, corners: Corners = .all) {
        self.color = color
        self.cornerRadius = cornerRadius
        self.corners = corners
    }

    /// The outline in `rect`, its rounded corners circular arcs (cubic
    /// curves), for drawing it in software.
    public func path(in rect: CGRect) -> Path {
        let radius = max(0, min(cornerRadius, rect.width / 2, rect.height / 2))
        // A cubic curve's control points for a quarter circle, as a
        // fraction of its radius.
        let k: CGFloat = 0.5522847498 * radius
        func r(_ corner: Corners) -> CGFloat { corners.contains(corner) ? radius : 0 }
        func c(_ corner: Corners) -> CGFloat { corners.contains(corner) ? k : 0 }
        let (minX, minY, maxX, maxY) = (rect.minX, rect.minY, rect.maxX, rect.maxY)
        var path = Path()
        path.move(to: CGPoint(x: minX + r(.topLeading), y: minY))
        path.addLine(to: CGPoint(x: maxX - r(.topTrailing), y: minY))
        path.addCurve(
            to: CGPoint(x: maxX, y: minY + r(.topTrailing)),
            control1: CGPoint(x: maxX - r(.topTrailing) + c(.topTrailing), y: minY),
            control2: CGPoint(x: maxX, y: minY + r(.topTrailing) - c(.topTrailing))
        )
        path.addLine(to: CGPoint(x: maxX, y: maxY - r(.bottomTrailing)))
        path.addCurve(
            to: CGPoint(x: maxX - r(.bottomTrailing), y: maxY),
            control1: CGPoint(x: maxX, y: maxY - r(.bottomTrailing) + c(.bottomTrailing)),
            control2: CGPoint(x: maxX - r(.bottomTrailing) + c(.bottomTrailing), y: maxY)
        )
        path.addLine(to: CGPoint(x: minX + r(.bottomLeading), y: maxY))
        path.addCurve(
            to: CGPoint(x: minX, y: maxY - r(.bottomLeading)),
            control1: CGPoint(x: minX + r(.bottomLeading) - c(.bottomLeading), y: maxY),
            control2: CGPoint(x: minX, y: maxY - r(.bottomLeading) + c(.bottomLeading))
        )
        path.addLine(to: CGPoint(x: minX, y: minY + r(.topLeading)))
        path.addCurve(
            to: CGPoint(x: minX + r(.topLeading), y: minY),
            control1: CGPoint(x: minX, y: minY + r(.topLeading) - c(.topLeading)),
            control2: CGPoint(x: minX + r(.topLeading) - c(.topLeading), y: minY)
        )
        path.closeSubpath()
        return path
    }
}
