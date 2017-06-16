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

internal extension SDL {
    
    static func poll(event sdlEvent: inout SDL_Event, screen: UIScreen, lastTouch: inout UITouch?, done: inout Bool) {
        
        // poll event queue
        
        var pollEventStatus: Int32 = 0
        
        repeat {
            
            pollEventStatus = SDL_PollEvent(&sdlEvent)
            
            let eventType = SDL_EventType(rawValue: sdlEvent.type)
            
            switch eventType {
                
            case SDL_QUIT, SDL_APP_TERMINATING:
                
                done = true
                
            case SDL_MOUSEBUTTONDOWN, SDL_MOUSEBUTTONUP, SDL_MOUSEMOTION:
                
                mouse(event: &sdlEvent, lastTouch: &lastTouch)
                
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
    
    static func mouse(event sdlEvent: inout SDL_Event, lastTouch: inout UITouch?) {
        
        let eventType = SDL_EventType(rawValue: sdlEvent.type)
        
        guard sdlEvent.button.which != -1
            else { return }
        
        let screenLocation = CGPoint(x: CGFloat(sdlEvent.button.x), y: CGFloat(sdlEvent.button.y))
        
        let timestamp = Double(sdlEvent.button.timestamp) / 1000
        
        let event = UIEvent(timestamp: timestamp)
        
        /// Only the key window can recieve touch input
        guard let window = UIApplication.shared.keyWindow,
            let view = window.hitTest(screenLocation, with: event)
            else { return }
        
        func send(touch phase: UITouchPhase, to view: UIView) {
            
            let touch = UITouch(timestamp: timestamp,
                                location: screenLocation,
                                phase: phase,
                                view: view,
                                window: window)
            
            event.allTouches?.insert(touch)
            
            // inform responder chain
            window.sendEvent(event)
            
            lastTouch = touch
        }
        
        // mouse released
        if eventType == SDL_MOUSEBUTTONUP {
            
            // prevent duplicate events
            if let lastTouch = lastTouch {
                
                guard lastTouch.phase != .ended
                    else { return }
            }
            
            send(touch: .ended, to: view)
            
        } else if let previousTouch = lastTouch,
            previousTouch.phase != .ended {
            
            if previousTouch.location == screenLocation {
                
                send(touch: .stationary, to: view)
                
            } else {
                
                if let previousView = previousTouch.view,
                    previousView != view {
                    
                    send(touch: .ended, to: previousView)
                    send(touch: .began, to: view)
                    
                } else {
                    
                    send(touch: .moved, to: view)
                }
            }
            
        } else if eventType == SDL_MOUSEBUTTONDOWN {
            
            send(touch: .began, to: view)
        }
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
