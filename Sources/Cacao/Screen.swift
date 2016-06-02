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
    
    public var scale: Double {
        
        return target.nativeSize.width / target.size.width
    }
    
    public var rootViewController: ViewController? {
        
        didSet { updateViewLayout() }
    }
    
    public var target: (surface: Surface, nativeSize: Size, size: Size) {
        
        didSet { updateViewLayout() }
    }
    
    // MARK: - Private Properties
    
    private var context: Silica.Context!
    
    // MARK: - Initialization
    
    public init(surface: Surface, nativeSize: Size, size: Size) {
        
        self.target = (surface, nativeSize, size)
    }
    
    // MARK: - Methods
    
    public func render() throws {
        
        context = try Silica.Context(surface: target.surface, size: target.nativeSize)
        
        context.scale(x: scale, y: scale)
        
        let frame = Rect(size: target.size)
        
        // render views
        
        if let rootView = rootViewController?.view {
            
            render(view: rootView, in: frame)
        }
    }
    
    public func handle(event: PointerEvent) {
        
        guard let rootView = rootViewController?.view,
            let hitView = rootView.hitTest(point: event.screenLocation)
            else { return }
        
        hitView.handle(event: event)
    }
    
    /*
    /// Converts a point in the screen's coordinates to a subview's coordinates.
    public func convert(point: Point, to view: View) {
        
        
    }*/
    
    // MARK: - Private Methods
    
    private func render(view: View, in frame: Rect) {
        
        guard view.hidden == false
            else { return }
        
        // add translation
        context.translate(x: view.frame.x, y: view.frame.y)
        
        // render view
        if let drawable = view as? Drawable {
            
            drawable.draw(context: context)
            
            if drawable.clipsToBounds {
                
                // FIXME
                //content.clip(to: view.frame)
            }
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
}