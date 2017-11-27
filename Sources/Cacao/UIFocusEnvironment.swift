//
//  UIFocusEnvironment.swift
//  Cacao
//
//  Created by Alsey Coleman Miller on 11/26/17.
//

import Foundation

/// Objects conforming to UIFocusEnvironment influence and respond to focus behavior
/// within a specific area of the screen that they control.
public protocol UIFocusEnvironment: class {
    
    
}

public protocol UIFocusItem : UIFocusEnvironment {
    
    
    /// Indicates whether or not this item is currently allowed to become focused.
    /// Returning NO restricts the item from being focusable, even if it is visible in the user interface. For example, UIControls return NO if they are disabled.
    
    var canBecomeFocused: Bool { get }
}
