//
//  ContentView.swift
//  Cacao
//
//  Created by Alsey Coleman Miller on 5/29/16.
//  Copyright © 2016 PureSwift. All rights reserved.
//

import Silica

/// A view that lays out its content according to a `ContentMode`.
public final class ContentView<Content: View>: View {
    
    // MARK: - Properties
    
    public var frame: Rect
    
    public var content: Content
    
    public var mode: ContentMode
    
    public var subviews: [View] {
        
        return [content]
    }
    
    public var userInteractionEnabled: Bool {
        
        return content.userInteractionEnabled
    }
    
    // MARK: - Initialization
    
    public init(frame: Rect, content: Content, mode: ContentMode = .scaleToFill) {
        
        self.frame = frame
        self.content = content
        self.mode = mode
    }
    
    // MARK: - Methods
    
    public func layoutSubviews() {
        
        let bounds = Rect(size: frame.size)
        
        let contentRect: Rect
        
        switch mode {
            
        case .scaleToFill:
            
            contentRect = bounds
        }
        
        content.frame = contentRect
        
        // layout all subviews
        subviews.forEach { $0.layoutSubviews() }
    }
}

// MARK: - Supporting Types

public enum ContentMode {
    
    public init() { self = .scaleToFill }
    
    case scaleToFill
}
