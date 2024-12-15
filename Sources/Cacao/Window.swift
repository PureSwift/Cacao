//
//  Window.swift
//  Cacao
//
//  Created by Alsey Coleman Miller on 12/14/24.
//

import Foundation
#if canImport(CoreGraphics)
import CoreGraphics
#endif
import SDL
import CSDL2

@MainActor
public final class Window {
    
    // MARK: - Properties
    
    internal let sdlWindow: SDLWindow
    
    internal let renderer: SDLRenderer
    
    public private(set) var needsDisplay: Bool = true
    
    // MARK: Initialization
    
    private static var _windows: WeakArray<Window> = []
    
    public static func didCreateWindow(_ window: Window) {
        _windows.append(window)
    }
    
    public static var windows: [Window] {
        _windows.values()
    }
    
    public init(
        title: String,
        size: CGSize = CGSize(width: 640, height: 480)
    ) {
        do {
            let sdlWindow = try SDLWindow(
                title: title,
                frame: (x: .centered, y: .centered, width: Int(size.width), height: Int(size.height)),
                options: [.resizable, .shown, .opengl]
            )
            let renderer = try SDLRenderer(window: sdlWindow)
            self.sdlWindow = sdlWindow
            self.renderer = renderer
        }
        catch {
            fatalError("Unable to create window. \(error)")
        }
        // inform singleton
        Self.didCreateWindow(self)
    }
    
    // MARK: - Accessors
    
    public var title: String {
        get {
            sdlWindow.title
        }
        set {
            sdlWindow.title = newValue
        }
    }
    
    public var size: CGSize {
        get {
            let size = sdlWindow.size
            return CGSize(width: Double(size.width), height: Double(size.height))
        }
        set {
            sdlWindow.size = (Int(newValue.width), Int(newValue.height))
        }
    }
    
    // MARK: - Methods
    
    public func setNeedsDisplay() {
        self.needsDisplay = true
    }
    
    internal func update() throws {
        
        
    }
    
    internal func handle(_ event: SDL_WindowEvent) {
        setNeedsDisplay()
    }
    
    internal func sendEvent(_ event: Event) {
        
        
    }
}
