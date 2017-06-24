//
//  UIPress.swift
//  Cacao
//
//  Created by Alsey Coleman Miller on 6/17/17.
//

import class Foundation.NSObject
import typealias Foundation.TimeInterval
import struct Foundation.CGFloat

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

/*
extension UIPress: Hashable {
    
    public var hashValue: Int {
        
        return timestamp.hashValue
    }
}*/

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

/// An event that describes the state of a set of physical buttons that are available to the device,
/// such as those on an associated remote or game controller.
public class UIPressesEvent: UIEvent {
    
    /// Returns the state of all physical buttons in the event.
    public internal(set) var allPresses: Set<UIPress> = []
    
    /// Returns the state of all physical buttons in the event that are associated with a particular gesture recognizer.
    public func presses(for gesture: UIGestureRecognizer) -> Set<UIPress> {
        
        return allPresses.filter({ ($0.gestureRecognizers ?? []).contains(where: { $0 === gesture }) })
    }
}

