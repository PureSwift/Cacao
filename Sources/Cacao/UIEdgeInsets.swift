//
//  UIEdgeInsets.swift
//  Cacao
//
//  Created by Alsey Coleman Miller on 6/18/17.
//

import Foundation

/// The inset distances for views.
///
/// Edge inset values are applied to a rectangle to shrink or expand the area represented by that rectangle.
/// Typically, edge insets are used during view layout to modify the view’s frame.
/// Positive values cause the frame to be inset (or shrunk) by the specified amount.
/// Negative values cause the frame to be outset (or expanded) by the specified amount.
public struct UIEdgeInsets {
    
    // MARK: - Properties
    
    /// The bottom edge inset value.
    public var bottom: CGFloat
    
    /// The left edge inset value.
    public var left: CGFloat
    
    /// The right edge inset value.
    public var right: CGFloat
    
    /// The top edge inset value.
    public var top: CGFloat
    
    // MARK: - Initialization
    
    public static let zero = UIEdgeInsets()
    
    /// Initializes the edge inset struct values.
    public init(top: CGFloat = 0, left: CGFloat = 0, bottom: CGFloat = 0, right: CGFloat = 0) {
        
        self.bottom = bottom
        self.left = left
        self.right = right
        self.top = top
    }
}

// MARK: - Equatable

extension UIEdgeInsets: Equatable {
    
    public static func == (lhs: UIEdgeInsets, rhs: UIEdgeInsets) -> Bool {
        
        return lhs.bottom == rhs.bottom
            && lhs.left == rhs.left
            && lhs.right == rhs.right
            && lhs.top == rhs.top
    }
}
