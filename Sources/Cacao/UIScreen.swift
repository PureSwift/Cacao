//
//  Screen.swift
//  Cacao
//
//  Created by Alsey Coleman Miller on 5/27/16.
//  Copyright © 2016 PureSwift. All rights reserved.
//

import Foundation
import CSDL2
import SDL
import Silica

public final class UIScreen {
    
    public static var main: UIScreen { return _main }
    internal static var _main: UIScreen!
    
    public static var screens: [UIScreen] { return [UIScreen.main] }
    
    // MARK: - Properties
    
    public var mirrored: UIScreen? { return nil }
    
    //public private(set) var coordinateSpace: UICoordinateSpace
    
    //var fixedCoordinateSpace: UICoordinateSpace
    
    public var bounds: CGRect { return CGRect(origin: .zero, size: size.window) }
    
    public var nativeBounds: CGRect { return CGRect(origin: .zero, size: size.native) }
    
    public var scale: CGFloat { return size.native.width / size.window.width }
    
    public var nativeScale: CGFloat { return scale }
    
    public var maximumFramesPerSecond: Int {
        
        return try! window.displayMode().refreshRate
    }
    
    internal let window: SDLWindow
    
    private var size: (window: CGSize, native: CGSize) { didSet { sizeChanged() } }
    
    internal let renderer: SDLRenderer
    
    internal var needsDisplay = true
    
    internal var needsLayout = true
    
    /// Children windows
    private var _windows = WeakArray<UIWindow>()
    internal var windows: [UIWindow] { return _windows.values() }
    
    internal private(set) weak var keyWindow: UIWindow?
    
    // MARK: - Intialization
    
    internal init(window: SDLWindow, size: CGSize) throws {
        
        self.renderer = try SDLRenderer(window: window)
        self.window = window
        self.size = (size, size)
        
        // update values
        self.updateSize()
        try self.renderer.setDrawColor((0x00, 0x00, 0x00, 0xFF))
    }
    
    // MARK: - Methods
    
    internal func updateSize() {
        
        let windowSize = window.size
        let size = CGSize(width: CGFloat(windowSize.width),
                          height: CGFloat(windowSize.height))
        
        let rendererSize = window.drawableSize
        let nativeSize = CGSize(width: CGFloat(rendererSize.width),
                                height: CGFloat(rendererSize.height))
        
        self.size = (size, nativeSize)
        self.needsLayout = true
        self.needsDisplay = true
    }
    
    /// Layout (if needed) and redraw the screen
    internal func update() throws {
        
        // apply animations
        if UIView.animations.isEmpty == false {
            
            needsDisplay = true
            needsLayout = true
            
            UIView.animations = UIView.animations.filter { $0.frameChange() }
        }
        
        // layout views
        if needsLayout {
            
            defer { needsLayout = false }
            
            windows.forEach { $0.layoutIfNeeded() }
            
            needsDisplay = true // also render views
        }
        
        // render views
        if needsDisplay {
            
            defer { needsDisplay = false }
            
            try renderer.clear()
            
            for window in windows {
                
                // render view hierarchy
                try render(view: window)
            }
            
            // render to screen
            renderer.present()
        }
    }
    
    private func sizeChanged() {
        
        // update windows
        windows.forEach { $0.frame = CGRect(origin: .zero, size: size.window) }
        
        needsDisplay = true
        needsLayout = true
    }
    
    private func render(view: UIView, origin: CGPoint = .zero) throws {
        
        guard view.shouldRender
            else { return }
        
        // add translation
        //context.translate(x: view.frame.x, y: view.frame.y)
        var relativeOrigin = origin
        relativeOrigin.x += (view.frame.origin.x + (view.superview?.bounds.origin.x ?? 0.0)) * scale
        relativeOrigin.y += (view.frame.origin.y + (view.superview?.bounds.origin.y ?? 0.0)) * scale
        
        // frame of view relative to SDL window
        let rect = SDL_Rect(x: Int32(relativeOrigin.x),
                            y: Int32(relativeOrigin.y),
                            w: Int32(view.bounds.size.width * scale),
                            h: Int32(view.bounds.size.height * scale))
        
        // render view
        try view.render(on: self, in: rect)
        
        // render subviews
        try view.subviews.forEach { try render(view: $0, origin: relativeOrigin) }
    }
    
    internal func addWindow(_ window: UIWindow) {
        
        _windows.append(window)
    }
    
    internal func setKeyWindow(_ window: UIWindow) {
        
        guard UIScreen.main.keyWindow !== self
            else { return }
        
        if windows.contains(where: { $0 === window }) == false {
            
            addWindow(window)
        }
        
        keyWindow?.resignKey()
        keyWindow = window
        keyWindow?.becomeKey()
    }
}
