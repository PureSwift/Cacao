//
//  UIMotionEvent.swift
//  Cacao
//
//  Created by Alsey Coleman Miller on 11/26/17.
//

import Foundation

internal final class UIMotionEvent: UIEvent {
    
    public override var type: UIEventType { return .motion }
    
    public private(set) var shakeState: UIMotionEventShakeState
    
    internal func sendEvent(to responder: UIResponder) {
        
        switch shakeState {
            
            
        }
    }
}

internal enum UIMotionEventShakeState: Int {
    
    case began = 0
    case ended = 1
    case cancelled = 2
}
