//
//  UIControl.swift
//  Cacao
//
//  Created by Alsey Coleman Miller on 6/7/17.
//

import class Foundation.NSNull

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
    private var targetActions = [Target: [UIControlEvents: [Selector]]]()
    
    /// Associates a target object and action method with the control.
    public func addTarget(_ target: AnyHashable?, action: Selector, for controlEvents: UIControlEvents) {
        
        let target = Target(target)
        
        targetActions[target, default: [:]][controlEvents,  default: []].append(action)
    }
    
    /// Stops the delivery of events to the specified target object.
    public func removeTarget(_ target: AnyHashable?, action: Selector, for controlEvents: UIControlEvents) {
            
        let target = Target(target)
        
        guard let index = targetActions[target, default: [:]][controlEvents,  default: []].index(of: action)
            else { return }
        
        targetActions[target, default: [:]][controlEvents,  default: []].remove(at: index)
    }
    
    /// Returns the actions performed on a target object when the specified event occurs.
    ///
    /// - Parameter target: The target object—that is, an object that has an action method associated with this control.
    /// You must pass an explicit object for this method to return a meaningful result.
    /// Specifying `nil` always returns `nil`.
    /// - Parameter controlEvent: A single control event constant representing the event
    /// for which you want the list of action methods.
    /// For a list of possible constants, see `UIControlEvents`.
    public func actions(forTarget target: AnyHashable?, forControlEvent controlEvent: UIControlEvents) -> [Selector]? {
        
        guard let targetValue = target
            else { return nil }
        
        let target = Target(targetValue)
        
        return targetActions[target, default: [:]][controlEvent, default: []]
    }
    
    /// Returns the events for which the control has associated actions.
    ///
    /// - Returns: A bitmask of constants indicating the events for which this control has associated actions.
    public var allControlEvents: UIControlEvents {
        
        return targetActions
            .reduce([UIControlEvents](), { $0 + Array($1.value.keys) })
            .reduce(UIControlEvents(), { $0.union($1) })
    }
    
    /// Returns all target objects associated with the control.
    ///
    /// - Returns: A set of all target objects associated with the control.
    /// The returned set may include one or more `NSNull` objects to indicate actions that are dispatched to the responder chain.
    public var allTargets: Set<AnyHashable> {
        
        let targets = targetActions.keys.map { $0.value ?? NSNull() as AnyHashable }
        
        return Set(targets)
    }
}

private extension UIControl {
    
    final class Target: Hashable {
        
        let value: AnyHashable?
        
        init(_ value: AnyHashable? = nil) {
            
            self.value = value
        }
        
        var hashValue: Int {
            
            return value?.hashValue ?? 0
        }
        
        static func == (lhs: Target, rhs: Target) -> Bool {
            
            return lhs.value == rhs.value
        }
    }
}

/// Cacao extension since Swift doesn't support ObjC runtime (on non-Darwin platforms)
public struct Selector: Hashable {
    
    public let action: (_ target: AnyHashable, _ sender: AnyObject?) -> ()
    
    public let name: String
    
    public var hashValue: Int {
        
        return name.hashValue
    }
    
    public static func == (lhs: Selector, rhs: Selector) -> Bool {
        
        return lhs.name == rhs.name
    }
}

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

extension UIControlEvents: Hashable {
    
    public var hashValue: Int {
        return rawValue
    }
}
