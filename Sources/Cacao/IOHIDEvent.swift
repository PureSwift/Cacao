//
//  IOHIDEvent.swift
//  Cacao
//
//  Created by Alsey Coleman Miller on 11/24/17.
//

import Foundation
import CSDL2
import SDL

internal struct IOHIDEvent {
    
    let timestamp: UInt
    
    private(set) var data: Data
    
    init?(sdlEvent: inout SDL_Event) {
        
        self.timestamp = UInt(sdlEvent.common.timestamp)
        
        let eventType = SDL_EventType(rawValue: sdlEvent.type)
        
        switch eventType {
            
        case SDL_QUIT, SDL_APP_TERMINATING:
            
            self.data = .quit
            
        case SDL_MOUSEBUTTONDOWN,
             SDL_MOUSEBUTTONUP,
             SDL_MOUSEMOTION:
            
            //guard sdlEvent.touch
            
            let mouseEvent: MouseEvent
            
            switch eventType {
                
            case SDL_MOUSEBUTTONDOWN:
                
                mouseEvent = .down
                
            case SDL_MOUSEBUTTONUP:
                
                mouseEvent = .up
                
            case SDL_MOUSEMOTION:
                
                mouseEvent = .motion
                
            default:
                
                return nil
            }
            
            let screenLocation = CGPoint(x: CGFloat(sdlEvent.button.x),
                                         y: CGFloat(sdlEvent.button.y))
            
            self.data = .mouse(mouseEvent, screenLocation)
            
        case SDL_MOUSEWHEEL:
            
            let translation = CGSize(width: CGFloat(sdlEvent.wheel.x),
                                     height: CGFloat(sdlEvent.wheel.y))
            
            self.data = .mouseWheel(translation)
            
        case SDL_WINDOWEVENT:
            
            let sdlWindowEvent = SDL_WindowEventID(rawValue: SDL_WindowEventID.RawValue(sdlEvent.window.event))
            
            let windowEvent: WindowEvent
            
            switch sdlWindowEvent {
                
            case SDL_WINDOWEVENT_SIZE_CHANGED:
                
                windowEvent = .sizeChange
                
            case SDL_WINDOWEVENT_FOCUS_GAINED,
                 SDL_WINDOWEVENT_FOCUS_LOST:
                
                windowEvent = .focusChange
                
            default:
                
                return nil
            }
            
            self.data = .window(windowEvent)
            
        default:
            
            return nil
        }
    }
    
    /// Merge the data if an event into another
    func merge(event: IOHIDEvent) -> IOHIDEvent? {
        
        switch (self.data, event.data) {
            
        case (.quit, .quit):
            return event
            
        case let (.mouse(lhsMouseEvent, _), .mouse(rhsMouseEvent, _)):
            return lhsMouseEvent == rhsMouseEvent ? event : nil
            
        case (.window(_), .window(_)):
            return nil
            
        case let (.mouseWheel(lhsTranslation), .mouseWheel(rhsTranslation)):
            
            var mergedEvent = event
            
            let size = CGSize(width: lhsTranslation.width + rhsTranslation.width,
                              height: lhsTranslation.height + rhsTranslation.height)
            
            // update data
            mergedEvent.data = .mouseWheel(size)
            
            return mergedEvent
            
        default:
            
            return nil
        }
    }
}

internal extension IOHIDEvent {
    
    enum Data {
        
        case quit
        case mouse(MouseEvent, CGPoint)
        case mouseWheel(CGSize)
        case touch
        case window(WindowEvent)
    }
    
    enum MouseEvent {
        
        case down, up, motion
    }
    
    enum WindowEvent {
        
        case sizeChange
        case focusChange
    }
}
