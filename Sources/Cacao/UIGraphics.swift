//
//  UIGraphics.swift
//  Cacao
//
//  Created by Alsey Coleman Miller on 5/12/16.
//  Copyright © 2016 PureSwift. All rights reserved.
//

import Silica

/// Returns the current graphics context.
///
/// The current graphics context is `nil` by default.
/// Prior to calling its drawRect: method, view objects push a valid context onto the stack, making it current.
/// If you are not using a UIView object to do your drawing, however, 
/// you must push a valid context onto the stack manually using the `UIGraphicsPushContext()` function.
///
/// This function may be called from any thread of your app.
public func UIGraphicsGetCurrentContext() -> CGContext? {
    
    return UIGraphicsContextStack.last
}

/// Makes the specified graphics context the current context.
public func UIGraphicsPushContext(_ context: CGContext) {
    
    UIGraphicsContextStack.append(context)
}

/// Removes the current graphics context from the top of the stack, restoring the previous context.
public func UIGraphicsPopContext() {
    
    if UIGraphicsContextStack.isEmpty == false {
        
        UIGraphicsContextStack.removeLast()
    }
}

// MARK: - Private

private var UIGraphicsContextStack: [CGContext] = []
