//
//  UITableViewController.swift
//  Cacao
//
//  Created by Alsey Coleman Miller on 11/18/17.
//

import Foundation
import Silica

/// A controller object that manages a table view.
open class UITableViewController: UIViewController {
    
    // MARK: - Initializing the UITableViewController Object
    
    public init() {
        
        // If you use the standard init method to initialize a UITableViewController object,
        // a table view in the plain style is created.
        // https://developer.apple.com/documentation/uikit/uitableviewcontroller/1614754-init
        self.init(style: .plain)
    }
    
    /// Initializes a table-view controller to manage a table view of a given style.
    public init(style: UITableViewStyle) {
        
        super.init()
    }
    
    // MARK: - Getting the Table View
    
    /// Returns the table view managed by the controller object.
    public var tableView: UITableView!
    
    // MARK: - Configuring the Table Behavior
    
    /// A Boolean value indicating if the controller clears the selection when the table appears.
    ///
    /// The default value of this property is `true`.
    /// When `true`, the table view controller clears the table’s current selection
    /// when it receives a `viewWillAppear(_:)` message.
    /// Setting this property to `false` preserves the selection.
    public var clearsSelectionOnViewWillAppear: Bool = true
    
    // MARK: - Refreshing the Table View
    
    /// The refresh control used to update the table contents.
    ///
    /// - Note: The default value of this property is nil.
    ///
    /// Assigning a refresh control to this property adds the control to the view controller’s associated interface.
    /// You do not need to set the frame of the refresh control before associating it with the view controller.
    /// The view controller updates the control’s height and width and sets its position appropriately.
    ///
    /// The table view controller does not automatically update table’s contents in response to user interactions
    /// with the refresh control. When the user initiates a refresh operation, the control generates a valueChanged event.
    /// You must associate a target and action method with this event and use them to refresh your table’s contents.
    public var refreshControl: UIRefreshControl?
    
    // MARK: - Overriden Methods
    
    open override func viewDidLoad() {
        
        
    }
}
