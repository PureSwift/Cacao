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
    
    public var nativeBounds: CGRect { return CGRect(size: size.native) }
    
    public var scale: Double { return size.native.width / size.window.width }
    
    public var nativeScale: Double { return scale }
    
    public var maximumFramesPerSecond: Int {
        
        return Int(window.displayMode?.refresh_rate ?? 60)
    }
    
    internal let window: Window
    
    private var size: (window: Size, native: Size)
    
    internal let renderer: Renderer
    
    internal var needsDisplay = true
    
    internal var needsLayout = true
    
    /// Children windows
    private var _windows = WeakArray<UIWindow>()
    internal var windows: [UIWindow] { return _windows.values() }
    
    internal private(set) weak var keyWindow: UIWindow?
    
    // MARK: - Intialization
    
    internal init(window: Window, size: Size) {
        
        self.renderer = Renderer(window: window).sdlAssert()
        self.window = window
        self.size = (size, size)
        self.updateSize()
    }
    
    // MARK: - Methods
    
    internal func updateSize() {
        
        let windowSize = window.size
        let size = Size(width: Double(windowSize.width), height: Double(windowSize.height))
        
        let rendererSize = window.drawableSize
        let nativeSize = Size(width: Double(rendererSize.width), height: Double(rendererSize.height))
        
        self.size = (size, nativeSize)
        self.needsDisplay = true
    }
    
    /// Layout (if needed) and redraw the screen
    internal func update() {
        
        // layout views
        if needsLayout {
            
            windows.forEach { $0.layoutIfNeeded() }
            needsDisplay = true // also updated render views
        }
        
        // render views
        if needsDisplay {
            
            renderer.drawColor = (0xFF, 0xFF, 0xFF, 0xFF)
            renderer.clear()
            
            for window in windows {
                
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
        windows.forEach { $0.frame = Rect(size: size.window) }
        
        needsDisplay = true
        needsLayout = true
    }
    
    private func render(view: UIView, origin: Point = Point()) {
        
        guard view.shouldRender
            else { return }
        
        // add translation
        //context.translate(x: view.frame.x, y: view.frame.y)
        var relativeOrigin = origin
        relativeOrigin.x += view.frame.origin.x * scale
        relativeOrigin.y += view.frame.origin.y * scale
        
        // frame of view relative to SDL window
        let rect = SDL_Rect(x: Int32(relativeOrigin.x),
                            y: Int32(relativeOrigin.y),
                            w: Int32(view.frame.size.width * scale),
                            h: Int32(view.frame.size.height * scale))
        
        // render view
        view.render(with: renderer, in: rect)
        
        // render subviews
        view.subviews.forEach { render(view: $0, origin: relativeOrigin) }
    }
    
    internal func addWindow(_ window: UIWindow) {
        
        _windows.append(window)
    }
    
    internal func setKeyWindow(_ window: UIWindow) {
        
        if windows.contains(where: { $0 === window }) == false {
            
            addWindow(window)
        }
        
        keyWindow = window
    }
}
