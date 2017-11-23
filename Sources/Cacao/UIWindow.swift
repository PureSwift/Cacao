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
    public final var isKeyWindow: Bool { return UIScreen.main.keyWindow === self }
    
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
    
    /// Dispatches the specified event to its views.
    public final func sendEvent(_ event: UIEvent) {
        
        let gestureEnvironment = UIApplication.shared.gestureEnvironment
        
        // handle touches event
        if let touchesEvent = event as? UITouchesEvent {
            
            gestureEnvironment.updateGestures(for: event, window: self)
            
            sendTouches(for: touchesEvent)
            
        } else if let pressesEvent = event as? UIPressesEvent {
            
            guard isUserInteractionEnabled else { return }
            
            gestureEnvironment.updateGestures(for: event, window: self)
            
            sendButtons(for: pressesEvent)
        }
        
        
        
        /*
        switch event.type {
            
        case .touches:
            
            let touches = event.touches(for: self) ?? []
            
            let gestureRecognizers = touches.reduce([UIGestureRecognizer](), { $0 + ($1.gestureRecognizers ?? []) })
            
            // handle gestures
            
            for gesture in gestureRecognizers {
                
                guard gesture.shouldRecognize
                    else { continue }
                
                gesture.touches = touches.sorted(by: { $0.timestamp < $1.timestamp })
                
                for touch in touches {
                    
                    switch touch.phase {
                    case .began: gesture.touchesBegan(touches, with: event)
                    case .moved: gesture.touchesMoved(touches, with: event)
                    case .stationary: break
                    case .ended: gesture.touchesEnded(touches, with: event)
                    case .cancelled: gesture.touchesCancelled(touches, with: event)
                    }
                }
            }
            
            // handle touches
            
            for touch in touches {
                
                switch touch.phase {
                case .began: touch.view?.touchesBegan(touches, with: event)
                case .moved: touch.view?.touchesMoved(touches, with: event)
                case .stationary: break
                case .ended: touch.view?.touchesEnded(touches, with: event)
                case .cancelled: touch.view?.touchesCancelled(touches, with: event)
                }
            }
            
        default:
            
            fatalError("\(event.type) events not implemented")
        }*/
    }
    
    // MARK: - Subclassed Methods
    
    open override func layoutSubviews() {
        
        self.rootViewController?.view.frame = self.bounds
    }
    
    // MARK: - UIResponder
    
    open override var next: UIResponder? {
        
        return UIApplication.shared
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
