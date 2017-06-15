//
//  UIBarPositioning.swift
//  Cacao
//
//  Created by Alsey Coleman Miller on 6/12/17.
//

/// Constants to identify the position of a bar.
public enum UIBarPosition: Int {
    
    /// Specifies that the position is unspecified.
    case any
    
    /// Specifies that the bar is at the bottom of its containing view.
    case bottom
    
    /// Specifies that the bar is at the top of its containing view.
    case top
    
    /// Specifies that the bar is at the top of the screen, as well as its containing view.
    case topAttached
}

// MARK: - Supporting Types

/// A set of methods that support the positioning of a bar that conforms to the `UIBarPositioning` protocol.
public protocol UIBarPositioningDelegate: class {
    
    /// Asks the delegate for the position of the specified bar in its new window.
    func position(for bar: UIBarPositioning) -> UIBarPosition
}

public extension UIBarPositioningDelegate {
    
    func position(for bar: UIBarPositioning) -> UIBarPosition {
        
        return .default
    }
}
