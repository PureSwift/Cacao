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
    
    
}

/// Constants describing the state of a control.
///
/// A control can have more than one state at a time.
/// Controls can be configured differently based on their state.
/// For example, a `UIButton` object can be configured to display one image
/// when it is in its normal state and a different image when it is highlighted.
public struct UIControlState: OptionSet {
    
    public let rawValue: Int
    
    public init(rawValue: Int) {
        
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
