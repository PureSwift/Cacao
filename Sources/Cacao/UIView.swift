//
//  UIView.swift
//  Cacao
//
//  Created by Alsey Coleman Miller on 5/27/16.
//  Copyright © 2016 PureSwift. All rights reserved.
//

import Silica

open class UIView {
    
    // MARK: - Initializing a View Object
    
    public init(frame: CGRect) {
        
        self.frame = frame
    }
    
    // MARK: - Properties
    
    public final var frame: CGRect
    
    public final var bounds: CGRect
    
    public final var backgroundColor: UIColor = UIColor(cgColor: Color.white)
    
    public final var alpha: Double = 1.0
    
    public final var hidden: Bool = false
    
    public final fileprivate(set) var subviews: [View] = []
    
    public final var tag: Int = 0
    
    // MARK: - Initialization
    
    public init(frame: Rect = Rect()) {
        
        self.frame = frame
    }
    
    // MARK: - Subclassable Methods
    
    open func draw(_ rect: CGRect) { /* implemented by subclasses */ }
    
    // MARK: - Final Methods
    
    public final func addSubview(_ view: View) {
        
        subviews.append(view)
    }
        
    internal final func draw(to context: Context) {
        
        guard hidden == false && alpha > 0
            else { return }
        
        UIGraphicsPushContext(CGContext(context))
        
        // draw background color
        context.fillColor = backgroundColor.CGColor
        context.add(rect: bounds)
        try! context.fill()
        
        // draw rect
        draw(bounds)
        
        UIGraphicsPopContext()
    }
    
    public final func handle(event: PointerEvent) {
        
        // translate to UIKit APIs
    }
    
    /// Returns the farthest descendant of the receiver in the view hierarchy (including itself) that contains a specified point.
    ///
    /// - Note: This method ignores view objects that are hidden or have user interaction disabled.
    /// This method does not take the view’s content into account when determining a hit.
    /// Thus, a view can still be returned even if the specified point is in a transparent portion of that view’s content.
    public final func hitTest(point: CGPoint) -> View? {
        
        guard hidden == false
            && userInteractionEnabled
            && pointInside(point)
            else { return nil }
        
        // convert point for subviews
        let subviewPoint = Point(x: point.x - frame.x, y: point.y - frame.y)
        
        for subview in subviews {
            
            guard let descendant = subview.hitTest(point: subviewPoint) else { return nil }
            
            return descendant
        }
        
        return self
    }
    
    public func setNeedsDisplay(_ rect: )
}
