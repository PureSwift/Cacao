//
//  UIResponder.swift
//  Cacao
//
//  Created by Alsey Coleman Miller on 6/8/17.
//

import Foundation

/// An abstract interface for responding to and handling events.
open class UIResponder: NSObject {
    
    // MARK: - Managing the Responder Chain
    
    /// Returns the next responder in the responder chain, or `nil` if there is no next responder.
    ///
    /// - Returns: The next object in the responder chain or nil if this is the last object in the chain.
    ///
    /// The UIResponder class does not store or set the next responder automatically,
    /// so this method returns nil by default. Subclasses must override this method and return an appropriate next responder.
    /// For example, `UIView` implements this method and returns the `UIViewController` object that manages it
    /// (if it has one) or its superview (if it doesn’t).
    /// `UIViewController` similarly implements the method and returns its view’s superview.
    /// `UIWindow` returns the application object.
    /// `UIApplication` returns nil.
    open var next: UIResponder? {
        
        return nil
    }
    
    /// Returns a Boolean value indicating whether this object is the first responder.
    open var isFirstResponder: Bool {
        
        return self === self.firstResponder
    }
    
    /// Returns a Boolean value indicating whether this object can become the first responder.
    open var canBecomeFirstResponder: Bool {
        
        return false
    }
    
    /// Asks Cacao to make this object the first responder in its window.
    open func becomeFirstResponder() -> Bool {
        
        // must belong to a view hierarchy
        guard let responderWindow = self.responderWindow
            else { fatalError("Not part of a valid view hierarchy") }
        
        // is already first responder
        guard isFirstResponder == false
            else { return true }
        
        // cannot become first responder
        guard canBecomeFirstResponder
            else { return false }
        
        // resign previous first responder
        guard responderWindow.firstResponder?.resignFirstResponder() ?? true
            else { return false }
        
        // set new responder
        responderWindow._firstResponder = self
        
        // TODO: Handle input
        
        return true
    }
    
    /// Returns a Boolean value indicating whether the receiver is willing to relinquish first-responder status.
    open var canResignFirstResponder: Bool {
        
        return true
    }
    
    /// Notifies this object that it has been asked to relinquish its status as first responder in its window.
    ///
    /// The default implementation returns true, resigning first responder status.
    /// You can override this method in your custom responders to update your object's state or perform other actions,
    /// such as removing the highlight from a selection. You can also return false, refusing to relinquish first responder
    /// status. If you override this method, you must call super (the superclass implementation) at some point in your code.
    open func resignFirstResponder() -> Bool {
        
        responderWindow?._firstResponder = nil
        
        // TODO: handle input
        
        
        return true
    }
    
    // MARK: - Responding to Touch Events
    
