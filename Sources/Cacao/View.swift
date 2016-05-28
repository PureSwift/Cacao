//
//  View.swift
//  Cacao
//
//  Created by Alsey Coleman Miller on 5/27/16.
//  Copyright © 2016 PureSwift. All rights reserved.
//

import Silica

/// The view protocol.
public protocol View: class {
    
    var frame: Rect { get set }
    
    var subviews: [View] { get }
    
    func layoutSubviews()
}

public extension View {
    
    var subviews: [View] { return [] }
    
    func layoutSubviews() {
        
        subviews.forEach { $0.layoutSubviews() }
    }
}

/// A view that can draw.
public protocol DrawableView: View {
    
    func draw(context: Silica.Context)
}

/// A view that can recieve events.
public protocol InteractiveView: View {
    
    func handle(event: Event)
}
