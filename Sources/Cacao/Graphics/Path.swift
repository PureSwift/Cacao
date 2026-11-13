//
//  Path.swift
//  Cacao
//
//  Created by Alsey Coleman Miller on 11/13/26.
//

import Foundation
#if canImport(CoreGraphics)
import CoreGraphics
#endif

/// The outline of a 2D shape.
public struct Path: Equatable, Sendable {

    /// An element of a path.
    public enum Element: Equatable, Sendable {

        /// A path element that terminates the current subpath (without closing
        /// it) and defines a new current point.
        case move(to: CGPoint)

        /// A line from the previous current point to the given point.
        case line(to: CGPoint)

        /// A quadratic Bézier curve from the previous current point to the
        /// given end-point, using the single control point.
        case quadCurve(to: CGPoint, control: CGPoint)

        /// A cubic Bézier curve from the previous current point to the given
        /// end-point, using the two control points.
        case curve(to: CGPoint, control1: CGPoint, control2: CGPoint)

        /// A line from the start point of the current subpath to its end.
        case closeSubpath
    }

    internal private(set) var elements: [Element]

    /// Creates an empty path.
    public init() {
        self.elements = []
    }

    /// Creates a path containing a rectangle.
    public init(_ rect: CGRect) {
        self.init()
        addRect(rect)
    }

    /// Creates a path containing a rounded rectangle.
    public init(roundedRect rect: CGRect, cornerRadius: CGFloat, style: RoundedCornerStyle = .continuous) {
        self.init()
        addRoundedRect(in: rect, cornerSize: CGSize(width: cornerRadius, height: cornerRadius), style: style)
    }

    /// Creates a path containing a rounded rectangle.
    public init(roundedRect rect: CGRect, cornerSize: CGSize, style: RoundedCornerStyle = .continuous) {
        self.init()
        addRoundedRect(in: rect, cornerSize: cornerSize, style: style)
    }

    /// Creates a path as an ellipse within the given rectangle.
    public init(ellipseIn rect: CGRect) {
        self.init()
        addEllipse(in: rect)
    }

    /// Creates an empty path, then executes a closure to add its initial elements.
    public init(_ callback: (inout Path) -> Void) {
        self.init()
        callback(&self)
    }

    /// A Boolean value indicating whether the path contains zero elements.
    public var isEmpty: Bool {
        elements.isEmpty
    }

    /// Calls `body` with each element in the path.
    public func forEach(_ body: (Element) -> Void) {
        elements.forEach(body)
    }

    // MARK: Building

    /// Begins a new subpath at the specified point.
    public mutating func move(to end: CGPoint) {
        elements.append(.move(to: end))
    }

    /// Appends a straight line segment from the current point to the specified point.
    public mutating func addLine(to end: CGPoint) {
        elements.append(.line(to: end))
    }

    /// Adds a quadratic Bézier curve to the path, with the specified end
    /// point and control point.
    public mutating func addQuadCurve(to end: CGPoint, control: CGPoint) {
        elements.append(.quadCurve(to: end, control: control))
    }

    /// Adds a cubic Bézier curve to the path, with the specified end point
    /// and control points.
    public mutating func addCurve(to end: CGPoint, control1: CGPoint, control2: CGPoint) {
        elements.append(.curve(to: end, control1: control1, control2: control2))
    }

    /// Closes and completes the current subpath.
    public mutating func closeSubpath() {
        elements.append(.closeSubpath)
    }

    /// Adds a rectangular subpath to the path.
    public mutating func addRect(_ rect: CGRect) {
        move(to: CGPoint(x: rect.minX, y: rect.minY))
        addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        closeSubpath()
    }

    /// Adds a set of rectangular subpaths to the path.
    public mutating func addRects(_ rects: [CGRect]) {
        rects.forEach { addRect($0) }
    }

    /// Adds a sequence of connected straight-line segments to the path.
    public mutating func addLines(_ lines: [CGPoint]) {
        guard let first = lines.first else { return }
        move(to: first)
        lines.dropFirst().forEach { addLine(to: $0) }
    }

    /// The factor that places cubic Bézier control points to approximate a
    /// quarter circle.
    private static let kappa: CGFloat = 0.5522847498

