//
//  Transform2D.swift
//  CacaoRender
//
//  Created by Alsey Coleman Miller on 11/13/26.
//

import Foundation
#if canImport(CoreGraphics)
import CoreGraphics
#endif

/// An affine transform of the plane, for transform effects.
public struct Transform2D: Equatable, Sendable {

    public var a: CGFloat = 1
    public var b: CGFloat = 0
    public var c: CGFloat = 0
    public var d: CGFloat = 1
    public var tx: CGFloat = 0
    public var ty: CGFloat = 0

    public static let identity = Transform2D()

    public init() { }

    public init(a: CGFloat, b: CGFloat, c: CGFloat, d: CGFloat, tx: CGFloat, ty: CGFloat) {
        (self.a, self.b, self.c, self.d, self.tx, self.ty) = (a, b, c, d, tx, ty)
    }

    public static func translation(_ x: CGFloat, _ y: CGFloat) -> Transform2D {
        Transform2D(a: 1, b: 0, c: 0, d: 1, tx: x, ty: y)
    }

    public static func scale(_ x: CGFloat, _ y: CGFloat) -> Transform2D {
        Transform2D(a: x, b: 0, c: 0, d: y, tx: 0, ty: 0)
    }

    public static func rotation(_ radians: CGFloat) -> Transform2D {
        let cosine = CGFloat(cos(Double(radians)))
        let sine = CGFloat(sin(Double(radians)))
        return Transform2D(a: cosine, b: sine, c: -sine, d: cosine, tx: 0, ty: 0)
    }

    /// This transform followed by another.
    public func concatenating(_ t: Transform2D) -> Transform2D {
        Transform2D(
            a: a * t.a + b * t.c,
            b: a * t.b + b * t.d,
            c: c * t.a + d * t.c,
            d: c * t.b + d * t.d,
            tx: tx * t.a + ty * t.c + t.tx,
            ty: tx * t.b + ty * t.d + t.ty
        )
    }

    /// The transform about a point: move it to the origin, transform, move back.
    public func about(_ point: CGPoint) -> Transform2D {
        Transform2D.translation(-point.x, -point.y)
            .concatenating(self)
            .concatenating(.translation(point.x, point.y))
    }

    public func apply(_ point: CGPoint) -> CGPoint {
        CGPoint(x: a * point.x + c * point.y + tx, y: b * point.x + d * point.y + ty)
    }

    /// Whether the transform only moves.
    public var isTranslation: Bool {
        a == 1 && b == 0 && c == 0 && d == 1
    }

    /// The transform that undoes this one, if it can be undone.
    public func inverted() -> Transform2D? {
        let determinant = a * d - b * c
        guard determinant != 0 else { return nil }
        return Transform2D(
            a: d / determinant,
            b: -b / determinant,
            c: -c / determinant,
            d: a / determinant,
            tx: (c * ty - d * tx) / determinant,
            ty: (b * tx - a * ty) / determinant
        )
    }

    /// The bounding rectangle of a rectangle's transformed corners.
    public func boundingRect(of rect: CGRect) -> CGRect {
        guard !rect.isNull else { return rect }
        let corners = [
            apply(CGPoint(x: rect.minX, y: rect.minY)), apply(CGPoint(x: rect.maxX, y: rect.minY)),
            apply(CGPoint(x: rect.minX, y: rect.maxY)), apply(CGPoint(x: rect.maxX, y: rect.maxY)),
        ]
        let xs = corners.map(\.x), ys = corners.map(\.y)
        return CGRect(x: xs.min()!, y: ys.min()!, width: xs.max()! - xs.min()!, height: ys.max()! - ys.min()!)
    }
}
