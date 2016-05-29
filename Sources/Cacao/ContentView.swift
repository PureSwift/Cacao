//
//  ContentView.swift
//  Cacao
//
//  Created by Alsey Coleman Miller on 5/29/16.
//  Copyright © 2016 PureSwift. All rights reserved.
//

import Silica

/// A view that lays out its content according to a `ContentMode`.
public final class ContentView: View {
    
    // MARK: - Properties
    
    public var frame: Rect
    
    /// Content view.
    public var content: View {
        
        didSet { size = content.frame.size }
    }
    
    /// Content's size.
    public var size: Size
    
    /// Content's display mode.
    public var mode: ContentMode
    
    public var subviews: [View] {
        
        return [content]
    }
    
    public var userInteractionEnabled: Bool {
        
        return content.userInteractionEnabled
    }
    
    // MARK: - Initialization
    
    public init(frame: Rect, content: View, mode: ContentMode = ContentMode()) {
        
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
    
    public init() { self = .scaleToFill }
    
    public func rect(for bounds: Rect, size: Size) -> Rect {
        
        switch self {
            
        case .scaleToFill:
            
            return Rect(size: bounds.size)
            
        case .aspectFit:
            
            let widthRatio = (bounds.width / size.width)
            let heightRatio = (bounds.height / size.height)
            
            var boundingSize = bounds.size
            
            if (widthRatio < heightRatio) {
                
                boundingSize.height = bounds.size.width / size.width * size.height
                
            } else if (heightRatio < widthRatio) {
                
                boundingSize.width = bounds.size.height / size.height * size.width
            }
            
            let size = Size(width: ceil(boundingSize.width), height: ceil(boundingSize.height))
            
            var origin = bounds.origin
            origin.x += (bounds.size.width - size.width) / 2.0
            origin.y += (bounds.size.height - size.height) / 2.0
            
            return Rect(origin: origin, size: size)
            
        case .aspectFill:
            
            fatalError()
        }
    }
}


