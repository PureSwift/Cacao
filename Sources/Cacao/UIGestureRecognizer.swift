//
//  UIGestureRecognizer.swift
//  Cacao
//
//  Created by Alsey Coleman Miller on 6/8/17.
//

import Foundation

/// The base class for concrete gesture recognizers.
///
/// A gesture-recognizer object—or, simply, a gesture recognizer—decouples the logic
/// for recognizing a sequence of touches (or other input) and acting on that recognition.
/// When one of these objects recognizes a common gesture or, in some cases,
/// a change in the gesture, it sends an action message to each designated target object.
open class UIGestureRecognizer: NSObject {
    
    // MARK: - Internal Properties
    
    private var targetActions = [TargetAction]()
    
    internal var touches = [UITouch]()
    
    private var failureRequirements = [UIGestureRecognizer]()
    
    internal weak var gestureEnvironment: UIGestureEnvironment?
    
    // MARK: - Initializing a Gesture Recognizer
        
    // Valid action method signatures:
    //     -(void)handleGesture;
    //     -(void)handleGesture:(UIGestureRecognizer*)gestureRecognizer;
    
    /// Initializes an allocated gesture-recognizer object with a target and an action selector.
    public init(targetAction: TargetAction) {
        super.init()
        
        self.addTarget(targetAction)
    }
    
    // MARK: - Adding and Removing Targets and Actions
    
    // add a target/action pair. you can call this multiple times to specify multiple target/actions
    public func addTarget(_ target: TargetAction) {
        
        targetActions.append(target)
    }
    
    // remove the specified target/action pair. passing nil for target matches all targets, and the same for actions
    public func removeTarget(_ target: TargetAction) {
        
        guard let index = targetActions.index(where: { $0.name == target.name })
            else { return }
        
        targetActions.remove(at: index)
    }
    
    internal func performActions() {
        
        targetActions.forEach { $0.action(self) }
    }
    
    // MARK: - Getting the Touches and Location of a Gesture
    
    // individual UIGestureRecognizer subclasses may provide subclass-specific location information. see individual subclasses for details
    // a generic single-point location for the gesture. usually the centroid of the touches involved
    
    /// Returns the point computed as the location of the gesture.
    ///
    /// - Parameter view: The view whose coordinate system you want to use for determining the location of the gesture.
    /// Specify nil to return the point in the coordinate system of the window.
    ///
    /// - Returns: The point at which the gesture occurred.
    /// The returned point is in the coordinate system of the specified view,
    /// or in the coordinate system of the window if you specified nil for the view parameter.
    open func location(in view: UIView?) -> CGPoint {
        
        return touches.map({ $0.location(in: view) }).center
    }
    
    // number of touches involved for which locations can be queried
    // the location of a particular touch
    open func location(ofTouch touchIndex: Int, in view: UIView?) -> CGPoint {
        
        return touches[touchIndex].location(in: view)
    }
    
    // number of touches involved for which locations can be queried
    open var numberOfTouches: Int {
        
        return touches.count
    }
    
    // MARK: - Getting the Recognizer’s State and View
    
    /// The current state of the gesture recognizer.
    ///
    /// - Warning: Readonly for users of a gesture recognizer.
    /// May only be changed by direct subclasses of `UIGestureRecognizer`.
    open var state = UIGestureRecognizerState()
    
    private let states: [(from: UIGestureRecognizerState, to: UIGestureRecognizerState, notify: Bool, reset: Bool)] =
        [(.possible, .recognized, true, true),
         (.possible, .failed, false, true),
         (.possible, .began, true, false),
         (.began, .changed, true, false),
         (.began, .cancelled, true, true),
         (.began, .failed, true, true),
         (.began, .ended, true, true),
         (.changed, .changed, true, false),
         (.changed, .cancelled, true, true),
         (.changed, .ended, true, true)]
    
    @discardableResult
    internal func transition(to state: UIGestureRecognizerState) -> (notify: Bool, reset: Bool) {
        
        let newValue = state
        
        let oldValue = self.state
        
        guard oldValue != newValue
            else { return (false, false) }
        
        guard let transition = states.first(where: { $0.from == oldValue && $0.to == newValue })
            else { fatalError("Invalid transition \(oldValue) -> \(newValue)") }
        
        self.state = newValue
        
        if transition.notify {
            
            performActions()
        }
        
        if transition.reset {
            
            reset()
        }
        
        return (transition.notify, transition.reset)
    }
    
