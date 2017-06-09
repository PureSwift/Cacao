//
//  UIControl.swift
//  Cacao
//
//  Created by Alsey Coleman Miller on 6/7/17.
//

/// The base class for controls, which are visual elements that convey
/// a specific action or intention in response to user interactions.
open class UIControl: UIView {
    
    // MARK: - Configuring the Control’s Attributes
    
    /// The state of the control, specified as a bitmask value.
    ///
    /// The value of this property is a bitmask of the constants in the UIControlState type.
    /// A control can be in more than one state at a time.
    /// For example, it can be focused and highlighted at the same time.
    /// You can also get the values for individual states using the properties of this class.
    open var state: UIControlState { return .normal }
    
    // MARK: - Accessing the Control’s Targets and Actions
    
    /// Target-Action pairs
    private var targetActions: [Selector]
    
    /// Associates a target object and action method with the control.
    public func addTarget<Target>(_ target: Target, action: Selector, for controlEvents: UIControlEvents)
        where Target: AnyObject, Target: Hashable {
        
        
    }
    
    /// Stops the delivery of events to the specified target object.
    public func removeTarget<Target>(_ target: Target, action: Selector, for controlEvents: UIControlEvents)
        where Target: AnyObject, Target: Hashable {
        
        
    }
    
    ///
    /// - Parameter target: The target object—that is, an object that has an action method associated with this control.
    /// You must pass an explicit object for this method to return a meaningful result.
    /// Specifying `nil` always returns `nil`.
    /// - Parameter controlEvent: A single control event constant representing the event
    /// for which you want the list of action methods.
    /// For a list of possible constants, see `UIControlEvents`.
    public func actions(forTarget target: Any?, forControlEvent controlEvent: UIControlEvents) -> [String]? {
        
        guard let target = target
            else { return nil }
        
        
    }
}

/// Cacao extension since Swift doesn't support ObjC runtime (on non-Darwin platforms)
public struct Selector {
    
    public let action: (_ sender: AnyObject?) -> ()
    
    public let name: String
}

extension Selector

/// Constants describing the state of a control.
///
/// A control can have more than one state at a time.
/// Controls can be configured differently based on their state.
/// For example, a `UIButton` object can be configured to display one image
/// when it is in its normal state and a different image when it is highlighted.
public struct UIControlState: OptionSet {
    
    public let rawValue: Int
    
    public init(rawValue: Int = 0) {
        
        self.rawValue = rawValue
    }
    
    /// The normal, or default state of a control—that is, enabled but neither selected nor highlighted.
    public static let normal = UIControlState(rawValue: 0)
    
    public static let highlighted = UIControlState(rawValue: 1 << 0)
    
    public static let disabled = UIControlState(rawValue: 1 << 1)
    
    public static let selected = UIControlState(rawValue: 1 << 2)
    
    public static let focused = UIControlState(rawValue: 1 << 3)
    
    public static let application = UIControlState(rawValue: 0x00FF0000)
}

public struct UIControlEvents: OptionSet {
    
    public let rawValue: Int
    
    public init(rawValue: Int = 0) {
        
        self.rawValue = rawValue
    }
}
