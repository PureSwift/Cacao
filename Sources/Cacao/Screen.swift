//
//  Screen.swift
//  Cacao
//
//  Created by Alsey Coleman Miller on 5/27/16.
//  Copyright © 2016 PureSwift. All rights reserved.
//

import Cairo
import Silica

public final class Screen {
    
    // MARK: - Properties
    
    public var rootViewController: ViewController? {
        
        didSet { updateViewLayout() }
    }
    
    public var target: (surface: Surface, size: Size) {
        
        didSet { updateViewLayout() }
    }
    
    // MARK: - Private Properties
    
    private var context: Silica.Context!
    
    // MARK: - Initialization
    
    public init(surface: Surface, size: Size) {
        
        self.target = (surface, size)
    }
    
    // MARK: - Methods
    
    public func render() throws {
        
        context = try Silica.Context(surface: target.surface, size: target.size)
        
        let frame = Rect(size: target.size)
        
        // render views
        
        if let rootView = rootViewController?.view {
            
            render(view: rootView, in: frame)
        }
    }
    
    // MARK: - Internal / Private Methods
    
    private func render(view: View, in frame: Rect) {
        
        // add translation
        context.translate(x: view.frame.x, y: view.frame.y)
        
        // render view
        if let drawableView = view as? DrawableView {
            
            drawableView.draw(context: context)
        }
        
        // render subviews
        let bounds = Rect(size: frame.size)
        view.subviews.forEach { render(view: $0, in: bounds) }
        
        // remove translation
        context.translate(x: -view.frame.x, y: -view.frame.y)
    }
    
    @inline(__always)
    private func updateViewLayout() {
        
        rootViewController?.view.frame = Rect(size: target.size)
        rootViewController?.layoutView()
    }
    
    internal func handle(event: Event) {
        
        // send to view
    }
}