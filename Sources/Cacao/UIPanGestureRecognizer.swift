//
//  UIPanGestureRecognizer.swift
//  Cacao
//
//  Created by Alsey Coleman Miller on 6/17/17.
//

import Foundation
import Silica

/// A concrete subclass of `UIGestureRecognizer` that looks for panning (dragging) gestures.
open class UIPanGestureRecognizer: UIGestureRecognizer {
    
    // MARK: - Configuring the Gesture Recognizer
    
    /// The maximum number of fingers that can be touching the view for this gesture to be recognized.
    public var maximumNumberOfTouches: Int = .max
    
    /// The minimum number of fingers that can be touching the view for this gesture to be recognized.
    public var minimumNumberOfTouches: Int = 1
    
    // MARK: - Tracking the Location and Velocity of the Gesture
    
    /// The translation of the pan gesture in the coordinate system of the specified view.
    ///
    /// The x and y values report the total translation over time.
    /// They are not delta values from the last time that the translation was reported.
    /// Apply the translation value to the state of the view when the gesture
    /// is first recognized—do not concatenate the value each time the handler is called.
    public func translation(in view: UIView?) -> CGPoint {
        
        return translation
    }
    
    public func velocity(in view: UIView?) -> CGPoint {
        
        return velocity
    }
    
    // MARK: - Private
    
    private var lastMovement: TimeInterval? = nil
    
    private var start: (location: CGPoint, time: TimeInterval)? = nil
    
    private var translation: CGPoint = .zero {
        
        didSet { velocity = .zero }
    }
    
    private var velocity: CGPoint = .zero
    
    private var displacement: CGPoint = .zero
    
    private var movementDuration: TimeInterval = 0
    
    private func validate(event: UIEvent) -> Set<UITouch>? {
        
        guard let gestureTouches = event.touches(for: self),
            gestureTouches.count >= minimumNumberOfTouches,
            gestureTouches.count <= maximumNumberOfTouches
            else { return nil }
        
        return gestureTouches
    }
    
    private func translate(_ delta: CGPoint, with event: UIEvent) -> Bool {
        
        let time = CGFloat(event.timestamp - (lastMovement ?? 0))
        
        guard time > 0, delta != .zero
            else { return false }
        
        translation.x += delta.x
        translation.y += delta.y
        
        velocity.x = delta.x / time
        velocity.y = delta.y / time
        
        lastMovement = event.timestamp
        
        return true
    }
    
    // MARK: - Overridden Methods
    
    open override func reset() {
        super.reset()
        
        translation = .zero
        velocity = .zero
        displacement = .zero
        movementDuration = 0
        lastMovement = nil
        start = nil
    }
    
    open override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent) {
        
        guard let _ = validate(event: event)
            else { return }
        
        self.transition(to: .possible)
        self.lastMovement = event.timestamp
    }
    
    open override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent) {
        
        guard let gestureTouches = validate(event: event)
            else { return }
        
        switch self.state {
            
        case .possible:
            
            self.transition(to: .began)
            self.start = (gestureTouches.center, event.timestamp)
            
            fallthrough
            
        case .began,
             .changed:
            
            let delta = gestureTouches.delta
            
            if translate(delta, with: event) {
                
                // make sure to notify
                if self.transition(to: .changed).notify == false {
                    
                    performActions()
                }
            }
            
        default: break
            
        }
    }
    
    open override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent) {
        
        switch self.state {
            
        case .changed:
            
            let time = event.timestamp - (lastMovement ?? 0)
            
            if time > 0.2 {
                
                self.velocity = .zero
                
            } else {
                
                self.velocity.x = displacement.x / CGFloat(movementDuration > 0 ? movementDuration : 0.001)
                self.velocity.y = displacement.y / CGFloat(movementDuration > 0 ? movementDuration : 0.001)
            }
            
            self.transition(to: .ended)
            
        default:
            
            self.transition(to: .failed)
        }
    }
    
    internal func shouldTryToBegin(with event: UIEvent) {
        
        
    }
    
    internal func willScrollY() {
        
        
    }
}
