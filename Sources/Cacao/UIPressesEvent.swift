//
//  UIPressesEvent.swift
//  Cacao
//
//  Created by Alsey Coleman Miller on 11/26/17.
//

import Foundation

/// An event that describes the state of a set of physical buttons that are available to the device,
/// such as those on an associated remote or game controller.
public class UIPressesEvent: UIEvent {
    
    /// Returns the state of all physical buttons in the event.
    public internal(set) var allPresses: Set<UIPress> = []
    
    public private(set) var triggeringPhysicalButton: UIPress?
    
    /// Returns the state of all physical buttons in the event that are associated with a particular gesture recognizer.
    public func presses(for gesture: UIGestureRecognizer) -> Set<UIPress> {
        
        return Set(allPresses.filter({ ($0.gestureRecognizers ?? []).contains(where: { $0 === gesture }) }))
    }
    
    internal func physicalButtons(for window: UIWindow) -> Set<UIPress> {
        
        return Set(allPresses.filter({ $0.window === window }))
    }
    
    internal func responders(for window: UIWindow) -> Set<UIResponder> {
        
        return Set(allPresses.flatMap({ $0.responder }))
    }
    
    internal func physicalButtons(for responder: UIResponder) -> Set<UIPress> {
        
        return Set(allPresses.filter({ $0.responder === responder }))
    }
    
    internal func physicalButtons(for responder: UIResponder, with phase: UIPressPhase) -> Set<UIPress> {
        
        return Set(allPresses.filter({ $0.responder === responder && $0.phase == phase }))
    }
}
