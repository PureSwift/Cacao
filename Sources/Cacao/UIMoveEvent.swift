//
//  UIMoveEvent.swift
//  Cacao
//
//  Created by Alsey Coleman Miller on 11/20/17.
//

import Foundation

public final class UIMoveEvent: UIEvent {
    
    public override var type: UIEventType { return .move }
    
    public private(set) var focusHeading: UInt = 0
    
    public private(set) var moveDirection: Int = 0
}

extension UIMoveEvent: UIResponderEvent {
    
    @inline(__always)
    func sendEvent(to responder: UIResponder) {
        
        responder.move(with: self)
    }
}
