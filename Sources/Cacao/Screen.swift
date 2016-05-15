//
//  Screen.swift
//  Cacao
//
//  Created by Alsey Coleman Miller on 5/14/16.
//  Copyright © 2016 PureSwift. All rights reserved.
//

import Silica
import Cairo

/// Device screen
public final class Renderer {
    
    public var scale: Double = 1.0
    
    public var size: Size
    
    public var surface: Surface
    
    public var views = [View]()
    
    // MARK: - Private Properties
    
    internal var context: Silica.Context
    
    // MARK: - Initialization
    
    public init(surface: Surface, size: Size) throws {
        
        self.size = size
        self.surface = surface
        
        self.context = try Silica.Context(surface: surface, size: size)
    }
    
    // MARK: - Methods
    
    public func render() throws {
        
        let context = try Silica.Context(surface: surface, size: size)
        
        self.context = context
        
        /// render views
        
        let frame = Rect(size: size)
        
        // render subviews
        views.forEach { render(view: $0, in: frame) }
    }
    
    // MARK: - Private Methods
    
    private func render(view: View, in frame: Rect) {
        
        // add translation
        context.translate(x: view.frame.x, y: view.frame.y)
        
        // draw
        view.draw(context: context)
        
        // render subviews
        view.subviews.forEach { render(view: $0, in: frame) }
        
        // remove translation
        context.translate(x: -view.frame.x, y: -view.frame.y)
    }
}
