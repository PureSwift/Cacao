//
//  UIFocusUpdateContext.swift
//  Cacao
//
//  Created by Alsey Coleman Miller on 11/26/17.
//

import Foundation

/// `UIFocusUpdateContexts` provide information relevant to a specific focus update from one view to another.
/// They are ephemeral objects that are usually discarded after the update is finished.
public class UIFocusUpdateContext {
    
    /// The item that was focused before the update, i.e. where focus is updating from. May be nil if no item was focused, such as when focus is initially set.
    public private(set) weak var previouslyFocusedItem: UIFocusItem?
    
    
    /// The item that is focused after the update, i.e. where focus is updating to. May be nil if no item is being focused, meaning focus is being lost.
    public private(set) weak var nextFocusedItem: UIFocusItem?
    
    
    /// The view that was focused before the update. May be nil if no view was focused, such as when setting initial focus.
    /// If previouslyFocusedItem is not a view, this returns that item's containing view, otherwise they are equal.
    /// NOTE: This property will be deprecated in a future release. Use previouslyFocusedItem instead.
    public private(set) weak var previouslyFocusedView: UIView?
    
    
    /// The view that will be focused after the update. May be nil if no view will be focused.
    /// If nextFocusedItem is not a view, this returns that item's containing view, otherwise they are equal.
    /// NOTE: This property will be deprecated in a future release. Use nextFocusedItem instead.
    public private(set) weak var nextFocusedView: UIView?
    
    
    /// The focus heading in which the update is occuring.
    public private(set) var focusHeading: UIFocusHeading = .init(rawValue: 0)
}
