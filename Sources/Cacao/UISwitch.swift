//
//  UISwitch.swift
//  Cacao
//
//  Created by Alsey Coleman Miller on 6/15/17.
//

import struct Foundation.CGFloat
import struct Foundation.CGPoint
import struct Foundation.CGSize
import struct Foundation.CGRect
import Silica

/// A control that offers a binary choice, such as On/Off.
///
/// The `UISwitch` class declares a property and a method to control its on/off state.
open class UISwitch: UIControl {
    
    // MARK: - Initializing the Switch Object
    
    public override init(frame: CGRect) {
        super.init(frame: frame)
        
        
    }
    
    // MARK: - Setting the Off/On State
    
    /// A Boolean value that determines the off/on state of the switch.
    ///
    /// This property allows you to retrieve and set (without animation) a value
    /// determining whether the `UISwitch` object is on or off.
    public var isOn: Bool {
        get { return _on }
        set { setOn(newValue, animated: false) }
    }
    private var _on: Bool = false
    
    /// Set the state of the switch to On or Off, optionally animating the transition.
    ///
    /// - Note: Setting the switch to either position does not result in an action message being sent.
    public func setOn(_ on: Bool, animated: Bool) {
        
        _on = on
    }
    
    // MARK: - Customizing the Appearance of the Switch
    
    /// The color used to tint the appearance of the switch when it is turned on.
    public var onTintColor: UIColor?
    
    /// The color used to tint the outline of the switch when it is turned off.
    // var tintColor: UIColor!
    
    /// The color used to tint the appearance of the thumb.
    public var thumbTintColor: UIColor?
    
    /// The image displayed when the switch is in the on position.
    public var onImage: UIImage?
    
    /// The image displayed while the switch is in the off position.
    public var offImage: UIImage?
    
    // MARK: - Private
    
    
}