    /// Adds an ellipse that fits inside the specified rectangle.
    public mutating func addEllipse(in rect: CGRect) {
        let rx = rect.width / 2
        let ry = rect.height / 2
        let cx = rect.midX
        let cy = rect.midY
        let ox = rx * Self.kappa
        let oy = ry * Self.kappa
        move(to: CGPoint(x: cx + rx, y: cy))
        addCurve(to: CGPoint(x: cx, y: cy + ry), control1: CGPoint(x: cx + rx, y: cy + oy), control2: CGPoint(x: cx + ox, y: cy + ry))
        addCurve(to: CGPoint(x: cx - rx, y: cy), control1: CGPoint(x: cx - ox, y: cy + ry), control2: CGPoint(x: cx - rx, y: cy + oy))
        addCurve(to: CGPoint(x: cx, y: cy - ry), control1: CGPoint(x: cx - rx, y: cy - oy), control2: CGPoint(x: cx - ox, y: cy - ry))
        addCurve(to: CGPoint(x: cx + rx, y: cy), control1: CGPoint(x: cx + ox, y: cy - ry), control2: CGPoint(x: cx + rx, y: cy - oy))
        closeSubpath()
    }

    /// Adds a rounded rectangle to the path.
    public mutating func addRoundedRect(in rect: CGRect, cornerSize: CGSize, style: RoundedCornerStyle = .continuous) {
        let rx = min(max(cornerSize.width, 0), rect.width / 2)
        let ry = min(max(cornerSize.height, 0), rect.height / 2)
        guard rx > 0, ry > 0 else {
            addRect(rect)
            return
        }
        let ox = rx * Self.kappa
        let oy = ry * Self.kappa
        move(to: CGPoint(x: rect.minX + rx, y: rect.minY))
        addLine(to: CGPoint(x: rect.maxX - rx, y: rect.minY))
        addCurve(
            to: CGPoint(x: rect.maxX, y: rect.minY + ry),
            control1: CGPoint(x: rect.maxX - rx + ox, y: rect.minY),
            control2: CGPoint(x: rect.maxX, y: rect.minY + ry - oy)
        )
        addLine(to: CGPoint(x: rect.maxX, y: rect.maxY - ry))
        addCurve(
            to: CGPoint(x: rect.maxX - rx, y: rect.maxY),
            control1: CGPoint(x: rect.maxX, y: rect.maxY - ry + oy),
            control2: CGPoint(x: rect.maxX - rx + ox, y: rect.maxY)
        )
        addLine(to: CGPoint(x: rect.minX + rx, y: rect.maxY))
        addCurve(
            to: CGPoint(x: rect.minX, y: rect.maxY - ry),
            control1: CGPoint(x: rect.minX + rx - ox, y: rect.maxY),
            control2: CGPoint(x: rect.minX, y: rect.maxY - ry + oy)
        )
        addLine(to: CGPoint(x: rect.minX, y: rect.minY + ry))
        addCurve(
            to: CGPoint(x: rect.minX + rx, y: rect.minY),
            control1: CGPoint(x: rect.minX, y: rect.minY + ry - oy),
            control2: CGPoint(x: rect.minX + rx - ox, y: rect.minY)
        )
        closeSubpath()
    }

    /// Appends another path value to this path.
    public mutating func addPath(_ path: Path) {
        elements.append(contentsOf: path.elements)
    }

    // MARK: Geometry

    /// Returns a path constructed by translating all its points.
    public func offsetBy(dx: CGFloat, dy: CGFloat) -> Path {
        func move(_ point: CGPoint) -> CGPoint {
            CGPoint(x: point.x + dx, y: point.y + dy)
        }
        var path = Path()
        path.elements = elements.map { element in
            switch element {
            case let .move(to): .move(to: move(to))
            case let .line(to): .line(to: move(to))
            case let .quadCurve(to, control): .quadCurve(to: move(to), control: move(control))
            case let .curve(to, control1, control2): .curve(to: move(to), control1: move(control1), control2: move(control2))
            case .closeSubpath: .closeSubpath
            }
        }
        return path
    }

