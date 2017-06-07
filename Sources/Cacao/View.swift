//
//  View.swift
//  Cacao
//
//  Created by Alsey Coleman Miller on 5/27/16.
//  Copyright © 2016 PureSwift. All rights reserved.
//

import Silica

public extension View {
    
    var subviews: [View] { return [] }
    
    var hidden: Bool { return false }
    
    var userInteractionEnabled: Bool { return true }
    
    func layoutSubviews() {
        
        subviews.forEach { $0.layoutSubviews() }
    }
    
    func handle(event: PointerEvent) { }
    
    /// Returns the farthest descendant of the receiver in the view hierarchy (including itself) that contains a specified point.
    /// 
    /// - Note: This method ignores view objects that are hidden or have user interaction disabled.
    /// This method does not take the view’s content into account when determining a hit. 
    /// Thus, a view can still be returned even if the specified point is in a transparent portion of that view’s content.
    func hitTest(point: Point) -> View? {
        
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
    
    /// Returns a Boolean value indicating whether the receiver contains the specified point.
    func pointInside(_ point: Point) -> Bool {
        
        let bounds = Rect(size: frame.size)
        
        return bounds.contains(point)
    }
    
    func setNeedsDiplay() {
        
        
    }
    
    func setNeedsLayout() {
        
        
    }
}
