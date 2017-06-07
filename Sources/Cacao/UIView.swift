//
//  UIView.swift
//  Cacao
//
//  Created by Alsey Coleman Miller on 5/27/16.
//  Copyright © 2016 PureSwift. All rights reserved.
//

import Silica
import SDL

open class UIView {
    
    // MARK: - Properties
    
    public final var frame: CGRect { didSet { frameChanged() } }
    
    public final var bounds: CGRect { didSet { frameChanged() } }
    
    public final var backgroundColor: UIColor = UIColor(cgColor: Color.white) { didSet { setNeedsDisplay() } }
    
    public final var alpha: Double = 1.0 { didSet { setNeedsDisplay() } }
    
    public final var isHidden: Bool = false { didSet { setNeedsDisplay() } }
    
    public final private(set) var subviews: [UIView] = []
    
    public final var tag: Int = 0
    
    /// The backing rendering node / texture.
    ///
    /// Cacao's equivalent of `UIView.layer` / `CALayer`.
    /// Instead of the CoreGraphics API you could draw directly to the texture's pixel data.
    public private(set) var texture: Texture!
    
    public final var window: UIWindow? {
        
        var superview: UIView
        
        
    }
    
    internal final var shouldDrawContent: Bool { return hidden == false && alpha > 0 }
    
    // MARK: - Initialization
    
    /// Draws the receiver’s image within the passed-in rectangle.
    public init(frame: CGRect) {
        
        self.frame = frame
    }
    
    // MARK: - Drawing
    
    open func draw(_ rect: CGRect) { /* implemented by subclasses */ }
    
    internal final func drawTexture() -> Texture {
        
        let shouldDrawContent = hidden == false && alpha > 0
        
        
    }
    
    internal func draw(in context: Silica.Context) {
        
        UIGraphicsPushContext(CGContext(context))
        
        // draw background color
        context.fillColor = backgroundColor.CGColor
        context.add(rect: bounds)
        try! context.fill()
        
        // draw rect
        draw(bounds)
        
        UIGraphicsPopContext()
    }
    
    // MARK: - Layout
    
    /// Asks the view to calculate and return the size that best fits the specified size.
    ///
    /// The default implementation of this method returns the existing size of the view. Subclasses can override this method to return a custom value based on the desired layout of any subviews. For example, a UISwitch object returns a fixed size value that represents the standard size of a switch view, and a UIImageView object returns the size of the image it is currently displaying.
    ///
    /// - Note: This method does not resize the receiver.
    open func sizeThatFits(_ size: CGSize) -> CGSize {
        
        return self.bounds.size
    }
    
    /// Lays out subviews.
    ///
    /// The default implementation of this method does nothing.
    ///
    /// Subclasses can override this method as needed to perform more precise layout of their subviews.
    /// You should override this method only if the autoresizing and constraint-based behaviors of
    /// the subviews do not offer the behavior you want.
    /// You can use your implementation to set the frame rectangles of your subviews directly.
    ///
    /// You should not call this method directly.
    /// If you want to force a layout update, call the `setNeedsLayout()` method instead
    /// to do so prior to the next drawing update.
    /// If you want to update the layout of your views immediately, call the `layoutIfNeeded()` method.
    open func layoutSubviews() {
        
        // TODO: Implement basic autoresize engine
    }
    
    /// Invalidates the current layout of the receiver and triggers a layout update during the next update cycle.
    ///
    /// Call this method on your application’s main thread when you want to adjust the layout of a view’s subviews.
    /// This method makes a note of the request and returns immediately.
    /// Because this method does not force an immediate update, but instead waits for the next update cycle,
    /// you can use it to invalidate the layout of multiple views before any of those views are updated.
    /// This behavior allows you to consolidate all of your layout updates to one update cycle,
    /// which is usually better for performance.
    public final func setNeedsLayout() {
        
        
    }
    
    /// Lays out the subviews immediately.
    ///
    /// Use this method to force the layout of subviews before drawing.
    /// Using the view that receives the message as the root view,
    /// this method lays out the view subtree starting at the root.
    public final func layoutIfNeeded() {
        
        
    }
    
    // MARK: - Final Methods
    
    public final func addSubview(_ view: UIView) {
        
        subviews.append(view)
        
        setNeedsDisplay()
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
    
    public func setNeedsDisplay(_ rect: Rect? = nil) {
        
        self.window?.screen.needsDisplay = true
    }
    
    // MARK: - Update Properties
    
    private func frameChanged() {
        
        // sync size
        self.bounds.size = self.frame.size
        
        setNeedsLayout()
    }
    
    private func boundsChanged() {
        
        // sync size
        self.frame.size = self.frame.size
        
        setNeedsLayout()
    }
}