    /// A rectangle containing all path segments, including control points.
    public var boundingRect: CGRect {
        var points: [CGPoint] = []
        for element in elements {
            switch element {
            case let .move(to), let .line(to):
                points.append(to)
            case let .quadCurve(to, control):
                points.append(contentsOf: [to, control])
            case let .curve(to, control1, control2):
                points.append(contentsOf: [to, control1, control2])
            case .closeSubpath:
                break
            }
        }
        guard let first = points.first else {
            return .null
        }
        var minX = first.x, maxX = first.x, minY = first.y, maxY = first.y
        for point in points.dropFirst() {
            minX = min(minX, point.x)
            maxX = max(maxX, point.x)
            minY = min(minY, point.y)
            maxY = max(maxY, point.y)
        }
        return CGRect(x: minX, y: minY, width: maxX - minX, height: maxY - minY)
    }

    /// Returns true if the path contains a specified point, with the
    /// non-zero winding rule or, if `eoFill`, the even-odd rule.
    public func contains(_ point: CGPoint, eoFill: Bool = false) -> Bool {
        var winding = 0
        for polygon in polygons() where polygon.count > 2 {
            for index in polygon.indices {
                let a = polygon[index]
                let b = polygon[(index + 1) % polygon.count]
                if a.y <= point.y {
                    if b.y > point.y, cross(a, b, point) > 0 {
                        winding += 1
                    }
                } else if b.y <= point.y, cross(a, b, point) < 0 {
                    winding -= 1
                }
            }
        }
        return eoFill ? winding % 2 != 0 : winding != 0
    }

    /// Whether a point is on the path's outline, stroked with a line width
    /// (and a point of tolerance).
    internal func strokeContains(_ point: CGPoint, lineWidth: CGFloat) -> Bool {
        let reach = lineWidth / 2 + 1
        for polygon in polygons() where !polygon.isEmpty {
            for index in polygon.indices {
                let a = polygon[index]
                let b = polygon[(index + 1) % polygon.count]
                let dx = b.x - a.x, dy = b.y - a.y
                let lengthSquared = dx * dx + dy * dy
                let t = lengthSquared > 0 ? min(max(((point.x - a.x) * dx + (point.y - a.y) * dy) / lengthSquared, 0), 1) : 0
                let px = a.x + t * dx - point.x, py = a.y + t * dy - point.y
                if px * px + py * py <= reach * reach {
                    return true
                }
            }
        }
        return false
    }

    private func cross(_ a: CGPoint, _ b: CGPoint, _ p: CGPoint) -> CGFloat {
        (b.x - a.x) * (p.y - a.y) - (p.x - a.x) * (b.y - a.y)
    }

    /// The subpaths flattened into polygons, approximating curves.
    private func polygons(segments: Int = 12) -> [[CGPoint]] {
        var polygons: [[CGPoint]] = []
        var current: [CGPoint] = []
        var last = CGPoint(x: 0, y: 0)
        for element in elements {
            switch element {
            case let .move(to):
                if !current.isEmpty { polygons.append(current) }
                current = [to]
                last = to
            case let .line(to):
                current.append(to)
                last = to
            case let .quadCurve(to, control):
                for step in 1...segments {
                    let t = CGFloat(step) / CGFloat(segments)
                    let u = 1 - t
                    current.append(CGPoint(
                        x: u * u * last.x + 2 * u * t * control.x + t * t * to.x,
                        y: u * u * last.y + 2 * u * t * control.y + t * t * to.y
                    ))
                }
                last = to
            case let .curve(to, c1, c2):
                for step in 1...segments {
                    let t = CGFloat(step) / CGFloat(segments)
                    let u = 1 - t
                    let a = u * u * u, b = 3 * u * u * t, c = 3 * u * t * t, d = t * t * t
                    current.append(CGPoint(
                        x: a * last.x + b * c1.x + c * c2.x + d * to.x,
                        y: a * last.y + b * c1.y + c * c2.y + d * to.y
                    ))
                }
                last = to
            case .closeSubpath:
                if !current.isEmpty {
                    polygons.append(current)
                    last = current[0]
                    current = []
                }
            }
        }
        if !current.isEmpty { polygons.append(current) }
        return polygons
    }
}

/// Defines the shape of a rounded rectangle's corners.
public enum RoundedCornerStyle: Hashable, Sendable {

    /// Quarter-circle rounded rect corners.
    case circular

    /// Continuous curvature rounded rect corners.
    case continuous
}
