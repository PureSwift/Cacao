//
//  Button.swift
//  Cacao
//
//  Created by Alsey Coleman Miller on 5/28/16.
//  Copyright © 2016 PureSwift. All rights reserved.
//

import Silica

public final class Button: View {
    
    public var frame: Rect { didSet { layoutSubviews() } }
    
    public var userInteractionEnabled: Bool = true
    
    public var hidden: Bool = false
    
    public var contentView: ContentView { didSet { layoutSubviews() } }
    
    public var subviews: [View] {
        
        return [contentView]
    }
    
    public var action: (Button) -> () = { _ in }
    
    // MARK: - Initialization
    
    public init(frame: Rect = Rect(), content: View, mode: ContentMode = ContentMode()) {
        
        self.frame = frame
        self.contentView = ContentView(frame: Rect(size: frame.size), content: content, mode: mode)
    }
    
    // MARK: - Methods
    
    public func hitTest(point: Point) -> View? {
        
        guard hidden == false
            && userInteractionEnabled
            && pointInside(point)
            else { return nil }
        
        // swallows touches intended for subviews
        
        return self
    }
    
    public func handle(event: PointerEvent) {
        
        switch event.input {
            
        case let .Mouse(.Button(buttonEvent)):
            
            if buttonEvent.state == .released {
                
                action(self)
            }
            
        default: break
        }
    }
    
    public func layoutSubviews() {
        
        contentView.frame = Rect(size: frame.size)
        
        contentView.layoutSubviews()
    }
}