    // a UIGestureRecognizer receives touches hit-tested to its view and any of that view's subviews
    // the view the gesture is attached to. set by adding the recognizer to a UIView using the `addGestureRecognizer()` method
    
    /// The view the gesture recognizer is attached to.
    public internal(set) weak var view: UIView?
    
    // default is true. disabled gesture recognizers will falset receive touches. when changed to false the gesture recognizer will be cancelled if it's currently recognizing a gesture
    public var isEnabled: Bool = true
    
    internal var shouldRecognize: Bool {
        
        return isEnabled
            && state != .failed
            && state != .cancelled
            && state != .ended
    }
    
    // MARK: - Canceling and Delaying Touches
    
    // default is true. causes touchesCancelled:withEvent: or pressesCancelled:withEvent: to be sent to the view for all touches or presses recognized as part of this gesture immediately before the action method is called.
    public var cancelsTouchesInView: Bool = true
    
    // default is false.  causes all touch or press events to be delivered to the target view only after this gesture has failed recognition. set to true to prevent views from processing any touches or presses that may be recognized as part of this gesture
    public var delaysTouchesBegan: Bool = false
    
    // default is true. causes touchesEnded or pressesEnded events to be delivered to the target view only after this gesture has failed recognition. this ensures that a touch or press that is part of the gesture can be cancelled if the gesture is recognized
    public var delaysTouchesEnded: Bool = true
    
    // MARK: - Specifying Dependencies Between Gesture Recognizers
    
    // create a relationship with afalsether gesture recognizer that will prevent this gesture's actions from being called until otherGestureRecognizer transitions to .Failed
    // if otherGestureRecognizer transitions to .Recognized or .Began then this recognizer will instead transition to .Failed
    // example usage: a single tap may require a double tap to fail
    open func require(toFail otherGestureRecognizer: UIGestureRecognizer) {
        
        
    }
    
    // MARK: - Setting and Getting the Delegate
    
    public weak var delegate: UIGestureRecognizerDelegate? // the gesture recognizer's delegate
    
    // MARK: - Recognizing Different Gestures
    
    //open var allowedTouchTypes: [UITouchType] // Array of UITouchTypes as NSNumbers.
    
    //open var allowedPressTypes: [UIPressType] // Array of UIPressTypes as NSNumbers.
    
    // Indicates whether the gesture recognizer will consider touches of different touch types simultaneously.
    // If false, it receives all touches that match its allowedTouchTypes.
    // If true, once it receives a touch of a certain type, it will ignore new touches of other types, until it is reset to .Possible.
     // defaults to true
    public var requiresExclusiveTouchType: Bool = true
    
    // Name tag used for debugging
    public var name: String?
    
    // MARK: - Methods for Subclasses
    
    /// Sent to the gesture recognizer when one or more fingers touch down in the associated view.
    open func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent) { }
    
    /// Sent to the gesture recognizer when one or more fingers move in the associated view.
    open func touchesMoved(_ touches:Set<UITouch>, with event: UIEvent) { }
    
    ///  Sent to the gesture recognizer when one or more fingers lift from the associated view.
    open func touchesEnded(_ touches:Set<UITouch>, with event: UIEvent) { }
    
    /// Sent to the gesture recognizer when a system event (such as an incoming phone call) cancels a touch event.
    open func touchesCancelled(_ touches:Set<UITouch>, with event: UIEvent) { }
    
    /// Overridden to reset internal state when a gesture recognition attempt completes.
    ///
    /// - Warning: Should never be called directly.
    open func reset() {
        
        self.state = .possible
        self.touches.removeAll()
    }
    
    /// Tells the gesture recognizer to ignore a specific touch of the given event.
    open func ignore(_ touch: UITouch, for event: UIEvent) { }
    
    /// Overridden to indicate that the specified gesture recognizer can prevent the receiver from recognizing a gesture.
    open func canBePrevented(by gestureRecognizer: UIGestureRecognizer) { }
    
    /// Overridden to indicate that the receiver can prevent the specified gesture recognizer from recognizing its gesture.
    open func canPrevent(_ gestureRecognizer: UIGestureRecognizer) { }
    
    /// Overridden to indicate that the receiver requires the specified gesture recognizer to fail.
    open func shouldRequireFailure(of gestureRecognizer: UIGestureRecognizer) { }
    
    /// Overridden to indicate that the receiver should be required to fail by the specified gesture recognizer.
    open func shouldBeRequiredToFail(by gestureRecognizer: UIGestureRecognizer) { }
    
    /// Tells the gesture recognizer to ignore a specific press of the given event.
    open func ignore(_ press: UIPress, for event: UIPressesEvent) { }
    
    /// Sent to the receiver when a physical button is pressed in the associated view.
    open func pressesBegan(_ presses: Set<UIPress>, with event: UIPressesEvent) { }
    
    /// Sent to the receiver when the force of the press has changed in the associated view.
    open func pressesChanged(_ presses: Set<UIPress>, with event: UIPressesEvent) { }
    
    ///  Sent to the receiver when a button is released from the associated view.
    open func pressesEnded(_ presses: Set<UIPress>, with event: UIPressesEvent) { }
    
    /// Sent to the receiver when a system event (such as a low-memory warning) cancels a press event.
    open func pressesCancelled(_ presses: Set<UIPress>, with event: UIPressesEvent) { }
}

