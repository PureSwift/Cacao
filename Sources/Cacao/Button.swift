//
//  Button.swift
//  Cacao
//
//  Created by Alsey Coleman Miller on 5/28/16.
//  Copyright © 2016 PureSwift. All rights reserved.
//

import Silica

public final class Button<Content: View>: View {
    
    public var frame: Rect
    
    public var userInteractionEnabled: Bool = true
    
    public var hidden: Bool = false
    
    public var contentView: ContentView<Content>
    
    public var subviews: [View] {
        
        return [contentView]
    }
    
    // MARK: - Initialization
    
    public init(frame: Rect = Rect(), content: Content) {
        
        self.frame = frame
        self.contentView = ContentView<Content>(frame: Rect(size: frame.size), content: content)
    }
    
    // MARK: - Methods
    
    public func handle(event: PointerEvent) {
        
        print("Event: \(event)")
    }
}
