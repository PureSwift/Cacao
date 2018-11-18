//
//  UITableViewCell.swift
//  Cacao
//
//  Created by Alsey Coleman Miller on 6/26/17.
//

import Foundation

#if os(iOS)
import UIKit
import CoreGraphics
#else
import Silica
#endif

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
        
        self.setupTableViewCellCommon()
    }
    
    #if os(iOS)
    public required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    #endif
    
    // MARK: - Reusing Cells
    
    /// A string used to identify a cell that is reusable.
    public let reuseIdentifier: String?
    
    /// Prepares a reusable cell for reuse by the table view's delegate.
    open func prepareForReuse() { } // default implementation is empty
    
    // MARK: - Managing the Predefined Content
    
    /// Returns the label used for the main textual content of the table cell.
    public var textLabel: UILabel? { return _contentView.textLabel }
    
    /// Returns the secondary label of the table cell if one exists.
    public var detailTextLabel: UILabel? { return _contentView.detailTextLabel }
    
    /// Returns the image view of the table cell.
    public var imageView: UIImageView? { return _contentView.imageView }
    
    // MARK: - Accessing Views of the Cell Object
    
    /// Returns the content view of the cell object.
    ///
    /// The content view of a `UITableViewCell` object is the default superview for content displayed by the cell.
    /// If you want to customize cells by simply adding additional views, you should add them to the content view
    /// so they will be positioned appropriately as the cell transitions into and out of editing mode.
    public var contentView: UIView { return _contentView }
    private lazy var _contentView: UITableViewCellContentView = UITableViewCellContentView(frame: CGRect(origin: .zero, size: self.bounds.size), cell: self)
    
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
    public var separatorInset: UIEdgeInsets = UITableView.defaultSeparatorInset
    
    // MARK: - Overriden Methods
    
    open override func layoutSubviews() {
        super.layoutSubviews()
        
        // layoutFloatingContentView()
        
        // UIKit`-[UITableViewCellLayoutManager layoutSubviewsOfCell:]:
        // UIKit`-[UITableViewCell layoutSubviews]:
        // https://gist.github.com/colemancda/7d39b640cca32849e0d33c17f8761270
        UITableViewCellLayoutManager.layoutSubviews(of: self)
    }
    
    // MARK: - Private
    
    internal static let defaultSize = CGSize(width: 320, height: UITableView.defaultRowHeight)
    
    internal weak var tableView: UITableView?
    
    @_versioned
    internal let style: UITableViewCellStyle
    
    // added as subview in `init()`
    fileprivate lazy var separatorView: UITableViewCellSeparatorView = UITableViewCellSeparatorView()
    
    internal func configureSeparator(style: UITableViewCellSeparatorStyle, color: UIColor?) {
        
        separatorView.style = style
        separatorView.color = color
    }
    
    private func setupTableViewCellCommon() {
        
        // add mandatory subviews
        self.addSubview(separatorView)
        self.addSubview(contentView)
        
        // layout subviews
        self.layoutIfNeeded()
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
    
    /// Called after default text label's text is changed
    fileprivate func contentViewLabelTextDidChange(_ label: UITableViewLabel) {
        
        setNeedsLayout()
    }
}

// MARK: - Supporting Types

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

// MARK: - Private Supporting Types

internal final class UITableViewCellContentView: UIView {
    
    private(set) weak var cell: UITableViewCell!
    
    /// Returns the label used for the main textual content of the table cell.
    private(set) weak var textLabel: UITableViewLabel?
    
    /// Returns the secondary label of the table cell if one exists.
    private(set) weak var detailTextLabel: UITableViewLabel?
    
    /// Returns the image view of the table cell.
    private(set) weak var imageView: UIImageView?
    
    var isLayoutEngineSuspended: Bool = false
    
    required init(frame: CGRect, cell: UITableViewCell) {
        super.init(frame: frame)
        
        self.cell = cell
        
        // setup predefined views
        self.tableViewCellContentViewCommonSetup()
    }
    
    #if os(iOS)
    public required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    #endif
    
    private func tableViewCellContentViewCommonSetup() {
        
        // should only be called once
        assert(self.textLabel == nil)
        
        guard let cell = self.cell
            else { fatalError("No cell configured") }
        
        let textLabel = UITableViewCellLayoutManager.textLabel(for: cell)
        let detailTextLabel = UITableViewCellLayoutManager.detailTextLabel(for: cell)
        let imageView = UITableViewCellLayoutManager.imageView(for: cell)
        
        // add subviews
        let contentSubviews: [UIView?] = [textLabel, detailTextLabel, imageView]
        
        // add as subviews to content view
        contentSubviews.forEach {
            if let view = $0 {
                self.addSubview(view)
            }
        }
        
        // set properties
        self.textLabel = textLabel
        self.detailTextLabel = detailTextLabel
        self.imageView = imageView
    }
    