// MARK: - Supporting Types

public extension UIGestureRecognizer {
    
    public struct TargetAction {
        
        public typealias Action = (UIGestureRecognizer) -> ()
        
        public let action: Action
        
        public let name: String
        
        public init(action: @escaping Action, name: String) {
            
            self.action = action
            self.name = name
        }
    }
}

public protocol UIGestureRecognizerDelegate: class {
    
    // called when a gesture recognizer attempts to transition out of .Possible. returning false causes it to transition to .Failed
    func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool
    
    
    // called when the recognition of one of gestureRecognizer or otherGestureRecognizer would be blocked by the other
    // return true to allow both to recognize simultaneously. the default implementation returns false (by default false two gestures can be recognized simultaneously)
    //
    // falsete: returning true is guaranteed to allow simultaneous recognition. returning false is falset guaranteed to prevent simultaneous recognition, as the other gesture's delegate may return true
    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool
    
    
    // called once per attempt to recognize, so failure requirements can be determined lazily and may be set up between recognizers across view hierarchies
    // return true to set up a dynamic failure requirement between gestureRecognizer and otherGestureRecognizer
    //
    // falsete: returning true is guaranteed to set up the failure requirement. returning false does falset guarantee that there will falset be a failure requirement as the other gesture's counterpart delegate or subclass methods may return true
    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRequireFailureOf otherGestureRecognizer: UIGestureRecognizer) -> Bool
    
    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldBeRequiredToFailBy otherGestureRecognizer: UIGestureRecognizer) -> Bool
    
    // called before touchesBegan:withEvent: is called on the gesture recognizer for a new touch. return false to prevent the gesture recognizer from seeing this touch
    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldReceive touch: UITouch) -> Bool
    
    
    // called before pressesBegan:withEvent: is called on the gesture recognizer for a new press. return false to prevent the gesture recognizer from seeing this press
    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldReceive press: UIPress) -> Bool
}

public enum UIGestureRecognizerState: Int {
    
    public init() { self = .possible }
    
    case possible // the recognizer has falset yet recognized its gesture, but may be evaluating touch events. this is the default state
    
    case began // the recognizer has received touches recognized as the gesture. the action method will be called at the next turn of the run loop
    
    case changed // the recognizer has received touches recognized as a change to the gesture. the action method will be called at the next turn of the run loop
    
    case ended // the recognizer has received touches recognized as the end of the gesture. the action method will be called at the next turn of the run loop and the recognizer will be reset to `.possible`
    
    case cancelled // the recognizer has received touches resulting in the cancellation of the gesture. the action method will be called at the next turn of the run loop. the recognizer will be reset to `.possible`
    
    case failed // the recognizer has received a touch sequence that can falset be recognized as the gesture. the action method will falset be called and the recognizer will be reset to `.possible`
    
    // Discrete Gestures – gesture recognizers that recognize a discrete event but do falset report changes (for example, a tap) do falset transition through the Began and Changed states and can falset fail or be cancelled
    public static let recognized: UIGestureRecognizerState = .ended // the recognizer has received touches recognized as the gesture. the action method will be called at the next turn of the run loop and the recognizer will be reset to `.possible`
}

