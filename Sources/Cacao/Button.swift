//
//  Button.swift
//  Cacao
//
//  Created by Alsey Coleman Miller on 5/28/16.
//  Copyright © 2016 PureSwift. All rights reserved.
//

import Silica

public final class Button: View {
    
    public var frame: Rect
    
    public var userInteractionEnabled: Bool = true
    
    public var hidden: Bool = false
    
    public var contentView: ContentView
    
    public var subviews: [View] {
        
        return [contentView]
    }
    
    // MARK: - Initialization
    
    public init(frame: Rect = Rect(), content: View, mode: ContentMode = ContentMode()) {
        
        self.frame = frame
        self.contentView = ContentView(frame: Rect(size: frame.size), content: content, mode: mode)
    }
    
    // MARK: - Methods
    
    public func handle(event: PointerEvent) {
        
        print("Event: \(event)")
    }
}