    /// Tells this object that one or more new touches occurred in a view or window.
    ///
    /// - Parameter touches: A set of UITouch instances that represent the touches for the starting phase of the event,
    /// which is represented by event. For touches in a view, this set contains only one touch by default.
    /// To receive multiple touches, you must set the view's `isMultipleTouchEnabled` property to true.
    ///
    /// - Parameter event: The event to which the touches belong.
    ///
    /// Cacao calls this method when a new touch is detected in a view or window.
    /// Many `UI*` classes override this method and use it to handle the corresponding touch events.
    ///
    /// The default implementation of this method forwards the message up the responder chain.
    /// When creating your own subclasses, call super to forward any events that you do not handle yourself.
    open func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        
        next?.touchesBegan(touches, with: event)
    }
    
    open func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        
        next?.touchesMoved(touches, with: event)
    }
    
    open func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        
        next?.touchesEnded(touches, with: event)
    }
    
    open func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        
        next?.touchesCancelled(touches, with: event)
    }
    
    // MARK: - Responding to Motion Events
    
    /// Tells the receiver that a motion event has begun.
    ///
    /// Cacao informs the responder only when a motion event starts and ends.
    /// It does not report intermediate shakes.
    /// Motion events are delivered initially to the first responder and are
    /// forwarded up the responder chain as appropriate.
    /// The default implementation of this method forwards the message up the responder chain.
    open func motionBegan(_ motion: UIEventSubtype,
                          with event: UIEvent?) {
        
        next?.motionBegan(motion, with: event)
    }
    
    /// Tells the receiver that a motion event has ended.
    open func motionEnded(_ motion: UIEventSubtype, with event: UIEvent?) {
        
        next?.motionEnded(motion, with: event)
    }
    
    /// Tells the receiver that a motion event has been cancelled.
    open func motionCancelled(_ motion: UIEventSubtype, with event: UIEvent?) {
        
        next?.motionCancelled(motion, with: event)
    }
    
    // MARK: - Responding to Press Events
    // Generally, responders that handle press events should override all four of these methods.
    
    /// Tells this object when a physical button is first pressed.
    ///
    /// - Parameter presses: A set of `UIPress` instances that represent the new presses that occurred.
    /// The phase of each press is set to began.
    ///
    /// - Parameter event: The event to which the presses belong.
    ///
    /// Cacao calls this method when a new button is pressed by the user.
    /// Use this method to determine which button was pressed and to take any needed actions.
    ///
    /// The default implementation of this method forwards the message up the responder chain.
    /// When creating your own subclasses, call super to forward any events that you do not handle yourself.
    open func pressesBegan(_ presses: Set<UIPress>, with event: UIPressesEvent?) {
        
        next?.pressesBegan(presses, with: event)
    }
    
    /// Tells this object when a value associated with a press has changed.
    open func pressesChanged(_ presses: Set<UIPress>, with event: UIPressesEvent?) {
        
        next?.pressesChanged(presses, with: event)
    }
    
    /// Tells the object when a button is released.
    open func pressesEnded(_ presses: Set<UIPress>, with event: UIPressesEvent?) {
        
        next?.pressesEnded(presses, with: event)
    }
    
    /// Tells this object when a system event (such as a low-memory warning) cancels a press event.
    open func pressesCancelled(_ presses: Set<UIPress>, with event: UIPressesEvent?) {
        
        next?.pressesCancelled(presses, with: event)
    }
    
    // MARK: - Responding to Remote-Control Events
    
    /// Tells the object when a remote-control event is received.
    ///
    /// - Parameter event: An event object encapsulating a remote-control command.
    /// Remote-control events have a type of `.remoteControl`.
    ///
    /// Remote-control events originate as commands from external accessories, including headsets.
    /// An application responds to these commands by controlling audio or video media presented to the user.
    /// The receiving responder object should examine the subtype of event to determine the intended
    /// command—for example, play (`.remoteControlPlay`)—and then proceed accordingly.
    ///
    /// To allow delivery of remote-control events, you must call the `beginReceivingRemoteControlEvents()`
    /// method of `UIApplication`. To turn off delivery of remote-control events,
    /// call the `endReceivingRemoteControlEvents()` method.
    open func remoteControlReceived(with event: UIEvent?) {
        
        next?.remoteControlReceived(with: event)
    }
    
    // MARK: - Managing Input Views
    
    /// The custom input view to display when the receiver becomes the first responder.
    ///
    /// This property is typically used to provide a view to replace the system-supplied keyboard
    /// that is presented for `UITextField` and `UITextView` objects.
    ///
    /// The value of this read-only property is `nil`.
    /// A responder object that requires a custom view to gather input from the user
    /// should redeclare this property as read-write and use it to manage its custom input view.
    /// When the receiver becomes the first responder, the responder infrastructure presents the
    /// specified input view automatically. Similarly, when the receiver resigns its first responder status,
    /// the responder infrastructure automatically dismisses the specified input view.
    open var inputView: UIView? { return nil }
    
    // MARK: - Getting the Undo Manager
    
    /// Returns the nearest shared undo manager in the responder chain.
    ///
    /// By default, every window of an application has an undo manager: a shared object for managing undo and redo operations.
    /// However, the class of any object in the responder chain can have their own custom undo manager.
    /// (For example, instances of UITextField have their own undo manager that is cleared when the text field
    /// resigns first-responder status.)
    /// When you request an undo manager, the request goes up the responder chain and the `UIWindow`
    /// object returns a usable instance.
    /// You may add undo managers to your view controllers to perform undo and redo operations local to the managed view.
    open var undoManager: UndoManager? { return nil }
    
    // MARK: - Validating Commands
    
    /// Requests the receiving responder to enable or disable the specified command in the user interface.
    open func canPerformAction(_ action: Selector,
                               withSender sender: Any?) -> Bool {
        
        return false
    }
    
    /// Returns the target object that responds to an action.
    ///
    /// This method is called whenever an action needs to be invoked by the object.
    /// The default implementation calls the canPerformAction(_:withSender:) method
    /// to determine whether it can invoke the action. If the object can invoke the action,
    /// it returns itself, otherwise it passes the request up the responder chain.
    /// Your app should override this method if it wants to override how a target is selected.
    open func target(forAction action: Selector,
                     withSender sender: Any?) -> Any? {
        
        return nil
    }
    
    // MARK: - Accessing the Available Key Commands
    
    /// The key commands that trigger actions on this responder.
    ///
    /// A responder object that supports hardware keyboard commands can redefine this property
    /// and use it to return an array of UIKeyCommand objects that it supports.
    /// Each key command object represents the keyboard sequence to recognize and the action method
    /// of the responder to call in response.
    /// The key commands you return from this method are applied to the entire responder chain.
    /// When an key combination is pressed that matches a key command object,
    /// Cacao walks the responder chain looking for an object that implements the corresponding action method.
    /// It calls that method on the first object it finds and then stops processing the event.
    open var keyCommands: [UIKeyCommand]? { return nil }
    
    // MARK: - Cacao Extensions
    
    open func wheelChanged(with event: UIWheelEvent) {
        
        next?.wheelChanged(with: event)
    }
    
    open func move(with event: UIMoveEvent) {
        
        next?.move(with: event)
    }
    
    // MARK: - Internal
    
    internal var responderWindow: UIWindow? {
        
        return next?.responderWindow
    }
    
    internal var firstResponder: UIResponder? {
        
        return next?.firstResponder
    }
}
