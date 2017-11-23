//
//  UIViewContentMode.swift
//  Cacao
//
//  Created by Alsey Coleman Miller on 5/31/16.
//  Copyright © 2016 PureSwift. All rights reserved.
//

#if os(macOS)
    import Darwin.C.math
#elseif os(Linux)
    import Glibc
#endif

import Foundation
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

// MARK: - Internal Cacao Extension

internal extension UIViewContentMode {
    
    func rect(for bounds: CGRect, size: CGSize) -> CGRect {
        
        switch self {
            
        case .redraw: fallthrough
            
        case .scaleToFill:
            
            return CGRect(origin: .zero, size: bounds.size)
            
        case .scaleAspectFit:
            
            let widthRatio = bounds.width / size.width
            let heightRatio = bounds.height / size.height
            
            var newSize = bounds.size
            
            if (widthRatio < heightRatio) {
                
                newSize.height = bounds.size.width / size.width * size.height
                
            } else if (heightRatio < widthRatio) {
                
                newSize.width = bounds.size.height / size.height * size.width
            }
            
            newSize = CGSize(width: ceil(newSize.width), height: ceil(newSize.height))
            
            var origin = bounds.origin
            origin.x += (bounds.size.width - newSize.width) / 2.0
            origin.y += (bounds.size.height - newSize.height) / 2.0
            
            return CGRect(origin: origin, size: newSize)
            
        case .scaleAspectFill:
            
            let widthRatio = (bounds.size.width / size.width)
            let heightRatio = (bounds.size.height / size.height)
            
            var newSize = bounds.size
            
            if (widthRatio > heightRatio) {
                
                newSize.height = bounds.size.width / size.width * size.height
                
            } else if (heightRatio > widthRatio) {
                
                newSize.width = bounds.size.height / size.height * size.width
            }
            
            newSize = CGSize(width: ceil(newSize.width), height: ceil(newSize.height))
            
            var origin = CGPoint()
            origin.x = (bounds.size.width - newSize.width) / 2.0
            origin.y = (bounds.size.height - newSize.height) / 2.0
            
            return CGRect(origin: origin, size: newSize)
            
        case .center:
            
            var rect = CGRect(origin: .zero, size: size)
            
            rect.origin.x = (bounds.size.width - rect.size.width) / 2.0
            rect.origin.y = (bounds.size.height - rect.size.height) / 2.0
            
            return rect
            
        case .top:
            
            var rect = CGRect(origin: .zero, size: size)
            
            rect.origin.y = 0.0
            rect.origin.x = (bounds.size.width - rect.size.width) / 2.0
            
            return rect
            
        case .bottom:
            
            var rect = CGRect(origin: .zero, size: size)
            
            rect.origin.x = (bounds.size.width - rect.size.width) / 2.0
            rect.origin.y = bounds.size.height - rect.size.height
            
            return rect
            
        case .left:
            
            var rect = CGRect(origin: .zero, size: size)
            
            rect.origin.x = 0.0
            rect.origin.y = (bounds.size.height - rect.size.height) / 2.0
            
            return rect
            
        case .right:
            
            var rect = CGRect(origin: .zero, size: size)
            
            rect.origin.x = bounds.size.width - rect.size.width
            rect.origin.y = (bounds.size.height - rect.size.height) / 2.0
            
            return rect
            
        case .topLeft:
            
            return CGRect(origin: .zero, size: size)
            
        case .topRight:
            
            var rect = CGRect(origin: .zero, size: size)
            
            rect.origin.x = bounds.size.width - rect.size.width
            rect.origin.y = 0.0
            
            return rect
            
        case .bottomLeft:
            
            var rect = CGRect(origin: .zero, size: size)
            
            rect.origin.x = 0.0
            rect.origin.y = bounds.size.height - rect.size.height
            
            return rect
            
        case .bottomRight:
            
            var rect = CGRect(origin: .zero, size: size)
            
            rect.origin.x = bounds.size.width - rect.size.width
            rect.origin.y = bounds.size.height - rect.size.height
            
            return rect
        }
    }
}
