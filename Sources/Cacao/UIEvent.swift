//
//  UIEvent.swift
//  Cacao
//
//  Created by Alsey Coleman Miller on 5/22/16.
//  Copyright © 2016 PureSwift. All rights reserved.
//

/// Represents an event.
public final class UIEvent {
    
    // MARK: - Properties
    
    /// The time when the event occurred.
    ///
    /// The property value is the number of seconds since app startup.
    public let timestamp: Double
    
    /// All the touches related to this event.
    public let touches: [UITouch]
    
    public let type: UIEventType = .Touches
    
    public let subtype: UIEventSubtype = .None
    
    // MARK: - Initialization
    
    internal init(timestamp: Double, touches: [UITouch]) {
        
        self.timestamp = timestamp
        self.touches = touches
    }
    
    // MARK: - Methods
    
    public func touches(for view: UIView) -> Set<UITouch> {
        
        let filteredTouches = touches.filter { $0.view === view }
        
        return Set(filteredTouches)
    }
    
    public func touches(for window: UIWindow) -> Set<UITouch> {
        
        let filteredTouches = touches.filter { $0.window === window }
        
        return Set(filteredTouches)
    }
}

// MARK: - Supporting Types

public enum UIEventType {
    
    case Touches
    case Motion
    case RemoteControl
    case Presses
}

public enum UIEventSubtype {
    
    public init() { self = .None }
    
    case None
    case MotionShake
    case RemoteControlPlay
    case RemoteControlPause
    case RemoteControlStop
    case RemoteControlTogglePlayPause
    case RemoteControlNextTrack
    case RemoteControlPreviousTrack
    case RemoteControlBeginSeekingBackward
    case RemoteControlEndSeekingBackward
    case RemoteControlBeginSeekingForward
    case RemoteControlEndSeekingForward
}