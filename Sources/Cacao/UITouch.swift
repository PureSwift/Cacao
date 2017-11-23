//
//  UITouch.swift
//  Cacao
//
//  Created by Alsey Coleman Miller on 6/8/17.
//

import Foundation
import Silica

/// An object representing the location, size, movement, and force of a touch occurring on the screen.
public final class UITouch: NSObject {
    
    internal init(touch: Touch, inputType: InputType) {
        
        self.touches = [touch]
        self.inputType = inputType
        
        super.init()
    }
    
    internal private(set) var touches: [Touch]
        
    internal var previousTouch: Touch? {
        
        guard touches.count >= 2
            else { return nil }
        
        return touches[touches.count - 2]
    }
    
    /// The absolute location, relative to screen.
    internal var location: CGPoint {
        
        return touches.last!.location
    }
    
    internal var delta: CGPoint {
        
        guard let previousLocation = self.previousTouch?.location
            else { return .zero }
        
        let location = self.location
        
        return CGPoint(x: location.x - previousLocation.x,
                       y: location.y - previousLocation.y)
    }
    
    internal func update(_ touch: Touch) {
        
        touches.append(touch)
    }
    
    // MARK: - Getting the Location of a Touch
    
    // Cacao Extension
    public let inputType: InputType
    
    /// The view to which touches are being delivered, if any.
    public var view: UIView? { return touches.last?.view }
    
    /// The window in which the touch initially occurred.
    public var window: UIWindow? { return touches.last?.window }
    
    /// The gesture recognizers that are receiving the touch object.
    public var gestureRecognizers: [UIGestureRecognizer]? { return touches.last?.gestureRecognizers }
    
    /// The phase of the touch.
    public var phase: UITouchPhase { return touches.last!.phase }
    
    /// The time when the touch occurred.
    public var timestamp: TimeInterval { return touches.last!.timestamp }
    
    /// Returns the current location of the receiver in the coordinate system of the given view.
    ///
    /// - Parameter view: The view object in whose coordinate system you want the touch located.
    /// A custom view that is handling the touch may specify self to get the touch location
    /// in its own coordinate system. Pass `nil` to get the touch location in the window’s coordinates.
    ///
    /// This method returns the current location of a UITouch object in the coordinate system of the specified view.
    /// Because the touch object might have been forwarded to a view from another view,
    /// this method performs any necessary conversion of the touch location to the coordinate system of the specified view.
    public func location(in view: UIView? = nil) -> CGPoint {
        
        let view = view ?? touches.last!.window
        
        return view.convert(location, to: view)
    }
    
    /// Returns the previous location of the receiver in the coordinate system of the given view.
    public func previousLocation(in view: UIView? = nil) -> CGPoint {
        
        guard let previousTouch = self.previousTouch
            else { return .zero }
        
        let view = view ?? previousTouch.window // should always be same window
        
        return view.convert(previousTouch.location, to: view)
    }
    
    // MARK: - CustomStringConvertible
    
    public override var description: String {
        
        return "\(Swift.type(of: self))(timestamp: \(timestamp), location: \(location), phase: \(phase))"
    }
}

// MARK: - Supporting Types

public enum UITouchPhase: Int {
    
    /// A finger for a given event touched the screen.
    case began
    
    /// A finger for a given event moved on the screen.
    case moved
    
    /// A finger is touching the surface but hasn't moved since the previous event.
    case stationary
    
    /// A finger for a given event was lifted from the screen.
    case ended
    
    ///  The system canceled tracking for the touch, as when (for example) the user moves the device against his or her face.
    case cancelled
}

// MARK: - Internal

public extension UITouch {
    
    public enum InputType {
        
        case touchscreen
        case mouse
    }
}

internal extension UITouch {
    
    final class Touch {
        
        /// The absolute location, relative to screen.
        let location: CGPoint
        
        /// The time when the touch occurred.
        let timestamp: TimeInterval
        
        /// The phase of the touch.
        let phase: UITouchPhase
        
        /// The view to which touches are being delivered, if any.
        let view: UIView
        
        /// The window in which the touch initially occurred.
        let window: UIWindow
        
        /// The gesture recognizers that are receiving the touch object.
        let gestureRecognizers: [UIGestureRecognizer]
        
        init(location: CGPoint, timestamp: TimeInterval, phase: UITouchPhase, view: UIView, window: UIWindow, gestureRecognizers: [UIGestureRecognizer]) {
            
            self.location = location
            self.timestamp = timestamp
            self.phase = phase
            self.view = view
            self.window = window
            self.gestureRecognizers = gestureRecognizers
        }
    }
}

internal extension Array where Element == CGPoint {
    
    var center: CGPoint {
        
        guard self.isEmpty == false
            else { return .zero }
        
        let combinedPoint = self.reduce(CGPoint(), { CGPoint(x: $0.x + $1.x, y: $0.y + $1.y) })
        
        return CGPoint(x: combinedPoint.x / CGFloat(self.count),
                       y: combinedPoint.y / CGFloat(self.count))
    }
}

internal extension Set where Element == UITouch {
    
    var center: CGPoint {
        
        return self.map({ $0.location }).center
    }
    
    var delta: CGPoint {
                
        return self.map({ $0.delta }).center
    }
}
