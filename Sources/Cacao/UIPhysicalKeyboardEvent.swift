//
//  UIPhysicalKeyboardEvent.swift
//  Cacao
//
//  Created by Alsey Coleman Miller on 11/20/17.
//

import Foundation

internal final class UIPhysicalKeyboardEvent: UIPressesEvent {
    
    public override var type: UIEventType { return .physicalKeyboard }
    
    public private(set) var keyCode: Int = 0
}
