//
//  ContentView.swift
//  Cacao
//
//  Created by Alsey Coleman Miller on 5/29/16.
//  Copyright © 2016 PureSwift. All rights reserved.
//

#if os(Linux)
import Glibc
#endif

import Silica

/// A view that lays out its content according to a `ContentMode`.
public final class ContentView: View {
    
    // MARK: - Properties
    
    public var frame: Rect { didSet { layoutSubviews() } }
    
    /// Content view.
    public var content: View { didSet { size = content.frame.size; layoutSubviews() } }
    
    /// Content's size.
    public var size: Size
    
    /// Content's display mode.
    public var mode: ContentMode { didSet { layoutSubviews() } }
    
    public var subviews: [View] {
        
        return [content]
    }
    
    public var userInteractionEnabled: Bool {
        
        return content.userInteractionEnabled
    }
    
    // MARK: - Initialization
    
    public init(frame: Rect = Rect(), content: View, mode: ContentMode = ContentMode()) {
        
        self.frame = frame
        self.content = content
        self.mode = mode
        self.size = content.frame.size
        self.layoutSubviews()
    }
    
    // MARK: - Methods
    
    public func layoutSubviews() {
        
        let bounds = Rect(size: frame.size)
        
        content.frame = mode.rect(for: bounds, size: size)
        
        // layout all subviews
        subviews.forEach { $0.layoutSubviews() }
    }
}

// MARK: - Supporting Types

public enum ContentMode {
    
    case scaleToFill
    case aspectFit
    case aspectFill
    case center
    case top
    case bottom
    case left
    case right
    case topLeft
    case topRight
    case bottomLeft
    case bottomRight
    
    public init() { self = .scaleToFill }
    
    public func rect(for bounds: Rect, size: Size) -> Rect {
        
        switch self {
            
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
            
        case left:
            
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