    override func layoutSubviews() {
        
        let contentFrame = self.frame
        
        let style = self.cell.style
        
        // layout default subviews
        switch style {
            
        case .default:
            
            let imageWidth = imageView?.image?.size.width ?? 0.0
            
            let imageViewFrame = CGRect(x: 5, y: 0, width: imageWidth, height: contentFrame.size.height)
            
            let textLabelX = imageViewFrame.origin.x + 15
            
            let textLabelFrame = CGRect(x: textLabelX, y: 0, width: contentFrame.size.width - textLabelX, height: contentFrame.size.height)
            
            imageView?.frame = imageViewFrame
            
            textLabel?.frame = textLabelFrame
            
            assert(detailTextLabel == nil, "No detail text label for \(style)")
            
        case .subtitle:
            
            // FIXME: subtitle layout
            break
            
        case .value1:
            
            // FIXME: value1 layout
            break
            
        case .value2:
            
            // FIXME: value2 layout
            break
        }
    }
}

/// Actual name is `_UITableViewCellSeparatorView`
internal typealias UITableViewCellSeparatorView = _UITableViewCellSeparatorView

internal final class _UITableViewCellSeparatorView: UIView {
    
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
    
    #if os(iOS)
    public required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    #endif
    
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

internal final class UITableViewCellSelectedBackground: UIView {
    
    
}

internal struct UITableViewCellLayoutManager {
    
    static func layoutSubviews(of cell: UITableViewCell) {
        
        let bounds = cell.bounds
        
        let isSeparatorVisible = cell.separatorView.isHidden == false
        
        var contentFrame = CGRect(x: 0, y: 0, width: bounds.size.width, height: bounds.size.height - (isSeparatorVisible ? 1 : 0))
        
        if let accessoryView = cell.accessoryView {
            
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
        
        // set content frames
        cell.backgroundView?.frame = contentFrame
        cell.selectedBackgroundView?.frame = contentFrame;
        cell.contentView.frame = contentFrame;
        
        // set separator frame
        let separatorFrame = CGRect(x: cell.separatorInset.left,
                                    y: bounds.size.height - 1,
                                    width: bounds.size.width - (cell.separatorInset.right + cell.separatorInset.left),
                                    height: 1)
        
        cell.separatorView.frame = isSeparatorVisible ? separatorFrame : .zero
    }
    
    @inline(__always)
    static private func createLabel(for cell: UITableViewCell) -> UITableViewLabel {
        
        return UITableViewLabel(frame: .zero, cell: cell)
    }
    
    static func textLabel(for cell: UITableViewCell) -> UITableViewLabel {
        
        let style = cell.style
        
        let label = createLabel(for: cell)
        
        switch style {
            
        case .default:
            
            break
            
        case .subtitle:
            
            break
            
        case .value1:
            
            break
            
        case .value2:
            
            break
        }
        
        return label
    }
    
    static func detailTextLabel(for cell: UITableViewCell) -> UITableViewLabel? {
        
        let style = cell.style
        
        switch style {
            
        case .default:
            
            return nil
            
        case .subtitle:
            
            let label = createLabel(for: cell)
            
            return label
            
        case .value1:
            
            let label = createLabel(for: cell)
            
            return label
            
        case .value2:
            
            let label = createLabel(for: cell)
            
            return label
        }
    }
    
    static func imageView(for cell: UITableViewCell) -> UIImageView? {
        
        let style = cell.style
        
        switch style {
            
        case .default:
            
            let imageView = UIImageView()
            
            return imageView
            
        case .subtitle:
            
            let imageView = UIImageView()
            
            return imageView
            
        case .value1, .value2:
            
            return nil
        }
    }
    /*
    static func backgroundEndingRect(for cell: UITableViewCell) -> CGRect {
        
        
    }*/
}

internal class UITableViewLabel: UILabel {
    
    private(set) weak var cell: UITableViewCell!
    
    override var text: String? {
        
        didSet {
            
            guard text != oldValue else { return }
            
            // inform cell of text change
            cell?.contentViewLabelTextDidChange(self)
        }
    }
    
    required init(frame: CGRect, cell: UITableViewCell) {
        super.init(frame: frame)
        
        self.cell = cell
    }
    
    #if os(iOS)
    public required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    #endif
}

// MARK: - ReusableView Protocol

internal protocol ReusableView {
    
    var reuseIdentifier: String? { get }
    
    func prepareForReuse()
}

extension UITableViewCell: ReusableView { }

