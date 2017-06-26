//
//  TableView.swift
//  Cacao
//
//  Created by Alsey Coleman Miller on 5/28/16.
//  Copyright © 2016 PureSwift. All rights reserved.
//

import Foundation
import Silica

/// A view that presents data using rows arranged in a single column.
open class UITableView: UIScrollView {
    
    // MARK: - Initialization
    
    /// Initializes and returns a table view object having the given frame and style.
    public init(frame: CGRect, style: UITableViewStyle) {
        
        self.style = style
        super.init(frame: frame)
    }
    
    public override init(frame: CGRect) {
        
        self.style = .plain
        super.init(frame: frame)
    }
    
    // MARK: - Providing the Table View Data
    
    /// The object that acts as the data source of the table view.
    public weak var dataSource: UITableViewDataSource?
    
    // MARK: - Customizing the Table View Behavior
    
    /// The object that acts as the delegate of the table view.
    //public weak var delegate: UITableViewDelegate?
    
    // MARK: - Configuring a Table View
    
    /// the style of the table view.
    public let style: UITableViewStyle
    
    /// Returns the number of rows (table cells) in a specified section.
    public func numberOfRows(inSection section: Int) {
        
        fatalError()
    }
    
    public var numberOfSections: Int {
        
        fatalError()
    }
    
    /// The height of each row (that is, table cell) in the table view.
    public var rowHeight: CGFloat = UITableView.defaultRowHeight
    
    /// The style for table cells used as separators.
    public var separatorStyle: UITableViewCellSeparatorStyle = .singleLine
    
    /// The color of separator rows in the table view.
    public var separatorColor: UIColor? = UIColor(red: CGFloat(0.88), green: CGFloat(0.88), blue: CGFloat(0.88), alpha: CGFloat(1))
    
    /// The effect applied to table separators.
    //public var separatorEffect: UIVisualEffect?
    
    /// The background view of the table view.
    public var backgroundView: UIView?
    
    /// Specifies the default inset of cell separators.
    public var separatorInset: UIEdgeInsets = UIEdgeInsets()
    
    // MARK: - Creating Table View Cells
    
    // MARK: - Private
    
    private static let defaultRowHeight: CGFloat = 43
}

// MARK: - Supporting Types

public enum UITableViewStyle: Int {
    
    case plain
    case grouped
}

public enum UITableViewScrollPosition: Int {
    
    case none
    case top
    case middle
    case bottom
}

public enum UITableViewRowAnimation: Int {
    
    case fade
    case right
    case left
    case top
    case bottom
    case none
    case middle
    
    case automatic = 100
}

// http://stackoverflow.com/questions/235120/whats-the-uitableview-index-magnifying-glass-character
public let UITableViewIndexSearch: String = "{search}"

open class UITableViewRowAction {
    
    
}

public protocol UITableViewDataSource: class {
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int
    
    
    // Row display. Implementers should *always* try to reuse cells by setting each cell's reuseIdentifier and querying for available reusable cells with dequeueReusableCellWithIdentifier:
    // Cell gets various attributes set automatically based on table (separators) and data source (accessory views, editing controls)
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell
    
    
    func numberOfSections(in tableView: UITableView) -> Int // Default is 1 if not implemented
    
    
    func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? // fixed font style. use custom view (UILabel) if you want something different
    
    func tableView(_ tableView: UITableView, titleForFooterInSection section: Int) -> String?
    
    
    // Editing
    
    // Individual rows can opt out of having the -editing property set for them. If not implemented, all rows are assumed to be editable.
    func tableView(_ tableView: UITableView, canEditRowAt indexPath: IndexPath) -> Bool
    
    
    // Moving/reordering
    
    // Allows the reorder accessory view to optionally be shown for a particular row. By default, the reorder control will be shown only if the datasource implements -tableView:moveRowAtIndexPath:toIndexPath:
    func tableView(_ tableView: UITableView, canMoveRowAt indexPath: IndexPath) -> Bool
    
    
    // Index
    
    func sectionIndexTitles(for tableView: UITableView) -> [String]? // return list of section titles to display in section index view (e.g. "ABCD...Z#")
    
    func tableView(_ tableView: UITableView, sectionForSectionIndexTitle title: String, at index: Int) -> Int // tell table which section corresponds to section title/index (e.g. "B",1))
    
    
    // Data manipulation - insert and delete support
    
    // After a row has the minus or plus button invoked (based on the UITableViewCellEditingStyle for the cell), the dataSource must commit the change
    // Not called for edit actions using UITableViewRowAction - the action's handler will be invoked instead
    func tableView(_ tableView: UITableView, commit editingStyle: UITableViewCellEditingStyle, forRowAt indexPath: IndexPath)
    
    
    // Data manipulation - reorder / moving support
    
    func tableView(_ tableView: UITableView, moveRowAt sourceIndexPath: IndexPath, to destinationIndexPath: IndexPath)
}

