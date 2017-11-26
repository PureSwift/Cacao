//
//  UIPress.swift
//  Cacao
//
//  Created by Alsey Coleman Miller on 6/17/17.
//

import Foundation

/// An object that represents the presence or movement of a button press on the screen for a particular event.
public class UIPress: NSObject {
    
    public let timestamp: TimeInterval
    
    public let phase: UIPressPhase
    
    public let type: UIPressType
    
    public let window: UIWindow?
    
    public let responder: UIResponder?
    
    public let gestureRecognizers: [UIGestureRecognizer]?
    
    // For analog buttons, returns a value between 0 and 1.  Digital buttons return 0 or 1.
    public let force: CGFloat
    
    internal init (timestamp: TimeInterval,
                   phase: UIPressPhase,
                   type: UIPressType,
                   window: UIWindow,
                   responder: UIResponder,
                   gestureRecognizers: [UIGestureRecognizer],
                   force: CGFloat) {
        
        fatalError()
    }
}

// MARK: - Supporting Types

public enum UIPressPhase: Int {
    
    case began // whenever a button press begins.
    
    case changed // whenever a button moves.
    
    case stationary // whenever a buttons was pressed and is still being held down.
    
    case ended // whenever a button is releasd.
    
    case cancelled // whenever a button press doesn't end but we need to stop tracking.
}

public enum UIPressType: Int {
    
    case upArrow
    
    case downArrow
    
    case leftArrow
    
    case rightArrow
    
    case select
    
    case menu
    
    case playPause
}
