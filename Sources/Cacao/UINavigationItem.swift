//
//  UINavigationItem.swift
//  Cacao
//
//  Created by Alsey Coleman Miller on 6/14/17.
//

/// An object that manages the buttons and views to be displayed in a navigation bar object.
public final class UINavigationItem {
    
    // MARK: - Initializing an Item
    
    /// Returns a navigation item initialized with the specified title.
    public init(title: String) {
        
        self.title = title
    }
    
    // MARK: - Getting and Setting Properties
    
    /// The navigation item’s title displayed in the center of the navigation bar.
    public var title: String?
    
    /// A single line of text displayed at the top of the navigation bar.
    public var prompt: String?
    
    /// The bar button item to use when a back button is needed on the navigation bar.
    public var backBarButtonItem: UIBarButtonItem?
    
    /// A Boolean value that determines whether the back button is hidden.
    public var hidesBackButton: Bool = false
    
    /// Sets whether the back button is hidden, optionally animating the transition.
    public func setHidesBackButton(_ hidesBackButton: Bool, animated: Bool) {
        
        
    }
}
