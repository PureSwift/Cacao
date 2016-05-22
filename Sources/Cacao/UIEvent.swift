//
//  UIEvent.swift
//  Cacao
//
//  Created by Alsey Coleman Miller on 5/22/16.
//  Copyright © 2016 PureSwift. All rights reserved.
//

public struct UIEvent {
    
    /// The time when the event occurred.
    ///
    /// The property value is the number of seconds since system startup.
    public let timestamp: Double
    
    public var touches: [UITouch]
}

// MARK: - Supporting Types

public enum UIEventType: Int {
    
    case Touches
    case Motion
    case RemoteControl
    case Presses
}

public enum UIEventSubtype: Int {
    
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