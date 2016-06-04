//
//  Event.swift
//  Cacao
//
//  Created by Alsey Coleman Miller on 5/27/16.
//  Copyright © 2016 PureSwift. All rights reserved.
//

import Silica
import CSDL2

// MARK: - Pointer Event

/// Events related to pointer input (e.g. Mouse, Touch Screen).
public struct PointerEvent {
    
    public let timestamp: UInt32
    
    public let screenLocation: Point
    
    public let input: PointerInput
}

public enum PointerInput {
    
    case Mouse(MouseEvent)
    case Finger
}

// MARK: - Mouse

public enum MouseEvent {
    
    case Button(MouseButtonEvent)
    case Motion
    case Wheel
}

public struct MouseButtonEvent {
    
    public let button: MouseButton
    
    public let state: ButtonState
    
    public let clicks: Int
}

public enum MouseButton {
    
    case left, right, middle
    
    internal init?(_ sdlValue: UInt8) {
        
        switch CInt(sdlValue) {
            
        case SDL_BUTTON_LEFT: self = .left
        case SDL_BUTTON_RIGHT: self = .right
        case SDL_BUTTON_MIDDLE: self = .middle
            
        default: return nil
        }
    }
}

public enum ButtonState {
    
    case pressed, released
    
    internal init?(_ sdlValue: UInt8) {
        
        switch sdlValue {
            
        case 0: self = .released
        case 1: self = .pressed
            
        default: return nil
        }
    }
}
    
// MARK: - SDL Conversion

public extension PointerEvent {
    
    internal init(_ sdlEvent: SDL_MouseButtonEvent) {
        
        self.timestamp = sdlEvent.timestamp
        self.screenLocation = Point(x: Double(sdlEvent.x), y: Double(sdlEvent.y))
        
        self.input = .Mouse(.Button(MouseButtonEvent(button: MouseButton(sdlEvent.button)!,
                                                     state: ButtonState(sdlEvent.state)!,
                                                     clicks: Int(sdlEvent.clicks))))
    }
}
