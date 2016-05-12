//
//  UIBezierPath.swift
//  Cacao
//
//  Created by Alsey Coleman Miller on 5/12/16.
//  Copyright © 2016 PureSwift. All rights reserved.
//

import SwiftCoreGraphics
import Silica
import Cacao

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
    
    public var CGPath: SwiftCoreGraphics.CGPath
    
    public var lineWidth: SwiftCoreGraphics.CGFloat = 1.0
    
    public var lineCapStyle: SwiftCoreGraphics.CGLineCap = .Butt
    
    public var lineJoinStyle: SwiftCoreGraphics.CGLineJoin = .Miter
    
    public var miterLimit: SwiftCoreGraphics.CGFloat = 10
    
    public var flatness: SwiftCoreGraphics.CGFloat = 0.6
    
    public var usesEvenOddFillRule: Bool = false
    
    public var lineDash: (phase: Double, lengths: [Double]) = (0.0, [])
    
    // MARK: - Initialization
    
    public init(CGPath path: SwiftCoreGraphics.CGPath) {
        
        self.CGPath = path
    }
    
    public init(rect: SwiftCoreGraphics.CGRect) {
        
        var path = Path()
        
        path.add(rect: rect)
        
        self.CGPath = path
    }
    
    public init(ovalInRect rect: SwiftCoreGraphics.CGRect) {
        
        var path = Path()
        
        path.add(ellipseInRect: rect)
        
        self.CGPath = path
    }
    
    // MARK: - Accessors
    
    public var currentPoint: SwiftCoreGraphics.CGPoint {
        
        fatalError("Not implemented")
    }
    
    public var isEmpty: Bool {
        
        return CGPath.elements.isEmpty
    }
    
    public var bounds: SwiftCoreGraphics.CGRect {
        
        fatalError("Not implemented")
    }
    
    // MARK: - Methods
    
    // MARK: Drawing
    
    public func fill() {
        
        guard let context = UIGraphicsGetCurrentContext()
            else { return }
        
        try! context.save()
        
        setContextPath()
        
        try! context.fill(evenOdd: usesEvenOddFillRule)
        
        context.beginPath()
        try! context.restore()
    }
    
    // MARK: - Private Methods
    
    private func setContextPath() {
        
        guard let context = UIGraphicsGetCurrentContext()
            else { return }
        
        context.beginPath()
        context.add(path: CGPath)
        context.lineWidth = lineWidth
        context.lineCap = lineCapStyle
        context.lineJoin = lineJoinStyle
        context.miterLimit = miterLimit
        context.tolerance = flatness
        context.lineDash = lineDash
    }
}