public protocol UITableViewDelegate: UIScrollViewDelegate {
    
    // Display customization
    
    func tableView(_ tableView: UITableView, willDisplay cell: UITableViewCell, forRowAt indexPath: IndexPath)
    
    func tableView(_ tableView: UITableView, willDisplayHeaderView view: UIView, forSection section: Int)
    
    func tableView(_ tableView: UITableView, willDisplayFooterView view: UIView, forSection section: Int)
    
    func tableView(_ tableView: UITableView, didEndDisplaying cell: UITableViewCell, forRowAt indexPath: IndexPath)
    
    func tableView(_ tableView: UITableView, didEndDisplayingHeaderView view: UIView, forSection section: Int)
    
    
    func tableView(_ tableView: UITableView, didEndDisplayingFooterView view: UIView, forSection section: Int)
    
    
    // Variable height support
    
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat
    
    func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat
    
    func tableView(_ tableView: UITableView, heightForFooterInSection section: Int) -> CGFloat
    
    
    // Use the estimatedHeight methods to quickly calcuate guessed values which will allow for fast load times of the table.
    // If these methods are implemented, the above -tableView:heightForXXX calls will be deferred until views are ready to be displayed, so more expensive logic can be placed there.
    func tableView(_ tableView: UITableView, estimatedHeightForRowAt indexPath: IndexPath) -> CGFloat
    
    func tableView(_ tableView: UITableView, estimatedHeightForHeaderInSection section: Int) -> CGFloat
    
    func tableView(_ tableView: UITableView, estimatedHeightForFooterInSection section: Int) -> CGFloat
    
    
    // Section header & footer information. Views are preferred over title should you decide to provide both
    
    func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? // custom view for header. will be adjusted to default or specified header height
    
    func tableView(_ tableView: UITableView, viewForFooterInSection section: Int) -> UIView? // custom view for footer. will be adjusted to default or specified footer height
    
    
    func tableView(_ tableView: UITableView, accessoryButtonTappedForRowWith indexPath: IndexPath)
    
    
    // Selection
    
    // -tableView:shouldHighlightRowAtIndexPath: is called when a touch comes down on a row.
    // Returning NO to that message halts the selection process and does not cause the currently selected row to lose its selected look while the touch is down.
    func tableView(_ tableView: UITableView, shouldHighlightRowAt indexPath: IndexPath) -> Bool
    
    func tableView(_ tableView: UITableView, didHighlightRowAt indexPath: IndexPath)
    
    func tableView(_ tableView: UITableView, didUnhighlightRowAt indexPath: IndexPath)
    
    
    // Called before the user changes the selection. Return a new indexPath, or nil, to change the proposed selection.
    func tableView(_ tableView: UITableView, willSelectRowAt indexPath: IndexPath) -> IndexPath?
    
    
    func tableView(_ tableView: UITableView, willDeselectRowAt indexPath: IndexPath) -> IndexPath?
    
    // Called after the user changes the selection.
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath)
    
    
    func tableView(_ tableView: UITableView, didDeselectRowAt indexPath: IndexPath)
    
    
    // Editing
    
    // Allows customization of the editingStyle for a particular cell located at 'indexPath'. If not implemented, all editable cells will have UITableViewCellEditingStyleDelete set for them when the table has editing property set to YES.
    func tableView(_ tableView: UITableView, editingStyleForRowAt indexPath: IndexPath) -> UITableViewCellEditingStyle
    
    func tableView(_ tableView: UITableView, titleForDeleteConfirmationButtonForRowAt indexPath: IndexPath) -> String?
    
    func tableView(_ tableView: UITableView, editActionsForRowAt indexPath: IndexPath) -> [UITableViewRowAction]?
    
    // Controls whether the background is indented while editing.  If not implemented, the default is YES.  This is unrelated to the indentation level below.  This method only applies to grouped style table views.
    func tableView(_ tableView: UITableView, shouldIndentWhileEditingRowAt indexPath: IndexPath) -> Bool
    
    
    // The willBegin/didEnd methods are called whenever the 'editing' property is automatically changed by the table (allowing insert/delete/move). This is done by a swipe activating a single row
    func tableView(_ tableView: UITableView, willBeginEditingRowAt indexPath: IndexPath)
    
    func tableView(_ tableView: UITableView, didEndEditingRowAt indexPath: IndexPath?)
    
    
    // Moving/reordering
    
    // Allows customization of the target row for a particular row as it is being moved/reordered
    func tableView(_ tableView: UITableView,
                   targetIndexPathForMoveFromRowAt sourceIndexPath: IndexPath,
                   toProposedIndexPath proposedDestinationIndexPath: IndexPath) -> IndexPath
    
    
    // Indentation
    
    func tableView(_ tableView: UITableView,
                   indentationLevelForRowAt indexPath: IndexPath) -> Int // return 'depth' of row for hierarchies
}
