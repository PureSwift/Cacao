//
//  SDL.swift
//  Cacao
//
//  Created by Alsey Coleman Miller on 6/7/17.
//

import struct Foundation.CGFloat
import struct Foundation.CGPoint
import struct Foundation.CGSize
import struct Foundation.CGRect
import CSDL2
import SDL

// MARK: - Events

internal final class SDLEventPoller {
    
    let screen: UIScreen
    
    private(set) var done: Bool = false
    
    private(set) var sdlEvent = SDL_Event()
    
    private(set) var mouseEvent: UIEvent?
    
    init(screen: UIScreen) {
        
        self.screen = screen
    }
    
    func poll() {
        
        // poll event queue
        
        var pollEventStatus: Int32 = 0
        
        repeat {
            
            pollEventStatus = SDL_PollEvent(&sdlEvent)
            
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
                
            default: break
            }
            
        } while pollEventStatus != 0
    }
    
    private func mouse() {
        
        let eventType = SDL_EventType(rawValue: sdlEvent.type)
        
        guard sdlEvent.button.which != -1
            else { return }
        
        let screenLocation = CGPoint(x: CGFloat(sdlEvent.button.x),
                                     y: CGFloat(sdlEvent.button.y))
        
        let timestamp = Double(sdlEvent.button.timestamp) / 1000
        
        let event: UIEvent
        
        if let currentEvent = mouseEvent {
            
            event = currentEvent
            
        } else {
            
            event = UIEvent(timestamp: timestamp)
        }
        
        /// Only the key window can recieve touch input
        guard let window = UIApplication.shared.keyWindow,
            let view = window.hitTest(screenLocation, with: event)
            else { return }
        
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
                else { return }
            
            // new touch sequence
            
            let internalTouch = UITouch.Touch(location: screenLocation,
                                              timestamp: timestamp,
                                              phase: .began,
                                              view: view,
                                              window: window,
                                              gestureRecognizers: view.gestureRecognizers ?? [])
            
            touch = UITouch(internalTouch)
            
            event.touches = [touch]
        }
        
        switch touch.phase {
            
        case .began:
            
            mouseEvent = event
            
        case .moved, .stationary:
            
            mouseEvent?.timestamp = timestamp
            
        case .ended, .cancelled:
            
            mouseEvent = nil
        }
        
        // inform responder chain
        window.sendEvent(event)
    }
}

// MARK: - Assertions

internal extension Bool {
    
    @inline(__always)
    func sdlAssert(function: String = #function, file: StaticString = #file, line: UInt = #line) {
        
        guard self else { sdlFatalError(function: function, file: file, line: line) }
    }
}

internal extension Optional {
    
    @inline(__always)
    func sdlAssert(function: String = #function, file: StaticString = #file, line: UInt = #line) -> Wrapped {
        
        guard let value = self
            else { sdlFatalError(function: function, file: file, line: line) }
        
        return value
    }
}

@_silgen_name("_cacao_sdl_fatal_error")
internal func sdlFatalError(function: String = #function, file: StaticString = #file, line: UInt = #line) -> Never {
    
    if let error = SDL.errorDescription {
        
        fatalError("SDL error: \(error)", file: file, line: line)
        
    } else {
        
        fatalError("An SDL error occurred", file: file, line: line)
    }
}
