//
//  Button.swift
//  Cacao
//
//  Created by Alsey Coleman Miller on 5/28/16.
//  Copyright © 2016 PureSwift. All rights reserved.
//

import Silica

public final class UIButton: UIView {
    
    // MARK: - Methods
    
    public override func hitTest(point: Point) -> UIView? {
        
        guard isHidden == false
            && isUserInteractionEnabled
            && pointInside(point)
            else { return nil }
        
        // swallows touches intended for subviews
        
        return self
    }
    
    /*
    public func handle(event: PointerEvent) {
        
        switch event.input {
            
        case let .mouse(.button(buttonEvent)):
            
            if buttonEvent.state == .released {
                
                action(self)
            }
            
        default: break
        }
    }*/
}
 
