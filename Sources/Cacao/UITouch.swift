//
//  UITouch.swift
//  Cacao
//
//  Created by Alsey Coleman Miller on 5/22/16.
//  Copyright © 2016 PureSwift. All rights reserved.
//

import Silica

/// Represents the location, size, movement, and force of a finger on the screen for a particular event.
///
/// - Note: A touch object persists throughout a multi-touch sequence.
/// Never retain a touch object when handling an event. 
/// If you need to keep information about a touch from one touch phase to another, copy that information from the touch.
public final class UITouch {
    
    /// The time when the touch occurred or when it was last mutated.
    ///
    /// The property value is the number of seconds since app startup.
    public internal(set) var timestamp: Double
    
    /// The view to which touches are being delivered.
    public let view: UIView
    
    /// The window in which the touch initially occurred.
    public let window: UIWindow
    
    public internal(set) var tapCount: Int = 0
    
    public internal(set) var phase: UITouchPhase
    
    // MARK: - Internal Properties
    
    internal var windowLocation: Point
    
    // MARK: - Initialization
    
    internal init(timestamp: Double, view: UIView, window: UIWindow, phase: UITouchPhase, windowLocation: Point) {
        
        self.timestamp = timestamp
        self.view = view
        self.window = window
        self.phase = phase
        self.windowLocation = windowLocation
    }
    
    // MARK: - Methods
    
    
}

// MARK: - Hashable

extension UITouch: Hashable {
    
    public var hashValue: Int {
        
        /// not a real hashValue, but initializer is internal so we dont care
        return Int(timestamp)
    }
}

// MARK: - Equatable

public func == (lhs: UITouch, rhs: UITouch) -> Bool {
    
    /// touches are unique, don't compare values, but identity
    return lhs === rhs
}

// MARK: - Supporting Types

public enum UITouchPhase {
    
    case Began
    case Moved
    case Stationary
    case Ended
    case Cancelled
}
