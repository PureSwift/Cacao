//
//  UIRemoteControlEvent.swift
//  Cacao
//
//  Created by Alsey Coleman Miller on 11/20/17.
//

import Foundation

internal final class UIRemoteControlEvent: UIEvent {
    
    public override var type: UIEventType { return .remoteControl }
    
    
}

extension UIRemoteControlEvent: UIResponderEvent {
    
    @inline(__always)
    func sendEvent(to responder: UIResponder) {
        
        responder.remoteControlReceived(with: self)
    }
}
