//
//  UIPhysicalKeyboardEvent.swift
//  Cacao
//
//  Created by Alsey Coleman Miller on 11/20/17.
//

import Foundation

internal final class UIPhysicalKeyboardEvent: UIPressesEvent {
    
    public override var type: UIEventType { return .physicalKeyboard }
    
    //public let keyCode: Int
    
    //public let isKeyDown: Bool
    
}

extension UIPhysicalKeyboardEvent {
    
    enum State {
        
        case pressed
        case released
    }
}
