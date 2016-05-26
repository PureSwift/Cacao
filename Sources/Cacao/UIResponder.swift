//
//  UIResponder.swift
//  Cacao
//
//  Created by Alsey Coleman Miller on 5/15/16.
//  Copyright © 2016 PureSwift. All rights reserved.
//

import Silica

public protocol UIResponder: class {
    
    // MARK: First Responder
    
    /// The next object in the responder chain to be presented with an event for handling.
    var nextResponder: UIResponder? { get }
    
    /// Whether the receiver is the first responder.
    var firstResponder: Bool { get }
    
    func canBecomeFirstResponder() -> Bool
    
    func becomeFirstResponder() -> Bool
    
    /// Notifies the receiver that it has been asked to relinquish its status as first responder in its window.
    func resignFirstResponder() -> Bool
    
    // MARK: Touches
    
    func touchesBegan(touches: Set<UITouch>, with event: UIEvent)
    
    func touchesMoved(touches: Set<UITouch>, with event: UIEvent)
    
    func touchesEnded(touches: Set<UITouch>, with event: UIEvent)
}

// MARK: - Implementation

public extension UIResponder {
    
    var nextResponder: UIResponder? { return nil }
    
    var firstResponder: Bool { return false }
    
    func canBecomeFirstResponder() -> Bool { return false }
    
    func canResignFirstResponder() -> Bool { return true }
    
    func becomeFirstResponder() -> Bool { return true }
    
    func resignFirstResponder() -> Bool { return true }
    
    func touchesBegan(touches: Set<UITouch>, with event: UIEvent) { }
    
    func touchesMoved(touches: Set<UITouch>, with event: UIEvent) { }
    
    func touchesEnded(touches: Set<UITouch>, with event: UIEvent) { }
}