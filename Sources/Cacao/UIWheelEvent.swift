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
    
    internal init(timestamp: TimeInterval, translation: CGSize) {
        
        self.translation = translation
        
        super.init(timestamp: timestamp)
    }
}

extension UIWheelEvent: UIResponderEvent {
    
    func sendEvent(to responder: UIResponder) {
        
        responder.wheelChanged(with: self)
    }
}
