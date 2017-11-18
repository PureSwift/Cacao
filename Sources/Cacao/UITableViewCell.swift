//
//  UITableViewCell.swift
//  Cacao
//
//  Created by Alsey Coleman Miller on 6/26/17.
//

import Foundation

/// A cell in a table view.
///
/// This class includes properties and methods for setting and managing cell content
/// and background (including text, images, and custom views), managing the cell
/// selection and highlight state, managing accessory views, and initiating the
/// editing of the cell contents.
open class UITableViewCell: UIView {
    
    // MARK: - Initializing a `UITableViewCell` Object
    
    /// Initializes a table cell with a style and a reuse identifier and returns it to the caller.
    public required init(style: UITableViewCellStyle, reuseIdentifier: String?) {
        
        self.style = style
        self.reuseIdentifier = reuseIdentifier
        
        // while `UIView.init()` creates a view with an empty frame,
        // UIKit creates a {0,0, 320, 44} cell with this initializer
        super.init(frame: CGRect(origin: .zero, size: UITableViewCell.defaultSize))
        
        // add mandatory subviews
        self.addSubview(separatorView)
        self.addSubview(contentView)
    }
    
    // MARK: - Reusing Cells
    
    /// A string used to identify a cell that is reusable.
    public let reuseIdentifier: String?
    
    /// Prepares a reusable cell for reuse by the table view's delegate.
    open func prepareForReuse() { } // default implementation is empty
    
    // MARK: - Managing the Predefined Content
    
    /// Returns the label used for the main textual content of the table cell.
    public private(set) weak var textLabel: UILabel?
    
    /// Returns the secondary label of the table cell if one exists.
    public private(set) weak var detailTextLabel: UILabel?
    
    /// Returns the image view of the table cell.
    public private(set) weak var imageView: UIImageView?
    
    // MARK: - Accessing Views of the Cell Object
    
    /// Returns the content view of the cell object.
    ///
    /// The content view of a `UITableViewCell` object is the default superview for content displayed by the cell.
    /// If you want to customize cells by simply adding additional views, you should add them to the content view
    /// so they will be positioned appropriately as the cell transitions into and out of editing mode.
    public lazy var contentView: UIView = UIView(frame: .zero)
    
    /// The view used as the background of the cell.
    ///
    /// The default is `nil` for cells in plain-style tables (`.plain`)
    /// and non-nil for grouped-style tables (`.grouped`).
    /// `UITableViewCell` adds the background view as a subview behind all other views and uses its current frame location.
    public var backgroundView: UIView?
    
    /// The view used as the background of the cell when it is selected.
    ///
    /// The default is nil for cells in plain-style tables (`.plain`)
    /// and non-nil for section-group tables (`.grouped`).
    /// `UITableViewCell` adds the value of this property as a subview only when the cell is selected.
    /// It adds the selected background view as a subview directly above the background view (`backgroundView`)
    /// if it is not nil, or behind all other views.
    /// Calling `setSelected(_:animated:)` causes the selected background view to animate in and out with an alpha fade.
    public var selectedBackgroundView: UIView?
    
    /// The background view to use for a selected cell when the table view allows multiple row selections.
    public var multipleSelectionBackgroundView: UIView?
    
    // MARK: - Managing Accessory Views
    
    /// The type of standard accessory view the cell should use (normal state).
    ///
    /// The accessory view appears in the right side of the cell in the table view’s normal (default) state.
    /// The standard accessory views include the disclosure chevron; for a description of valid accessoryType constants,
    /// see `UITableViewCellAccessoryType`.
    /// The default is `.none`.
    /// If a custom accessory view is set through the accessoryView property, the value of this property is ignored.
    /// If the cell is enabled and the accessory type is detailDisclosureButton, the accessory view tracks touches and,
    /// when tapped, sends the data-source object a `tableView(_:accessoryButtonTappedForRowWith:)` message.
    ///
    /// The accessory-type image cross-fades between normal and editing states if it set for both states;
    /// use the `editingAccessoryType` property to set the accessory type for the cell during editing mode.
    /// If this property is not set for both states, the cell is animated to slide in or out, as necessary.
    public var accessoryType: UITableViewCellAccessoryType = .none
    
