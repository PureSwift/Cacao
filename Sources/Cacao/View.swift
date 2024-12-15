//
//  View.swift
//  Cacao
//
//  Created by Alsey Coleman Miller on 12/14/24.
//

import Foundation
import SDL
import Cairo
import Silica

@MainActor
public protocol View: AnyObject {
    
    var frame: CGRect { get }
    
    var subviews: [any View] { get }
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
