//
//  UIViewContentMode.swift
//  Cacao
//
//  Created by Alsey Coleman Miller on 5/31/16.
//  Copyright © 2016 PureSwift. All rights reserved.
//

import Silica

public enum UIViewContentMode: Int {
    
    public init() { self = .scaleToFill }
    
    case scaleToFill
    case scaleAspectFit
    case scaleAspectFill
    case redraw
    case center
    case top
    case bottom
    case left
    case right
    case topLeft
    case topRight
    case bottomLeft
    case bottomRight
}

// Cacao extension
public extension UIViewContentMode {
    
    public func rect(for bounds: Rect, size: Size) -> Rect {
        
        switch self {
            
        case .redraw:
            
            // tiled?
            fallthrough
            
        case .scaleToFill:
            
            return Rect(size: bounds.size)
            
        case .aspectFit:
            
            let widthRatio = bounds.width / size.width
            let heightRatio = bounds.height / size.height
            
            var newSize = bounds.size
            
            if (widthRatio < heightRatio) {
                
                newSize.height = bounds.size.width / size.width * size.height
                
            } else if (heightRatio < widthRatio) {
                
                newSize.width = bounds.size.height / size.height * size.width
            }
            
            newSize = Size(width: ceil(newSize.width), height: ceil(newSize.height))
            
            var origin = bounds.origin
            origin.x += (bounds.size.width - newSize.width) / 2.0
            origin.y += (bounds.size.height - newSize.height) / 2.0
            
            return Rect(origin: origin, size: newSize)
            
        case .aspectFill:
            
            let widthRatio = (bounds.size.width / size.width)
            let heightRatio = (bounds.size.height / size.height)
            
            var newSize = bounds.size
            
            if (widthRatio > heightRatio) {
                
                newSize.height = bounds.size.width / size.width * size.height
                
            } else if (heightRatio > widthRatio) {
                
                newSize.width = bounds.size.height / size.height * size.width
            }
            
            newSize = Size(width: ceil(newSize.width), height: ceil(newSize.height))
            
            var origin = Point()
            origin.x = (bounds.size.width - newSize.width) / 2.0
            origin.y = (bounds.size.height - newSize.height) / 2.0
            
            return Rect(origin: origin, size: newSize)
            
        case .center:
            
            var rect = Rect(size: size)
            
            rect.origin.x = (bounds.size.width - rect.size.width) / 2.0
            rect.origin.y = (bounds.size.height - rect.size.height) / 2.0
            
            return rect
            
        case .top:
            
            var rect = Rect(size: size)
            
            rect.origin.y = 0.0
            rect.origin.x = (bounds.size.width - rect.size.width) / 2.0
            
            return rect
            
        case .bottom:
            
            var rect = Rect(size: size)
            
            rect.origin.x = (bounds.size.width - rect.size.width) / 2.0
            rect.origin.y = bounds.size.height - rect.size.height
            
            return rect
            
        case .left:
            
            var rect = Rect(size: size)
            
            rect.origin.x = 0.0
            rect.origin.y = (bounds.size.height - rect.size.height) / 2.0
            
            return rect
            
        case .right:
            
            var rect = Rect(size: size)
            
            rect.origin.x = bounds.size.width - rect.size.width
            rect.origin.y = (bounds.size.height - rect.size.height) / 2.0
            
            return rect
            
        case .topLeft:
            
            return Rect(size: size)
            
        case .topRight:
            
            var rect = Rect(size: size)
            
            rect.origin.x = bounds.size.width - rect.size.width
            rect.origin.y = 0.0
            
            return rect
            
        case .bottomLeft:
            
            var rect = Rect(size: size)
            
            rect.origin.x = 0.0
            rect.origin.y = bounds.size.height - rect.size.height
            
            return rect
            
        case .bottomRight:
            
            var rect = Rect(size: size)
            
            rect.origin.x = bounds.size.width - rect.size.width
            rect.origin.y = bounds.size.height - rect.size.height
            
            return rect
        }
    }
}
