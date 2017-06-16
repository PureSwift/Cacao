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
    
    /// Constant size
    private static let size = CGSize(width: 51, height: 31)
    
    // MARK: - Initializing the Switch Object
    
    public override init(frame: CGRect) {
        
        let frame = CGRect(origin: frame.origin, size: UISwitch.size)
        
        super.init(frame: frame)
        
        self.tintColor = UISwitchStyleKit.defaultOnColor
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
        
        setOn(on, animated: animated)
    }
    
    private func setOn(_ on: Bool, tapped: Bool, animated: Bool) {
        
        _on = on
        
        let phase = Phase(on: on, tapped: tapped)
        internalState = State(phase, tintColor: tintColor, onTintColor: onTintColor, thumbTintColor: thumbTintColor)
        
        setNeedsDisplay()
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
    
    // MARK: - Drawing
    
    open override func draw(_ rect: CGRect) {
        
        UISwitchStyleKit.drawSwitchView(frame: bounds,
                                        resizing: .center,
                                        thumbColor: UIColor(cgColor: internalState.thumbColor),
                                        fillColor: UIColor(cgColor: internalState.fillColor),
                                        switchOn: internalState.on,
                                        tapped: internalState.tapped)
    }
    
    // MARK: - Events
    
    open override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        
        setOn(self.isOn, tapped: true, animated: true)
    }
    
    // MARK: - Private
    
    private var internalState = State(.off)
}

// MARK: - Supporting Types

private extension UISwitch {
    
    enum Phase {
        case off
        case on
        case tapped(on: Bool)
        
        init(on: Bool = false, tapped: Bool = false) {
            if tapped {
                self = .tapped(on: on)
            } else {
                self = on ? .on : .off
            }
        }
    }
    
    struct State {
        
        var on: CGFloat
        var tapped: CGFloat
        var fillColor: CGColor
        var thumbColor: CGColor
        
        init(_ phase: Phase,
             tintColor: UIColor? = nil,
             onTintColor: UIColor? = nil,
             thumbTintColor: UIColor? = nil) {
            
            self.thumbColor = thumbTintColor?.cgColor ?? UISwitchStyleKit.defaultThumbColor.cgColor
            
            switch phase {
                
            case .off:
                self.on = 0
                self.tapped = 0
                self.fillColor = tintColor?.cgColor ?? UISwitchStyleKit.defaultStrokeColor.cgColor
                
            case .tapped(on: false):
                self.on = 0
                self.tapped = 1
                self.fillColor = tintColor?.cgColor ?? UISwitchStyleKit.defaultStrokeColor.cgColor
                
            case .on:
                self.on = 1
                self.tapped = 0
                self.fillColor = onTintColor?.cgColor ?? UISwitchStyleKit.defaultOnColor.cgColor
                
            case .tapped(on: true):
                self.on = 1
                self.tapped = 1
                self.fillColor = onTintColor?.cgColor ?? UISwitchStyleKit.defaultOnColor.cgColor
                
            }
        }
    }
}
