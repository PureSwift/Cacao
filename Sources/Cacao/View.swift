//
//  View.swift
//  Cacao
//
//  Created by Alsey Coleman Miller on 5/27/16.
//  Copyright © 2016 PureSwift. All rights reserved.
//

import Silica

/// The view protocol.
public protocol View {
    
    var frame: Rect { get set }
    
    var subviews: [View] { get }
}

/// A view that can draw with `Silica`.
public protocol DrawableView: View {
    
    func draw(context: Silica.Context)
}

/// A view that can recieve events.
public protocol InteractiveView: View {
    
    func handle(event: Event)
}
