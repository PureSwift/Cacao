//
//  UIMotionEvent.swift
//  Cacao
//
//  Created by Alsey Coleman Miller on 11/26/17.
//

import Foundation

internal final class UIMotionEvent: UIEvent {
    
    public override var type: UIEventType { return .motion }
    
    public private(set) var shakeState: UIMotionEventShakeState = .began
    
    public override var subtype: UIEventSubtype { return .motionShake }
    
    override init(timestamp: TimeInterval) {
                
        super.init(timestamp: timestamp)
    }
}

internal enum UIMotionEventShakeState: Int {
    
    case began = 0
    case ended = 1
    case cancelled = 2
}

extension UIMotionEvent: UIResponderEvent {
    
    func sendEvent(to responder: UIResponder) {
        
        switch shakeState {
        case .began: responder.motionBegan(subtype, with: self)
        case .ended: responder.motionEnded(subtype, with: self)
        case .cancelled: responder.motionCancelled(subtype, with: self)
        }
    }
}
