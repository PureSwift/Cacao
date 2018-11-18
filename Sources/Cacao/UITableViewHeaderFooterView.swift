//
//  UITableViewHeaderFooterView.swift
//  Cacao
//
//  Created by Alsey Coleman Miller on 11/17/17.
//

import Foundation

#if os(iOS)
import UIKit
import CoreGraphics
#else
import Silica
#endif

/// A reusable view that can be placed at the top or bottom of a table section
/// to display additional information for that section.
///
/// You can use this class as-is without subclassing in most cases.
/// If you have custom content to display, create the subviews for
/// your content and add them to the view in the `contentView` property.
open class UITableViewHeaderFooterView: UIView {
    
    // MARK: - Initializing the View
    
    /// Initializes a header/footer view with the specified reuse identifier.
    public required init(reuseIdentifier: String?) {
        
        self.reuseIdentifier = reuseIdentifier
        
        super.init(frame: .zero)
    }
    
    #if os(iOS)
    public required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    #endif
    
    // MARK: - Accessing the Content Views
    
    /// The content view of the header or footer.
    public var contentView: UIView = UIView(frame: .zero)
    
    /// The background view of the header or footer.
    public var backgroundView: UIView?
    
    // MARK: - Managing View Reuse
    
    /// A string used to identify a reusable header or footer.
    public let reuseIdentifier: String?
    
    /// Prepares a reusable header or footer view for reuse by the table.
    open func prepareForReuse() { } // override
    
    // MARK: - Accessing the Default View Content
    
    /// A primary text label for the view.
    open var textLabel: UILabel?
    
    /// A detail text label for the view.
    open var detailTextLabel: UILabel?
}

// MARK: - ReusableView Protocol

extension UITableViewHeaderFooterView: ReusableView { }

