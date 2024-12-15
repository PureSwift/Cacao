//
//  View.swift
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
import Cairo
import Silica

@MainActor
open class View: AnyObject {
    
    // MARK: - Initialization
    
    /// Initializes and returns a newly allocated view object with the specified frame rectangle.
    public init(frame: CGRect = .zero) {
        self.frame = frame
    }
    
    // MARK: - Properties
    
    public final var frame: CGRect
    
    /// The receiver’s superview, or nil if it has none.
    public final private(set) weak var superview: View?
    
    /// The receiver’s immediate subviews.
    ///
    /// You can use this property to retrieve the subviews associated with your custom view hierarchies.
    /// The order of the subviews in the array reflects their visible order on the screen,
    /// with the view at index 0 being the back-most view.
    public final private(set) var subviews: [View] = []
    
    /// The view’s background color.
    ///
    /// The default value is `nil`, which results in a transparent background color.
    public final var backgroundColor: UIColor? { didSet { setNeedsDisplay() } }
    
    /// The backing rendering node / texture.
    ///
    /// Cacao's equivalent of `UIView.layer` / `CALayer`.
    /// Instead of the CoreGraphics API you could draw directly to the texture's pixel data.
    ///
    /// The value is guarenteed to be valid during `draw()` calls and can be used directly
    /// (e.g. video streaming, SDL game) instead of the CoreGraphics drawing API.
    ///
    /// - Warning: Do not hold a reference to this object as it can be recreated as needed for rendering.
    public private(set) var texture: SDLTexture?
    
    internal var shouldRender: Bool {
        return isHidden == false
            && alpha > 0
            && bounds.size.width >= 1.0
            && bounds.size.height >= 1.0 // must be at least 1x1
    }
    
    // MARK: - Methods
    
    /// Unlinks the view from its superview and its window, and removes it from the responder chain.
    ///
    /// If the view’s superview is not `nil`, the superview releases the view.
    ///
    /// - Note: Calling this method removes any constraints that refer to the view you are removing,
    /// or that refer to any view in the subtree of the view you are removing.
    public final func removeFromSuperview() {
        
        guard let index = superview?.subviews.index(where: { $0 === self })
            else { return }
        
        superview?.willRemoveSubview(self)
        
        superview?.subviews.remove(at: index)
    }
    
    internal final func render(on screen: UIScreen, in rect: SDL_Rect) throws {
        
        guard shouldRender
            else { return }
        
        let scale = screen.scale
        let nativeSize = (width: Int(bounds.size.width * scale),
                          height: Int(bounds.size.height * scale))
        
        let texture: SDLTexture
        
        // reuse cached texture if view hasn't been resized.
        if let cachedTexture = self.texture,
            let attributes = try? cachedTexture.attributes(),
            attributes.width == nativeSize.width,
            attributes.height == nativeSize.height {
            
            texture = cachedTexture
            
        } else {
            
            texture = try SDLTexture(renderer: screen.renderer,
                                     format: .argb8888, // SDL_PIXELFORMAT_ARGB8888
                                     access: .streaming,
                                     width: nativeSize.width,
                                     height: nativeSize.height)
            
            try texture.setBlendMode([.alpha])
            
            // cache for reuse if view size isn't changed
            self.texture = texture
        }
        
        // unlock and modify texture
        try texture.withUnsafeMutableBytes {
            
            let surface = try Cairo.Surface.Image(mutableBytes: $0.assumingMemoryBound(to: UInt8.self),
                                                   format: .argb32,
                                                   width: nativeSize.width,
                                                   height: nativeSize.height,
                                                   stride: $1)
            
            // reset memory
            memset($0, 0, surface.stride * surface.height)
            
            let context = try! CGContext(surface: surface, size: bounds.size)
            context.scaleBy(x: scale, y: scale)
            
            // CoreGraphics drawing
            draw(in: context)
            
            /// flush surface
            surface.flush()
            surface.finish()
        }
        
        try screen.renderer.copy(texture, destination: rect)
    }
    
    internal func draw(in context: Silica.CGContext) {
        
        UIGraphicsPushContext(context)
        
        // draw background color
        context.fillColor = backgroundColor?.cgColor ?? CGColor.clear
        context.addRect(bounds)
        context.fillPath()
        
        // apply alpha
        context.setAlpha(alpha)
        
        // draw rect
        draw(bounds)
        
        UIGraphicsPopContext()
    }
}

public protocol Responder: View {
    
    func handle(_ event: Event)
}

/// View that renders an SDL Surface
public protocol RenderedView: View {
    
    var surface: SDLSurface { get throws }
}

/// A view that renders to a Cairo context
public protocol Canvas: View {
    
    func draw(_ context: Cairo.Context)
}

public extension Canvas {
    
}

public protocol SilicaCanvas: Canvas {
    
    func draw()
}

public extension SilicaCanvas {
    
    func draw(_ context: Cairo.Context) {
        let silicaContext = try! CGContext(
            surface: context.surface,
            size: frame.size
        )
        UIGraphicsPushContext(silicaContext)
        draw()
        UIGraphicsPopContext()
    }
}