    /// A view that is used, typically as a control, on the right side of the cell (normal state).
    public var accessoryView: UIView?
    
    /// The type of standard accessory view the cell should use in the table view’s editing state.
    public var editingAccessoryType: UITableViewCellAccessoryType = .none
    
    /// A view that is used typically as a control on the right side of the cell when it is in editing mode.
    public var editingAccessoryView: UIView?
    
    // MARK: - Managing Cell Selection and Highlighting
    
    /// The style of selection for a cell.
    public var selectionStyle: UITableViewCellSelectionStyle = .blue
    
    /// A Boolean value that indicates whether the cell is selected.
    public var isSelected: Bool = false
    
    /// Sets the selected state of the cell, optionally animating the transition between states.
    public func setSelected(_ selected: Bool, animated: Bool) {
        
        
    }
    
    /// A Boolean value that indicates whether the cell is highlighted.
    public var isHighlighted: Bool = false
    
    /// Sets the highlighted state of the cell, optionally animating the transition between states.
    public func setHighlighted(_ highlighted: Bool, animated: Bool) {
        
        
    }
    
    // MARK: - Editing the Cell
    
    /// A Boolean value that indicates whether the cell is in an editable state.
    public var isEditing: Bool = false
    
    /// Toggles the receiver into and out of editing mode.
    public func setEditing(_ editing: Bool, animated: Bool) {
        
        
    }
    
    /// The editing style of the cell.
    public internal(set) var editingStyle: UITableViewCellEditingStyle = .none
    
    /// Returns whether the cell is currently showing the delete-confirmation button.
    ///
    /// When users tap the deletion control (the red circle to the left of the cell),
    /// the cell displays a "Delete" button on the right side of the cell; this string is localized.
    public internal(set) var showingDeleteConfirmation: Bool = false
    
    /// A Boolean value that determines whether the cell shows the reordering control.
    ///
    /// The reordering control is gray, multiple horizontal bar control on the right side of the cell.
    /// Users can drag this control to reorder the cell within the table.
    /// The default value is `false`.
    /// If the value is `true`, the reordering control temporarily replaces any accessory view.
    public var showsReorderControl: Bool = false
    
    // MARK: - Managing Content Indentation
    
    /// The indentation level of the cell’s content.
    ///
    /// The default value of the property is zero (no indentation).
    /// Assigning a positive value to this property indents the cell’s content from
    /// the left edge of the cell separator. The amount of indentation is equal to
    /// the indentation level multiplied by the value in the `indentationWidth` property.
    public var indentationLevel: Int = 0
    
    /// The width for each level of indentation of a cell's content.
    ///
    /// The default indentation width is 10.0 points.
    public var indentationWidth: CGFloat = 10
    
    /// A Boolean value that controls whether the cell background is indented when the table view is in editing mode.
    ///
    /// The default value is `true`.
    /// This property is unrelated to `indentationLevel`.
    /// The delegate can override this value in `tableView(_:shouldIndentWhileEditingRowAt:)`.
    /// This property has an effect only on table views created in the grouped style (`.grouped`);
    /// it has no effect on plain table views.
    public var shouldIndentWhileEditing: Bool = true
    
    /// The inset values for the cell’s content.
    ///
    /// You can use this property to add space between the current cell’s contents and the left and right edges of the table.
    /// Positive inset values move the cell content and cell separator inward and away from the table edges.
    /// Negative values are treated as if the inset is set to `0`.
    ///
    /// Only the left and right inset values are respected; the top and bottom inset values are ignored.
    /// The value assigned to this property takes precedence over any default separator insets set on the table view.
    public var separatorInset: UIEdgeInsets = UIEdgeInsets(top: 0, left: 15, bottom: 0, right: 0)
    
    // MARK: - Overriden Methods
    
