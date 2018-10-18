//
//  UIWindow.swift
//  Cacao
//
//  Created by Alsey Coleman Miller on 6/7/17.
//

import Foundation
import Silica

/// An object that provides the backdrop for your app’s user interface and provides important event-handling behaviors.
open class UIWindow: UIView {
    
    // MARK: - Properties
    
    /// The root view controller for the window.
    public final var rootViewController: UIViewController? { didSet { rootViewControllerChanged(oldValue) } }
    
    /// The screen on which the window is displayed.
    public final var screen: UIScreen = UIScreen.main
    
    /// The position of the window in the z-axis.
    public final var windowLevel: UIWindowLevel = UIWindowLevelNormal
    
    /// A Boolean value that indicates whether the window is the key window for the app.
    public final var isKeyWindow: Bool { return UIApplication.shared.keyWindow === self }
    
    // MARK: - Initialization
    
    public override init(frame: CGRect) {
        
        super.init(frame: frame)
        
        screen.addWindow(self)
    }
    
    // MARK: - Methods
    
    /// Shows the window and makes it the key window.
    public final func makeKeyAndVisible() {
        
        makeKey()
        
        isHidden = false
    }
    
    /// Makes the receiver the key window.
    public final func makeKey() {
        
        UIScreen.main.setKeyWindow(self)
    }
    
    /// Called automatically to inform the window that it has become the key window.
    open func becomeKey() { /* subclass implementation */ }
    
    /// Called automatically to inform the window that it is no longer the key window.
    open func resignKey() { /* subclass implementation */ }
    
    /// last touch event, used for scrolling
    private var lastTouchEvent: UITouchesEvent?
    
    /// Dispatches the specified event to its views.
    public final func sendEvent(_ event: UIEvent) {
        
        let gestureEnvironment = UIApplication.shared.gestureEnvironment
        
        // handle touches event
        if let touchesEvent = event as? UITouchesEvent {
            
            // send touches to gesture recognizers
            gestureEnvironment.updateGestures(for: event, window: self)
            
            // send touches directly to views (legacy API)
            sendTouches(for: touchesEvent)
            
            // cache event
            lastTouchEvent = touchesEvent
        }
        // handle presses
        else if let pressesEvent = event as? UIPressesEvent {
            
            guard isUserInteractionEnabled else { return }
            
            gestureEnvironment.updateGestures(for: event, window: self)
            
            sendButtons(for: pressesEvent)
            
        } else if let moveEvent = event as? UIMoveEvent {
            // TODO: Implement self.focusResponder
            /*
            if let focusResponder = self.focusResponder {
                
                moveEvent.sendEvent(to: focusResponder)
            }*/
            
        } else if let wheelEvent = event as? UIWheelEvent {
            
            guard isUserInteractionEnabled else { return }
            
            guard let touchEvent = lastTouchEvent,
                let touch = touchEvent.touches.first,
                touch.phase == .moved,
                let view = touch.view
                else { return }
            
            wheelEvent.sendEvent(to: view)
        
        } else if let responderEvent = event as? UIResponderEvent {
            
            if let responder = self.firstResponder {
                
                responderEvent.sendEvent(to: responder)
            }
            
        } else {
            
            fatalError("Event not handled \(event)")
        }
    }
    
    // MARK: - Subclassed Methods
    
    open override func layoutSubviews() {
        
        self.rootViewController?.view.frame = self.bounds
    }
    
    // MARK: - UIResponder
    
    internal var _firstResponder: UIResponder?
    
    internal override var firstResponder: UIResponder? {
        
        return _firstResponder
    }
    
    /*
    internal override var firstResponder: UIResponder? {
        
        if let fieldEditor = _firstResponder as? UIFieldEditor {
            
            return fieldEditor.proxiedView
            
        } else {
            
            return _firstResponder
        }
    }*/
    
    public final override var next: UIResponder? {
        
        return UIApplication.shared
    }
    
    public final override func becomeFirstResponder() -> Bool {
        
        guard let rootViewController = self.rootViewController,
            rootViewController.becomeFirstResponder()
            else { return super.becomeFirstResponder() }
        
        return true
    }
    
    // MARK: - Private Methods
    
    private func rootViewControllerChanged(_ oldValue: UIViewController?) {
        
        oldValue?.view?.removeFromSuperview()
        
        guard let viewController = rootViewController
            else { return }
        
        addSubview(viewController.view)
        
        layoutIfNeeded()
    }
    
    private func sendTouches(for event: UITouchesEvent) {
        
        let touches = event.touches
        
        for touch in touches {
            
            switch touch.phase {
            case .began: touch.view?.touchesBegan(touches, with: event)
            case .moved: touch.view?.touchesMoved(touches, with: event)
            case .stationary: break
            case .ended: touch.view?.touchesEnded(touches, with: event)
            case .cancelled: touch.view?.touchesCancelled(touches, with: event)
            }
        }
    }
    
    private func sendButtons(for event: UIPressesEvent) {
        
        let responders = event.responders(for: self)
        
        for responder in responders {
            
            
        }
    }
    
    internal override var responderWindow: UIWindow? {
        
        return self
    }
}

// MARK: - Supporting Types

/// The positioning of windows relative to each other.
///
/// The stacking of levels takes precedence over the stacking of windows within each level.
/// That is, even the bottom window in a level obscures the top window of the next level down.
/// Levels are listed in order from lowest to highest.
public typealias UIWindowLevel = CGFloat

/// The default level. Use this level for the majority of your content, including for your app’s main window.
public let UIWindowLevelNormal: UIWindowLevel = 0

/// The level for an alert view. Windows at this level appear on top of windows at the UIWindowLevelNormal level.
public let UIWindowLevelAlert: UIWindowLevel = 2000

/// The level for a status window. Windows at this level appear on top of windows at the UIWindowLevelAlert level.
public let UIWindowLevelStatusBar: UIWindowLevel = 1000
