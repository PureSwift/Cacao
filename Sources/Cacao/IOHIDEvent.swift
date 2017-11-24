//
//  IOHIDEvent.swift
//  Cacao
//
//  Created by Alsey Coleman Miller on 11/24/17.
//

import Foundation
import CSDL2
import SDL

internal final class IOHIDEvent {
    
    let sdlEvent: SDL_Event
    
    init(sdlEvent: SDL_Event) {
        
        self.sdlEvent = sdlEvent
    }
}
