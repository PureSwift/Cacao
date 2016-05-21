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
    
    public var scale: Double = 1.0
    
    public var size: Size {
        
        didSet { self.context = try! Silica.Context(surface: surface, size: size) }
    }
    
    public let surface: Surface
    
    public var windows = [UIWindow]()
    
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
        
        UIGraphicsPushContext(context)
        
        // render views
        windows.forEach { render(view: $0, in: frame) }
        
        UIGraphicsPopContext()
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
        
        view.layoutSubviews()
        
        // render subviews
        view.subviews.forEach { render(view: $0, in: bounds) }
        
        // TODO: apply alpha
        
        // remove translation
        context.translate(x: -view.frame.x, y: -view.frame.y)
    }
}
