//
//  UITouchesEvent.swift
//  Cacao
//
//  Created by Alsey Coleman Miller on 11/19/17.
//

import Foundation

internal final class UITouchesEvent: UIEvent {
    
    public override var type: UIEventType { return .touches }
    
    public override var allTouches: Set<UITouch>? { return touches }
    
    internal var touches = Set<UITouch>()
    
    
}
