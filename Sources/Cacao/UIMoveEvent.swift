//
//  UIMoveEvent.swift
//  Cacao
//
//  Created by Alsey Coleman Miller on 11/20/17.
//

import Foundation

internal final class UIMoveEvent: UIEvent {
    
    public override var type: UIEventType { return .move }
    
    private(set) var focusHeading: UInt = 0
    
    private(set) var moveDirection: Int = 0
}

