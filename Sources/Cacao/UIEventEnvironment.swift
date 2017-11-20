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
    
    private(set) weak var application: UIApplication!
    
    private(set) var eventQueue = [SDL_Event]()
    
    init(application: UIApplication) {
        
        self.application = application
    }
    
    func enqueueHIDEvent(_ event: SDL_Event) {
        
        eventQueue.insert(event, at: 0) // prepend
    }
    
    func handleEventQueue() {
        
        let app = self.application
        
        let queue = self.eventQueue
        
        // create UIEvent from SDL event
        
        guard let event = environment.event(for: sdlEvent) else {
            
            return
        }
        
        
    }
    
    private func event(for sdlEvent: SDL_Event) {
        
        let eventType = SDL_EventType(rawValue: sdlEvent.type)
        
        switch eventType {
            
        case SDL_QUIT, SDL_APP_TERMINATING:
            
            done = true
            
        case SDL_MOUSEBUTTONDOWN, SDL_MOUSEBUTTONUP, SDL_MOUSEMOTION:
            
            mouse()
            
        case SDL_WINDOWEVENT:
            
            let windowEvent = SDL_WindowEventID(rawValue: SDL_WindowEventID.RawValue(sdlEvent.window.event))
            
            switch windowEvent {
                
            case SDL_WINDOWEVENT_SIZE_CHANGED:
                
                screen.updateSize()
                
            case SDL_WINDOWEVENT_FOCUS_GAINED, SDL_WINDOWEVENT_FOCUS_LOST:
                
                #if os(Linux)
                    screen.needsDisplay = true
                #else
                    break
                #endif
                
            default: break
            }
        }
    }
}

private func ___dispatchPreprocessedEventFromEventQueue(sdlEvent: SDL_Event, environment: UIEventEnvironment) {
    
    
}
