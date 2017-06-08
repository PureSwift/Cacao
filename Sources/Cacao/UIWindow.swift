//
//  UIWindow.swift
//  Cacao
//
//  Created by Alsey Coleman Miller on 6/7/17.
//

import typealias Silica.CGFloat

/// An object that provides the backdrop for your app’s user interface and provides important event-handling behaviors.
open class UIWindow: UIView {
    
    // MARK: - Properties
    
    /// The root view controller for the window.
    public final var rootViewController: UIViewController?
    
    /// The screen on which the window is displayed.
    public final var screen: UIScreen { return UIScreen.main }
    
    /// The position of the window in the z-axis.
    public final var windowLevel: UIWindowLevel = .normal
    
    /// A Boolean value that indicates whether the window is the key window for the app.
    public final var isKeyWindow: Bool { return UIScreen.main.keyWindow === self }
    
    // MARK: - Methods
    
    /// Shows the window and makes it the key window.
    public final func makeKeyAndVisible() {
        
        makeKey()
        
        hidden = false
    }
    
    /// Makes the receiver the key window.
    public final func makeKey() {
        
        UIScreen.main.keyWindow = self
    }
    
    /// Called automatically to inform the window that it has become the key window.
    public func becomeKey() { /* subclass implementation */ }
    
    /// Called automatically to inform the window that it is no longer the key window.
    public func resignKey() { /* subclass implementation */ }
    
    /// Dispatches the specified event to its views.
    public final func sendEvent(_ event: UIEvent) {
        
        
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
public let UIWindowLevelNormal: UIWindowLevel

/// The level for an alert view. Windows at this level appear on top of windows at the UIWindowLevelNormal level.
public let UIWindowLevelAlert: UIWindowLevel

/// The level for a status window. Windows at this level appear on top of windows at the UIWindowLevelAlert level.
public let UIWindowLevelStatusBar: UIWindowLevel