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
import struct Foundation.TimeInterval
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
        
        self.onTintColor = UISwitchStyleKit.defaultOnColor
        self.tintColor = UISwitchStyleKit.defaultStrokeColor
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
    public func setOn(_ newValue: Bool, animated: Bool) {
        
        setOn(newValue, tapped: false, animated: animated)
    }
    
    private func setOn(_ on: Bool, tapped: Bool, animated: Bool) {
        
        _on = on
        
        let phase = Phase(on: on, tapped: tapped)
        
        let animationDuration: TimeInterval
        
        if animated {
            
            if tapped {
                
                animationDuration = 0.1
                
            } else {
                
                animationDuration = 0.2
            }
        } else {
            
            animationDuration = 0
        }
        
        let targetState = State(phase, tintColor: tintColor, onTintColor: onTintColor, thumbTintColor: thumbTintColor)
        
        UIView.animate(withDuration: animationDuration) { [weak self] in
            
            self?.internalState = targetState
        }
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
        
        assert(_internalState.on.isNaN == false)
        assert(_internalState.on >= 0)
        assert(_internalState.on <= 1)
        assert(_internalState.tapped.isNaN == false)
        assert(_internalState.tapped >= 0)
        assert(_internalState.tapped <= 1)
        
        UISwitchStyleKit.drawSwitchView(frame: bounds,
                                        resizing: .center,
                                        thumbColor: UIColor(cgColor: _internalState.thumbColor),
                                        fillColor: UIColor(cgColor: _internalState.fillColor),
                                        switchOn: _internalState.on,
                                        tapped: _internalState.tapped,
                                        showFilled: _internalState.fillAlpha)
    }
    
    // MARK: - Events
    
    open override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        
        setOn(isOn, tapped: true, animated: true)
    }
    
    open override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        
        let newValue = !isOn
        
        setOn(newValue, tapped: false, animated: true)
        
        sendActions(for: .valueChanged)
    }
    
    // MARK: - Private
    
    private var internalState: State {
        
        @inline(__always)
        get { return _internalState }
        
        set {
            
            if let animationDuration = UIView.animationDuration {
                
                let oldValue = _internalState
                
                // On
                
                UIView.animations.append(Animation(view: self,
                                                   duration: animationDuration,
                                                   value: (start: oldValue.on, end: newValue.on),
                                                   keyPath: .init(get: { $0.internalState.on },
                                                                  set: { $0.internalState.on = $1 })))
                                                   //keyPath: \UISwitch.internalState.on))
                
                // Tapped
                
                UIView.animations.append(Animation(view: self,
                                                   duration: animationDuration,
                                                   value: (start: oldValue.tapped, end: newValue.tapped),
                                                   keyPath: .init(get: { $0.internalState.tapped },
                                                                  set: { $0.internalState.tapped = $1 })))
                                                   //keyPath: \UISwitch.internalState.tapped))
                
                // Fill Alpha
                
                UIView.animations.append(Animation(view: self,
                                                   duration: animationDuration,
                                                   value: (start: oldValue.fillAlpha, end: newValue.fillAlpha),
                                                   keyPath: .init(get: { $0.internalState.fillAlpha },
                                                                  set: { $0.internalState.fillAlpha = $1 })))
                                                   //keyPath: \UISwitch.internalState.fillAlpha))
                
                // Fill color
                
                UIView.animations.append(Animation(view: self,
                                                   duration: animationDuration,
                                                   value: (start: oldValue.fillColor.red, end: newValue.fillColor.red),
                                                   keyPath: .init(get: { $0.internalState.fillColor.red },
                                                                  set: { $0.internalState.fillColor.red = $1 })))
                                                   //keyPath: \UISwitch.internalState.fillColor.red))
                
                UIView.animations.append(Animation(view: self,
                                                   duration: animationDuration,
                                                   value: (start: oldValue.fillColor.green,
                                                           end: newValue.fillColor.green),
                                                   keyPath: .init(get: { $0.internalState.fillColor.green },
                                                                  set: { $0.internalState.fillColor.green = $1 })))
                                                   //keyPath: \UISwitch.internalState.fillColor.green))
                
                UIView.animations.append(Animation(view: self,
                                                   duration: animationDuration,
                                                   value: (start: oldValue.fillColor.blue,
                                                           end: newValue.fillColor.blue),
                                                   keyPath: .init(get: { $0.internalState.fillColor.blue },
                                                                  set: { $0.internalState.fillColor.blue = $1 })))
                                                   //keyPath: \UISwitch.internalState.fillColor.blue))
                
                UIView.animations.append(Animation(view: self,
                                                   duration: animationDuration,
                                                   value: (start: oldValue.fillColor.alpha,
                                                           end: newValue.fillColor.alpha),
                                                   keyPath: .init(get: { $0.internalState.fillColor.alpha },
                                                                  set: { $0.internalState.fillColor.alpha = $1 })))
                                                   //keyPath: \UISwitch.internalState.fillColor.alpha))
                
                // Thumb Color
                
                UIView.animations.append(Animation(view: self,
                                                   duration: animationDuration,
                                                   value: (start: oldValue.thumbColor.red,
                                                           end: newValue.thumbColor.red),
                                                   keyPath: .init(get: { $0.internalState.thumbColor.red },
                                                                  set: { $0.internalState.thumbColor.red = $1 })))
                                                   //keyPath: \UISwitch.internalState.thumbColor.red))
                
                UIView.animations.append(Animation(view: self,
                                                   duration: animationDuration,
                                                   value: (start: oldValue.thumbColor.green,
                                                           end: newValue.thumbColor.green),
                                                   keyPath: .init(get: { $0.internalState.thumbColor.green },
                                                                  set: { $0.internalState.thumbColor.green = $1 })))
                                                   //keyPath: \UISwitch.internalState.thumbColor.green))
                
                UIView.animations.append(Animation(view: self,
                                                   duration: animationDuration,
                                                   value: (start: oldValue.thumbColor.blue,
                                                           end: newValue.thumbColor.blue),
                                                   keyPath: .init(get: { $0.internalState.thumbColor.blue },
                                                                  set: { $0.internalState.thumbColor.blue = $1 })))
                                                   //keyPath: \UISwitch.internalState.thumbColor.blue))
                
                UIView.animations.append(Animation(view: self,
                                                   duration: animationDuration,
                                                   value: (start: oldValue.thumbColor.alpha,
                                                           end: newValue.thumbColor.alpha),
                                                   keyPath: .init(get: { $0.internalState.thumbColor.alpha },
                                                                  set: { $0.internalState.thumbColor.alpha = $1 })))
                                                   //keyPath: \UISwitch.internalState.thumbColor.alpha))
                
            } else {
                
                _internalState = newValue
            }
        }
    }
    
    private var _internalState = State(.off)
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
        var fillAlpha: CGFloat
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
                self.fillAlpha = 0
                self.fillColor = tintColor?.cgColor ?? UISwitchStyleKit.defaultStrokeColor.cgColor
                
            case .tapped(on: false):
                self.on = 0
                self.tapped = 1
                self.fillAlpha = 1
                self.fillColor = tintColor?.cgColor ?? UISwitchStyleKit.defaultStrokeColor.cgColor
                
            case .on:
                self.on = 1
                self.tapped = 0
                self.fillAlpha = 1
                self.fillColor = onTintColor?.cgColor ?? UISwitchStyleKit.defaultOnColor.cgColor
                
            case .tapped(on: true):
                self.on = 1
                self.tapped = 1
                self.fillAlpha = 1
                self.fillColor = onTintColor?.cgColor ?? UISwitchStyleKit.defaultOnColor.cgColor
            }
        }
    }
}
