//
//  UIWheelEvent.swift
//  Cacao
//
//  Created by Alsey Coleman Miller on 11/20/17.
//

import Foundation

public final class UIWheelEvent: UIEvent {
    
    public override var type: UIEventType { return .wheel }
    
    public let translation: CGSize
    
    
}
