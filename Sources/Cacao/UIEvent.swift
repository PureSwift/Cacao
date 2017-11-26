//
//  UIEvent.swift
//  Cacao
//
//  Created by Alsey Coleman Miller on 6/7/17.
//

import typealias Foundation.TimeInterval

/// An object that describes a single user interaction with your app.
public class UIEvent {
    
    // MARK: - Getting the Touches for an Event
    
    /// Returns all touches associated with the event.
    ///
    /// - Returns: A set of `UITouch` objects representing all touches associated with the event.
    public var allTouches: Set<UITouch>? { return nil }
    
    public func touches(for view: UIView) -> Set<UITouch>? {
        
        return Set(allTouches?.filter({ $0.view === view }) ?? [])
    }
    
    public func touches(for window: UIWindow) -> Set<UITouch>? {
        
        return Set(allTouches?.filter({ $0.window === window }) ?? [])
    }
    
    public func touches(for gestureRecognizer: UIGestureRecognizer) -> Set<UITouch>? {
        
        return Set(allTouches?.filter({ $0.gestureRecognizers?.contains(where: { $0 === gestureRecognizer }) ?? false }) ?? [])
    }
    
    // MARK: - Getting Event Attributes
    
    /// The time when the event occurred.
    ///
    /// This property contains the number of seconds that have elapsed since system startup.
    /// For a description of this time value, see the description of the `systemUptime` method of the `ProcessInfo` class.
    public internal(set) var timestamp: TimeInterval
    
    // MARK: - Getting the Event Type
    
    /// Returns the type of the event.
    ///
    /// The UIEventType constant returned by this property indicates the general type of this event—for example,
    /// whether it is a touch or motion event.
    public var type: UIEventType { fatalError("Should override for \(self)") }
    
    /// Returns the subtype of the event.
    ///
    /// The `UIEventSubtype` constant returned by this property indicates the subtype of the event
    /// in relation to the general type, which is returned from the type property.
    public var subtype: UIEventSubtype { return .none }
    
    // MARK: - Initialization
    
    internal init(timestamp: TimeInterval) {
        
        self.timestamp = timestamp
    }
    
    // MARK: - Private Methods
    
    internal func gestureRecognizers(for window: UIWindow) -> Set<UIGestureRecognizer> {
        
        return []
    }
}

// MARK: - CustomStringConvertible

extension UIEvent: CustomStringConvertible {
    
    public var description: String {
        
        return "\(Swift.type(of: self))(timestamp:\(timestamp), touches: \(allTouches ?? []))"
    }
}

// MARK: - Supporting Types

public enum UIEventType: Int {
    
    /// The event is related to touches on the screen.
    case touches // 0x0
    
    /// The event is related to motion of the device, such as when the user shakes it.
    case motion // 0x1
    
    /// The event is a remote-control event.
    ///
    /// Remote-control events originate as commands received from a headset
    /// or external accessory for the purposes of controlling multimedia on the device.
    case remoteControl // 0x2
    
    /// The event is related to the press of a physical button.
    case presses // 0x3
    
    // Private
    
    case physicalKeyboard = 0x4
    case move = 0x5
    
    case wheel = 0x7
    case gameController = 0x8
    case drag = 0x9
}

public enum UIEventSubtype: Int {
    
    case none
    case motionShake
    case remoteControlPlay
    case remoteControlPause
    case remoteControlStop
    case remoteControlTogglePlayPause
    case remoteControlNextTrack
    case remoteControlPreviousTrack
    case remoteControlBeginSeekingBackward
    case remoteControlEndSeekingBackward
    case remoteControlBeginSeekingForward
    case remoteControlEndSeekingForward
    
    
}

// MARK: - Internal

internal protocol UIResponderEvent: class {
    
    func sendEvent(to responder: UIResponder)
}
