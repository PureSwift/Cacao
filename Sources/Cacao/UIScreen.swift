//
//  Screen.swift
//  Cacao
//
//  Created by Alsey Coleman Miller on 5/27/16.
//  Copyright © 2016 PureSwift. All rights reserved.
//

import CSDL2
import SDL
import Silica

public final class UIScreen {
    
    public static internal(set) var main: UIScreen!
    
    public static var screens: [UIScreen] { return [UIScreen.main] }
    
    // MARK: - Properties
    
    public var mirrored: UIScreen? { return nil }
    
    //public private(set) var coordinateSpace: UICoordinateSpace
    
    //var fixedCoordinateSpace: UICoordinateSpace
    
    public var bounds: CGRect { return CGRect(size: size.window) }
    
    public var nativeBounds: CGRect { return CGRect(size: size.window) }
    
    public var scale: Double { return size.native.width / size.window.width }
    
    public var nativeScale: Double { return scale }
    
    public var maximumFramesPerSecond: Int {
        
        return Int(window.displayMode?.refresh_rate ?? 60)
    }
    
    internal let window: Window
    
    internal var size: (window: Size, native: Size) { didSet { sizeChanged() } }
    
    internal lazy var renderer: Renderer = Renderer(window: self.window).sdlAssert()
    
    internal var needsDisplay = true
    
    internal var needsLayout = true
    
    /// Children windows
    internal var windows = [UIWindow]()
    
    internal var keyWindow: UIWindow?
    
    // MARK: - Intialization
    
    internal init(window: Window, size: (window: Size, native: Size)) {
        
        self.window = window
        self.size = size
    }
    
    // MARK: - Methods
    
    /// Layout (if needed) and redraw the screen
    internal func update() {
        
        // layout views
        if needsLayout {
            windows.forEach { $0.layoutIfNeeded() }
        }
        
        // render views
        if needsLayout || needsDisplay {
            
            renderer.drawColor = (0xFF, 0xFF, 0xFF, 0xFF)
            renderer.clear()
            
            // FIXME to support multiple windows
            for window in [keyWindow!] {
                
                // render view hierarchy
                render(view: window)
                
            }
            
            // render to screen
            renderer.present()
        }
        
        needsDisplay = false
        needsLayout = false
    }
    
    private func sizeChanged() {
        
        // update windows
        keyWindow?.frame = Rect(size: size.window)
        
        needsDisplay = true
        needsLayout = true
    }
    
    private func render(view: UIView, origin: Point = Point()) {
        
        guard view.shouldRender
            else { return }
        
        // add translation
        //context.translate(x: view.frame.x, y: view.frame.y)
        var relativeOrigin = origin
        relativeOrigin.x += view.frame.origin.x
        relativeOrigin.y += view.frame.origin.y
        
        // frame of view relative to SDL window
        let rect = SDL_Rect(x: Int32(relativeOrigin.x),
                            y: Int32(relativeOrigin.y),
                            w: Int32(view.frame.size.width),
                            h: Int32(view.frame.size.height))
        
        // render view
        view.render(with: renderer, in: rect)
        
        // render subviews
        view.subviews.forEach { render(view: $0, origin: relativeOrigin) }
    }
}

/*
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
*/
 
