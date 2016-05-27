//
//  UIScreen.swift
//  Cacao
//
//  Created by Alsey Coleman Miller on 5/14/16.
//  Copyright © 2016 PureSwift. All rights reserved.
//

import Cairo
import Silica

/// Device screen
public final class UIScreen {
    
    // MARK: - Class Properties
    
    public internal(set) static var main: UIScreen!
    
    public internal(set) static var screens: [UIScreen] = [main]
    
    // MARK: - Properties
    
    public let scale: Double = 1.0
    
    public var bounds: Rect {
        
        return Rect(size: size)
    }
    
    public internal(set) var windows = [UIWindow]()
    
    // MARK: - Internal Properties
    
    internal var size: Size
    
    internal var surface: Surface
    
    internal var context: Silica.Context!
    
    internal var needsDisplay = true
    
    internal var needsLayout = true
    
    // MARK: - Initialization
    
    internal init(surface: Surface, size: Size) {
        
        self.size = size
        self.surface = surface
    }
    
    // MARK: - Internal Methods
    
    internal func render() throws {
        
        context = try Silica.Context(surface: surface, size: size)
        
        /// render views
        
        let frame = Rect(size: size)
        
        UIGraphicsPushContext(context)
        
        // render views
        windows.forEach { render(view: $0, in: frame) }
        
        UIGraphicsPopContext()
        
        needsDisplay = false
        needsLayout = false
    }
    
    // MARK: - Private Methods
    
    private func render(view: UIView, in frame: Rect) {
        
        guard view.hidden == false
            && view.alpha > 0
            else { return }
        
        // add translation
        context.translate(x: view.frame.x, y: view.frame.y)
        
        // draw
        let bounds = Rect(size: view.frame.size)
        
        // draw background color
        context.fillColor = view.backgroundColor.CGColor
        context.add(rect: bounds)
        try! context.fill()
        
        // render view
        view.draw(bounds)
        
        // layout subviews
        view.layoutSubviews()
        
        // render subviews
        view.subviews.forEach { render(view: $0, in: bounds) }
        
        // TODO: apply alpha
        
        // remove translation
        context.translate(x: -view.frame.x, y: -view.frame.y)
    }
}
