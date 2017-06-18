//
//  UIPanGestureRecognizer.swift
//  Cacao
//
//  Created by Alsey Coleman Miller on 6/17/17.
//

import struct Foundation.CGFloat
import struct Foundation.CGPoint
import struct Foundation.CGSize
import typealias Foundation.TimeInterval

/// A concrete subclass of `UIGestureRecognizer that looks for panning (dragging) gestures.
public final class UIPanGestureRecognizer: UIGestureRecognizer {
        
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
    
    // MARK: - Internal
    
    private var lastMovement: TimeInterval?
    
    private var startLocation: CGPoint?
    
    private var startTime: TimeInterval?
    
    private var translation: CGPoint = .zero
    
    private var velocity: CGPoint = .zero
    
    private func validate(event: UIEvent) -> Set<UITouch>? {
        
        guard let gestureTouches = event.touches(for: self),
            gestureTouches.count >= minimumNumberOfTouches,
            gestureTouches.count <= maximumNumberOfTouches
            else { return nil }
        
        return gestureTouches
    }
    
    private func update(delta: CGPoint, event: UIEvent) -> Bool {
        
        let time = event.timestamp - (lastMovement ?? 0)
        
        guard time > 0
            else { return false }
        
        translation = delta
        
        
        
        lastMovement = event.timestamp
        
        return true
    }
    
    // MARK: - Overridden Methods
    
    public override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent) {
        
        guard let _ = validate(event: event)
            else { return }
        
        self.state = .possible
        self.lastMovement = event.timestamp
    }
    
    public override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent) {
        
        guard let gestureTouches = validate(event: event)
            else { return }
        
        switch self.state {
            
        case .possible:
            
            self.state = .began
            self.startLocation = gestureTouches.center
            self.startTime = event.timestamp
            
            fallthrough
            
        case .began, .changed:
            
            let delta = gestureTouches.delta
            
            if update(delta: delta, event: event) {
                
                self.state = .changed
                self.performActions()
            }
            
        default: break
            
        }
    }
}
