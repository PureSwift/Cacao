//
//  UIGestureEnvironment.swift
//  Cacao
//
//  Created by Alsey Coleman Miller on 11/19/17.
//

import Foundation

internal final class UIGestureEnvironment {
    
    private(set) var gestureRecognizers = Set<UIGestureRecognizer>()
    
    private(set) var gestureRecognizersNeedingUpdate = Set<UIGestureRecognizer>()
    
    init() {
        
    }
    
    internal func addGestureRecognizer(_ gestureRecognizer: UIGestureRecognizer) {
        
        gestureRecognizers.insert(gestureRecognizer)
    }
    
    internal func updateGestures(for event: UIEvent, window: UIWindow) {
        
        let gestureRecognizers = event.gestureRecognizers(for: window)
        
        if let touchesEvent = event as? UITouchesEvent {
            
            deliver(event: touchesEvent, to: gestureRecognizers) { (gestureRecognizer) in
                /*
                if gestureRecognizer.state.rawValue <= UIGestureRecognizerState.changed.rawValue {
                    
                    
                }*/
                
                return true
            }
            
        } else if let pressesEvent = event as? UIPressesEvent {
            
            deliver(event: pressesEvent, to: gestureRecognizers) { (gestureRecognizer) in
                
                return true
            }
        }
    }
    
    private func deliver<Event: UIEvent>(event: Event, to gestureRecognizers: Set<UIGestureRecognizer>, using block: (UIGestureRecognizer) -> (Bool)) {
        
        gestureRecognizers.forEach {
            
            if block($0) {
                
                markDirty($0)
                setGestureNeedsUpdate($0)
            }
        }
        
        if hasGesturesNeedingUpdate {
            
            update()
        }
    }
    
    private func markDirty(_ gesture: UIGestureRecognizer) {
        
        
    }
    
    private func setGestureNeedsUpdate(_ gesture: UIGestureRecognizer) {
        
        if gesture.view != nil {
            
            gestureRecognizersNeedingUpdate.insert(gesture)
            
        } else {
            
            clearGestureNeedsUpdate(gesture)
        }
    }
    
    @inline(__always)
    private func clearGestureNeedsUpdate(_ gesture: UIGestureRecognizer) {
        
        gestureRecognizersNeedingUpdate.remove(gesture)
    }
    
    private func queueGestureRecognizersForResetIfFinished() {
        
        
    }
    
    private var hasGesturesNeedingUpdate: Bool {
        
        @inline(__always)
        get { return gestureRecognizersNeedingUpdate.isEmpty == false }
    }
    
    private func update() {
        
        if let event = UIApplication.shared.touchesEvent {
            
            for gesture in gestureRecognizersNeedingUpdate {
                
                let touches = event.touches(for: gesture) ?? []
                
                let gestureRecognizers = touches.reduce([UIGestureRecognizer](), { $0 + ($1.gestureRecognizers ?? []) })
                
                // handle gestures
                
                for gesture in gestureRecognizers {
                    
                    guard gesture.shouldRecognize
                        else { continue }
                    
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
        }
    }
}
