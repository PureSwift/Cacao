//
//  UIBezierPath.swift
//  Cacao
//
//  Created by Alsey Coleman Miller on 5/12/16.
//  Copyright © 2016 PureSwift. All rights reserved.
//

import Silica

/// The `UIBezierPath` class lets you define a path consisting of straight and curved line segments
/// and render that path in your custom views. You use this class initially to specify just the geometry for your path. 
/// Paths can define simple shapes such as rectangles, ovals, and arcs or they can define complex polygons that 
/// incorporate a mixture of straight and curved line segments. 
/// After defining the shape, you can use additional methods of this class to render the path in the current drawing context.
///
/// A `UIBezierPath` object combines the geometry of a path with attributes that describe the path during rendering.
/// You set the geometry and attributes separately and can change them independent of one another. 
/// Once you have the object configured the way you want it, you can tell it to draw itself in the current context. 
/// Because the creation, configuration, and rendering process are all distinct steps,
/// Bezier path objects can be reused easily in your code. 
/// You can even use the same object to render the same shape multiple times, 
/// perhaps changing the rendering options between successive drawing calls.
public final class UIBezierPath {
    
    // MARK: - Properties
    
    public var cgPath: Path
    
    public var lineWidth: Double = 1.0
    
    public var lineCapStyle: LineCap = .butt
    
    public var lineJoinStyle: LineJoin = .miter
    
    public var miterLimit: Double = 10
    
    public var flatness: Double = 0.6
    
    public var usesEvenOddFillRule: Bool = false
    
    public var lineDash: (phase: Double, lengths: [Double]) = (0.0, [])
    
    // MARK: - Initialization
    
    public init(cgPath path: CGPath = CGPath()) {
        
        self.cgPath = path
    }
    
    public init(rect: CGRect) {
        
        var path = CGPath()
        
        path.addRect(rect)
        
        self.cgPath = path
    }
    
    public init(ovalIn rect: CGRect) {
        
        var path = CGPath()
        
        path.addEllipse(in: rect)
        
        self.cgPath = path
    }
    
    public convenience init(roundedRect rect: CGRect, cornerRadius: CGFloat) {
        
        self.init(roundedRect: rect, byRoundingCorners: .allCorners, cornerRadii: CGSize(width: cornerRadius, height: cornerRadius))
    }
    
    public init(roundedRect rect: CGRect, byRoundingCorners corners: UIRectCorner, cornerRadii: CGSize) {
        
        var path = CGPath()
        
        let topLeft = rect.origin
        let topRight = CGPoint(x: rect.maxX, y: rect.maxY)
        let bottomRight = CGPoint(x: rect.maxX, y: rect.maxY)
        let bottomLeft = CGPoint(x: rect.maxX, y: rect.maxY)
        
        if corners.contains(.topLeft) {
            path.move(to: CGPoint(x: topLeft.x+cornerRadii.width, y:topLeft.y))
        } else {
            path.move(to: CGPoint(x: topLeft.x, y:topLeft.y))
        }
        if corners.contains(.topRight) {
            path.addLine(to: CGPoint(x: topRight.x-cornerRadii.width, y: topRight.y))
            path.addCurve(to: CGPoint(x: topRight.x, y: topRight.y),
                          control1: CGPoint(x: topRight.x, y: topRight.y+cornerRadii.height),
                          control2: CGPoint(x: topRight.x, y: topRight.y+cornerRadii.height))
        } else {
            path.addLine(to: CGPoint(x: topRight.x, y: topRight.y))
        }
        if corners.contains(.bottomRight) {
            path.addLine(to: CGPoint(x: bottomRight.x, y: bottomRight.y-cornerRadii.height))
            path.addCurve(to: CGPoint(x: bottomRight.x, y: bottomRight.y),
                          control1: CGPoint(x: bottomRight.x-cornerRadii.width, y: bottomRight.y),
                          control2: CGPoint(x: bottomRight.x-cornerRadii.width, y: bottomRight.y))
        } else {
            path.addLine(to: CGPoint(x: bottomRight.x, y: bottomRight.y))
        }
        if corners.contains(.bottomLeft) {
            path.addLine(to: CGPoint(x: bottomLeft.x+cornerRadii.width, y: bottomLeft.y))
            path.addCurve(to: CGPoint(x: bottomLeft.x, y: bottomLeft.y),
                          control1: CGPoint(x: bottomLeft.x, y: bottomLeft.y-cornerRadii.height),
                          control2: CGPoint(x:bottomLeft.x, y: bottomLeft.y-cornerRadii.height))
        } else {
            path.addLine(to: CGPoint(x: bottomLeft.x, y: bottomLeft.y))
        }
        if corners.contains(.topLeft) {
            path.addLine(to: CGPoint(x: topLeft.x, y: topLeft.y+cornerRadii.height))
            path.addCurve(to: CGPoint(x: topLeft.x, y: topLeft.y),
                          control1: CGPoint(x: topLeft.x+cornerRadii.width, y: topLeft.y),
                          control2: CGPoint(x: topLeft.x+cornerRadii.width, y: topLeft.y))
        } else {
            path.addLine(to: CGPoint(x: topLeft.x, y: topLeft.y))
        }
        
        path.closeSubpath()
        
        self.cgPath = path
    }
    
    
    
    // MARK: - Accessors
    
    public var currentPoint: Point {
        
        fatalError("Not implemented")
    }
    
    public var isEmpty: Bool {
        
        return cgPath.elements.isEmpty
    }
    
    public var bounds: Rect {
        
        fatalError("Not implemented")
    }
    
    // MARK: - Methods
    
    // MARK: Drawing
    
    public func fill() {
        
        guard let context = UIGraphicsGetCurrentContext()?.silicaContext
            else { return }
        
        try! context.save()
        
        setContextPath()
        
        try! context.fill(evenOdd: usesEvenOddFillRule)
        context.beginPath()
        try! context.restore()
    }
    
    // MARK: Clipping Paths
    
    public func addClip() {
        
        guard let context = UIGraphicsGetCurrentContext()?.silicaContext
            else { return }
        
        setContextPath()
        
        context.clip(evenOdd: usesEvenOddFillRule)
    }
    
    // MARK: - Constructing a Path
    
    public func move(to point: Point) {
        
        cgPath.elements.append(.moveToPoint(point))
    }
    
    public func addLine(to point: Point) {
        
        cgPath.elements.append(.addLineToPoint(point))
    }
    
    public func addCurve(to endPoint: Point, controlPoint1: Point, controlPoint2: Point) {
        
        cgPath.elements.append(.addCurveToPoint(controlPoint1, controlPoint2, endPoint))
    }
    
    public func addQuadCurve(to endPoint: Point, controlPoint: Point) {
        
        cgPath.elements.append(.addQuadCurveToPoint(controlPoint, endPoint))
    }
    
    public func close() {
        
        cgPath.elements.append(.closeSubpath)
    }
    
    public func addArc(with center: Point, radius: Double, startAngle: Double, endAngle: Double, clockwise: Bool) {
        
        fatalError("Not implemented")
    }
    
    // MARK: - Private Methods
    
    private func setContextPath() {
        
        guard let context = UIGraphicsGetCurrentContext()?.silicaContext
            else { return }
        
        context.beginPath()
        context.add(path: cgPath)
        context.lineWidth = lineWidth
        context.lineCap = lineCapStyle
        context.lineJoin = lineJoinStyle
        context.miterLimit = miterLimit
        context.tolerance = flatness
        context.lineDash = lineDash
    }
}
