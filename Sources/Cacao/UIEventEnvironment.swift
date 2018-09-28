//
//  UIEventEnvironment.swift
//  Cacao
//
//  Created by Alsey Coleman Miller on 11/19/17.
//

import Foundation
import CoreFoundation
import SDL
import CSDL2

internal final class UIEventEnvironment {
    
    internal private(set) weak var application: UIApplication!
    
    internal private(set) var eventQueue = [IOHIDEvent]()
    
    internal var commitTimeForTouchEvents: TimeInterval = 0
    
    internal private(set) var touchesEvent: UITouchesEvent?
    
    internal private(set) var physicalKeyboardEvent: UIPhysicalKeyboardEvent?
    
    internal private(set) var wheelEvent: UIWheelEvent?
    
    internal private(set) var gameControllerEvent: UIGameControllerEvent?
    
    internal init(application: UIApplication) {
        
        self.application = application
    }
    
    internal func enqueueHIDEvent(_ event: IOHIDEvent) {
        
        eventQueue.append(event) // prepend
    }
    
    internal func handleEventQueue() {
        
        for hidEvent in eventQueue {
            
            guard let event = event(for: hidEvent)
                else { handleNonUIEvent(hidEvent); continue }
            
            application.sendEvent(event)
        }
        
        if let hidEvent = eventQueue.first {
            
            print("Processed \(eventQueue.count) events (\(SDL_GetTicks() - UInt32(hidEvent.timestamp))ms)")
        }
        
        // clear queue
        eventQueue.removeAll()
    }
    
    private func event(for hidEvent: IOHIDEvent) -> UIEvent? {
        
        let timestamp = Double(hidEvent.timestamp) / 1000
        
        switch hidEvent.data {
            
        case let .touch(mouseEvent, screenLocation):
            
            let event: UITouchesEvent
            
            if let currentEvent = touchesEvent {
                
                event = currentEvent
                
            } else {
                
                event = UITouchesEvent(timestamp: timestamp)
            }
            
            // get UIView touched
            // Only the key window can recieve touch input
            guard let window = UIApplication.shared.keyWindow,
                let view = window.hitTest(screenLocation, with: event)
                else { return nil }
            
            // get UIGestureRecognizer touched
            var gestures = [UIGestureRecognizer]()
            
            var gestureView: UIView? = view
            
            while let view = gestureView {
                
                gestures += (view.gestureRecognizers ?? [])
                
                gestureView = view.superview
            }
            
            let touch: UITouch
            
            if let previousTouch = event.allTouches?.first {
                
                touch = previousTouch
                
                let newPhase: UITouchPhase
                
                assert(previousTouch.phase != .ended, "Did not create new event after touches ended")
                
                // touches ended
                if mouseEvent == .up {
                    
                    newPhase = .ended
                    
                } else {
                    
                    if touch.location == screenLocation {
                        
                        newPhase = .stationary
                        
                    } else {
                        
                        newPhase = .moved
                    }
                }
                
                let internalTouch = UITouch.Touch(location: screenLocation,
                                                  timestamp: timestamp,
                                                  phase: newPhase,
                                                  view: view,
                                                  window: window,
                                                  gestureRecognizers: gestures)
                
                touch.update(internalTouch)
                
            } else {
                
                guard mouseEvent == .down
                    else { return nil }
                
                // new touch sequence
                
                let internalTouch = UITouch.Touch(location: screenLocation,
                                                  timestamp: timestamp,
                                                  phase: .began,
                                                  view: view,
                                                  window: window,
                                                  gestureRecognizers: gestures)
                
                touch = UITouch(touch: internalTouch, inputType: .touchscreen)
                
                event.addTouch(touch)
            }
            
            switch touch.phase {
                
            case .began:
                
                touchesEvent = event
                
            case .moved,
                 .stationary:
                
                touchesEvent?.timestamp = timestamp
                
            case .ended,
                 .cancelled:
                
                touchesEvent = nil
            }
            
            return event
            
        case let .mouseWheel(translation):
            
            let event = UIWheelEvent(timestamp: timestamp, translation: translation)
            
            return event
            
        default:
            
            return nil
        }
    }
    
    private func handleNonUIEvent(_ hidEvent: IOHIDEvent) {
        
        guard let app = self.application
            else { fatalError("\(UIApplication.self) released") }
        
        switch hidEvent.data {
            
        case .quit:
            
            app.quit()
            
        case .lowMemory:
            
            app.lowMemory()
            
        case let .window(windowEvent):
            
            switch windowEvent {
                
            case .sizeChange:
                
                UIScreen.main.updateSize()
                
            case .focusChange:
                
                #if os(Linux)
                    UIScreen.main.needsDisplay = true
                #else
                    break
                #endif
                
            }
            
        default:
            
            break;
        }
    }
}
