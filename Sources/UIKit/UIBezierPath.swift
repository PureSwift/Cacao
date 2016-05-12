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
    
    
    
    // MARK: - Initialization
    
    public init(rect: SwiftCoreGraphics.CGRect) {
        
        
    }
}
