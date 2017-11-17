//
//  UIResponder.swift
//  Cacao
//
//  Created by Alsey Coleman Miller on 6/8/17.
//

import class Foundation.NSObject

/// An abstract interface for responding to and handling events.
open class UIResponder: NSObject {

    // MARK: - Managing the Responder Chain

    /// Returns the next responder in the responder chain, or `nil` if there is no next responder.
    ///
    /// - Returns: The next object in the responder chain or nil if this is the last object in the chain.
    ///
    /// The UIResponder class does not store or set the next responder automatically,
    /// so this method returns nil by default. Subclasses must override this method and return an appropriate next responder.
    /// For example, UIView implements this method and returns the UIViewController object that manages it
    /// (if it has one) or its superview (if it doesn’t).
    /// UIViewController similarly implements the method and returns its view’s superview.
    /// UIWindow returns the application object. UIApplication returns nil.
    open var next: UIResponder? {
        return nil
    }

    // MARK: - Responding to Touch Events

    /// Tells this object that one or more new touches occurred in a view or window.
    ///
    /// - Parameter touches: A set of UITouch instances that represent the touches for the starting phase of the event,
    /// which is represented by event. For touches in a view, this set contains only one touch by default.
    /// To receive multiple touches, you must set the view's `isMultipleTouchEnabled` property to true.
    /// - Parameter event: The event to which the touches belong.
    ///
    /// Cacao calls this method when a new touch is detected in a view or window.
    /// Many `UI*` classes override this method and use it to handle the corresponding touch events.
    /// The default implementation of this method forwards the message up the responder chain.
    /// When creating your own subclasses, call super to forward any events that you do not handle yourself.
    open func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) { }

    open func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) { }

    open func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) { }

    open func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) { }
}