    open override func layoutSubviews() {
        super.layoutSubviews()
        
        let bounds = self.bounds
        
        let isSeparatorVisible = separatorView.isHidden == false
        
        var contentFrame = CGRect(x: 0, y: 0, width: bounds.size.width, height: bounds.size.height - (isSeparatorVisible ? 1 : 0))
        
        if let accessoryView = self.accessoryView {
            
            /// calculate frame
            var frame = CGRect(x: bounds.size.width, y: 0, width: 0, height: 0)
            frame.size = accessoryView.sizeThatFits(bounds.size)
            frame.origin.x = bounds.size.width - frame.size.width
            frame.origin.y = round( 0.5 * (bounds.size.height - frame.size.height))
            
            // set accessory frame
            accessoryView.frame = frame
            
            // adjust content frame based on accessory
            contentFrame.size.width = frame.origin.x - 1
        }
        
        // set frames
        self.backgroundView?.frame = contentFrame
        self.selectedBackgroundView?.frame = contentFrame;
        self.contentView.frame = contentFrame;
        
        if isSeparatorVisible {
            
            separatorView.frame = CGRect(x: 0, y: bounds.size.height-1, width: bounds.size.width, height: 1)
        }
        
        // layout default subviews
        
    }
    
    // MARK: - Private
    
    internal static let defaultSize = CGSize(width: 320, height: UITableView.defaultRowHeight)
    
    private let style: UITableViewCellStyle
    
    // added as subview in `init()`
    private lazy var separatorView: SeparatorView = SeparatorView(frame: .zero)
    
    internal func configureSeparator(style: UITableViewCellSeparatorStyle, color: UIColor?) {
        
        separatorView.style = style
        separatorView.color = color
    }
    
    /// Arranges the subviews in the proper order
    private func orderSubviews() {
        
        if let view = selectedBackgroundView {
            
            sendSubview(toBack: view)
        }
        
        if let view = backgroundView {
            
            sendSubview(toBack: view)
        }
        
        bringSubview(toFront: contentView)
        
        if let view = accessoryView {
            
            bringSubview(toFront: view)
        }
        
        bringSubview(toFront: separatorView)
    }
    
}

// MARK: - Supporting Types

internal extension UITableViewCell {
    
    final class SeparatorView: UIView {
        
        var style: UITableViewCellSeparatorStyle = .none  {
            
            didSet {
                setNeedsDisplay()
                isHidden = style == .none
            }
        }
        
        var color: UIColor? {
            
            didSet { setNeedsDisplay() }
        }
        
        override init(frame: CGRect) {
            super.init(frame: frame)
            
            self.isHidden = true
        }
        
        override func draw(_ rect: CGRect) {
            
            guard let context = UIGraphicsGetCurrentContext(),
                let color = self.color,
                style != .none
                else { return }
            
            color.setStroke()
            
            let line = UIBezierPath()
            line.move(to: .zero)
            line.addLine(to: CGPoint(x: bounds.size.width, y: 0))
            line.lineWidth = 1
            
            switch style {
                
            case .none:
                
                break
                
            case .singleLine:
                
                line.stroke()
                
            case .singleLineEtched:
                
                context.saveGState()
                context.setLineDash(phase: 0, lengths: [2, 2])
                line.stroke()
                context.restoreGState()
            }
        }
    }
}

public enum UITableViewCellAccessoryType: Int {
    
    case none
    case disclosureIndicator
    case detailDisclosureButton
    case checkmark
}

public enum UITableViewCellSeparatorStyle: Int {
    
    case none
    case singleLine
    case singleLineEtched
}

public enum UITableViewCellStyle: Int {
    
    case `default`
    case value1
    case value2
    case subtitle
}

public enum UITableViewCellSelectionStyle: Int {
    
    case none
    case blue
    case gray
}

public enum UITableViewCellEditingStyle: Int {
    
    case none
    case delete
    case insert
}

// MARK: - ReusableView Protocol

internal protocol ReusableView {
    
    var reuseIdentifier: String? { get }
    
    func prepareForReuse()
}

extension UITableViewCell: ReusableView { }

