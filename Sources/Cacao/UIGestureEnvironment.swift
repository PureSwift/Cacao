//
//  UIGestureEnvironment.swift
//  Cacao
//
//  Created by Alsey Coleman Miller on 11/19/17.
//

import Foundation

internal final class UIGestureEnvironment {
    
    init() { }
    
    internal func updateGestures(for event: UIEvent, window: UIWindow) {
        
        let gestureRecognizers = event.gestureRecognizers(for: window)
        
        if let touchesEvent = event as? UITouchesEvent {
            
            deliver(event: touchesEvent, to: gestureRecognizers)
            
        } else if let pressesEvent = event as? UIPressesEvent {
            
            deliver(event: pressesEvent, to: gestureRecognizers)
        }
    }
    
    private func deliver(event: UIEvent,
                         to gestureRecognizers: Set<UIGestureRecognizer>,
                         using block: (UIGestureRecognizer) -> (Bool) = { _ in return true }) {
        
        gestureRecognizers.forEach {
            
            if block($0) {
                update(gesture: $0, with: event)
            }
        }
    }
    
    private func update(gesture: UIGestureRecognizer, with event: UIEvent) {
        
        // handle touches
        guard gesture.shouldRecognize
            else { return }
        
        let touches = event.touches(for: gesture) ?? []
        
        gesture.touches = touches.sorted(by: { $0.timestamp < $1.timestamp })
        
        for touch in touches {
            
            switch touch.phase {
            case .began: gesture.touchesBegan(touches, with: event)
            case .moved: gesture.touchesMoved(touches, with: event)
            case .stationary: break
            case .ended: gesture.touchesEnded(touches, with: event)
            case .cancelled: gesture.touchesCancelled(touches, with: event)
            }
        }
    }
}
