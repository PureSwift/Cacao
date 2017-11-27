//
//  UIKeyInput.swift
//  Cacao
//
//  Created by Alsey Coleman Miller on 11/26/17.
//

import Foundation

/// A set of methods a subclass of `UIResponder` uses to implement simple text entry.
///
/// When instances of this subclass are the first responder, the system keyboard is displayed.
/// Only a small subset of the available keyboards and languages are available to classes that adopt this protocol.
public protocol UIKeyInput: UITextInputTraits {
    
    /// Insert a character into the displayed text.
    ///
    /// - Parameter text: A string object representing the character typed on the system keyboard.
    ///
    /// Add the character text to your class’s backing store at the index corresponding to the cursor and redisplay the text.
    func insertText(_ text: String)
    
    /// Delete a character from the displayed text.
    ///
    /// Remove the character just before the cursor from your class’s backing store and redisplay the text.
    func deleteBackward()
    
    /// A Boolean value that indicates whether the text-entry objects has any text.
    ///
    /// - Returns: `true` if the backing store has textual content, `false` otherwise.
    var hasText: Bool { get }
}
