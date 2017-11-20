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
    
    internal private(set) var eventQueue = [SDL_Event]()
    
    internal var commitTimeForTouchEvents: TimeInterval = 0
    
    internal private(set) var touchesEvent: UITouchesEvent?
    
    internal private(set) var physicalKeyboardEvent: UIPhysicalKeyboardEvent?
    
    internal init(application: UIApplication) {
        
        self.application = application
    }
    
    internal func enqueueHIDEvent(_ event: SDL_Event) {
        
        eventQueue.insert(event, at: 0) // prepend
    }
    
    internal func handleEventQueue() {
        
        for sdlEvent in eventQueue {
            
            guard let event = event(for: sdlEvent)
                else { handleNonUIEvent(sdlEvent); continue }
            
            
        }
        
        // clear queue
        eventQueue.removeAll()
    }
    
    private func event(for sdlEvent: SDL_Event) -> UIEvent? {
        
        let eventType = SDL_EventType(rawValue: sdlEvent.type)
        
        switch eventType {
            
        case SDL_MOUSEBUTTONDOWN, SDL_MOUSEBUTTONUP, SDL_MOUSEMOTION:
            
            return mouseEvent(for: sdlEvent)
        
        default:
            
            return nil
        }
    }
    
    private func mouseEvent(for sdlEvent: SDL_Event) -> UIEvent? {
        
        let eventType = SDL_EventType(rawValue: sdlEvent.type)
        
        // FIXME: Implement tablet touch event
        guard sdlEvent.button.which != -1
            else { return nil }
        
        let screenLocation = CGPoint(x: CGFloat(sdlEvent.button.x),
                                     y: CGFloat(sdlEvent.button.y))
        
        let timestamp = Double(sdlEvent.button.timestamp) / 1000
        
        let event: UITouchesEvent
        
        if let currentEvent = touchesEvent {
            
            event = currentEvent
            
        } else {
            
            event = UITouchesEvent(timestamp: timestamp)
        }
        
        /// Only the key window can recieve touch input
        guard let window = UIApplication.shared.keyWindow,
            let view = window.hitTest(screenLocation, with: event)
            else { return nil }
        
        let touch: UITouch
        
        if let previousTouch = event.allTouches?.first {
            
            touch = previousTouch
            
            let newPhase: UITouchPhase
            
            assert(previousTouch.phase != .ended, "Did not create new event after touches ended")
            
            // touches ended
            if eventType == SDL_MOUSEBUTTONUP {
                
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
                                              gestureRecognizers: view.gestureRecognizers ?? [])
            
            touch.update(internalTouch)
            
        } else {
            
            guard eventType == SDL_MOUSEBUTTONDOWN
                else { return nil }
            
            // new touch sequence
            
            let internalTouch = UITouch.Touch(location: screenLocation,
                                              timestamp: timestamp,
                                              phase: .began,
                                              view: view,
                                              window: window,
                                              gestureRecognizers: view.gestureRecognizers ?? [])
            
            touch = UITouch(internalTouch)
            
            event.addTouch(touch)
        }
        
        switch touch.phase {
            
        case .began:
            
            touchesEvent = event
            
        case .moved, .stationary:
            
            touchesEvent?.timestamp = timestamp
            
        case .ended, .cancelled:
            
            touchesEvent = nil
        }
        
        return event
    }
    
    private func handleNonUIEvent(_ sdlEvent: SDL_Event) {
        
        guard let app = self.application
            else { fatalError("\(UIApplication.self) released") }
        
        let eventType = SDL_EventType(rawValue: sdlEvent.type)
        
        switch eventType {
            
        case SDL_QUIT, SDL_APP_TERMINATING:
            
            app.quit()
            
        case SDL_WINDOWEVENT:
            
            let windowEvent = SDL_WindowEventID(rawValue: SDL_WindowEventID.RawValue(sdlEvent.window.event))
            
            switch windowEvent {
                
            case SDL_WINDOWEVENT_SIZE_CHANGED:
                
                UIScreen.main.updateSize()
                
            case SDL_WINDOWEVENT_FOCUS_GAINED, SDL_WINDOWEVENT_FOCUS_LOST:
                
                #if os(Linux)
                    UIScreen.main.needsDisplay = true
                #else
                    break
                #endif
                
            default: break
            }
            
        default:
            
            break;
        }
    }
}
