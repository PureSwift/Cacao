//
//  TableView.swift
//  Cacao
//
//  Created by Alsey Coleman Miller on 5/28/16.
//  Copyright © 2016 PureSwift. All rights reserved.
//

#if os(macOS)
    import Darwin.C.math
#elseif os(Linux)
    import Glibc
#endif

import Foundation

#if os(iOS)
import UIKit
import CoreGraphics
#else
import Silica
#endif

/// A view that presents data using rows arranged in a single column.
open class UITableView: UIScrollView {
    
    // MARK: - Initialization
    
    /// Initializes and returns a table view object having the given frame and style.
    public init(frame: CGRect, style: UITableViewStyle) {
        
        // UITableView properties
        self.style = style
        
        // initialize
        super.init(frame: frame)
        
        // setup common
        self.setupTableViewCommon()
    }
    
    public override convenience init(frame: CGRect) {
        
        self.init(frame: frame, style: .plain)
    }
    
    #if os(iOS)
    public required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    #endif
    
    // MARK: - Providing the Table View Data
    
    /// The object that acts as the data source of the table view.
    public weak var dataSource: UITableViewDataSource?
    
    // MARK: - Customizing the Table View Behavior
    
    /// The object that acts as the delegate of the table view.
    public weak var tableViewDelegate: UITableViewDelegate?
    
    /// The object that acts as the delegate of the table view.
    public override weak var delegate: UIScrollViewDelegate? {
        
        get { return tableViewDelegate }
        
        set { tableViewDelegate = delegate as? UITableViewDelegate }
    }
    
    // MARK: - Configuring a Table View
    
    /// the style of the table view.
    public let style: UITableViewStyle
    
    /// Returns the number of rows (table cells) in a specified section.
    public func numberOfRows(inSection section: Int) -> Int {
        
        return _dataSource.tableView(self, numberOfRowsInSection: section)
    }
    
    /// The number of sections in the table view.
    public var numberOfSections: Int {
        
        return _dataSource.numberOfSections(in: self)
    }
    
    /// The height of each row (that is, table cell) in the table view.
    public var rowHeight: CGFloat = UITableView.defaultRowHeight
    
    /// The style for table cells used as separators.
    public var separatorStyle: UITableViewCellSeparatorStyle = .singleLine
    
    /// The color of separator rows in the table view.
    public var separatorColor: UIColor? = UITableView.defaultSeparatorColor
    
    /// The effect applied to table separators.
    //public var separatorEffect: UIVisualEffect?
    
    /// The background view of the table view.
    public var backgroundView: UIView? {
        
        didSet {
            
            if backgroundView !== oldValue {
                
                oldValue?.removeFromSuperview()
                
                if let backgroundView = self.backgroundView {
                    
                    insertSubview(backgroundView, at: 0)
                }
            }
        }
    }
    
    /// Specifies the default inset of cell separators.
    public var separatorInset: UIEdgeInsets = UITableView.defaultSeparatorInset
    
    // MARK: - Creating Table View Cells
    
    /// Registers a class for use in creating new table cells.
    public func register(_ cellClass: UITableViewCell.Type?,
                         forCellReuseIdentifier identifier: String) {
        
        assert(identifier.isEmpty == false, "Identifier must not be an empty string")
        
        if let cellClass = cellClass {
            
            self.reuseIdentifiers.cells[identifier] = .class(cellClass)
            
        } else {
            
            self.reuseIdentifiers.cells[identifier] = nil
        }
    }
    
    /// Returns a reusable table-view cell object located by its identifier.
    ///
    /// - Returns: A `UITableViewCell` object with the associated identifier
    /// or nil if no such object exists in the reusable-cell queue.
    public func dequeueReusableCell(withIdentifier identifier: String) -> UITableViewCell? {
        
        return dequeue(with: identifier, cache: &cache.cells.reusable)
    }
    
    /// Returns a reusable table-view cell object for the specified reuse identifier and adds it to the table.
    public func dequeueReusableCell(withIdentifier identifier: String,
                                    for indexPath: IndexPath) -> UITableViewCell {
        
        if let existingCell = self.dequeueReusableCell(withIdentifier: identifier) {
            
            return existingCell
            
        } else {
            
            guard let registeredCell = self.reuseIdentifiers.cells[identifier]
                else { fatalError("No cell type registered for identifier \(identifier)") }
            
            // create new cell
            switch registeredCell {
                
            // initialize from cell class
            case let .class(tableViewCellClass):
                
                return tableViewCellClass.init(style: .default, reuseIdentifier: identifier)
            }
        }
    }
    
    // MARK: - Accessing Header and Footer Views
    
    public func register(_ viewClass: UITableViewHeaderFooterView.Type?,
                         forHeaderFooterViewReuseIdentifier identifier: String) {
        
        assert(identifier.isEmpty == false, "Identifier must not be an empty string")
        
        if let viewClass = viewClass {
            
            self.reuseIdentifiers.headerFooters[identifier] = .class(viewClass)
            
        } else {
            
            self.reuseIdentifiers.headerFooters[identifier] = nil
        }
    }
    
    /// Returns a reusable header or footer view located by its identifier.
    public func dequeueReusableHeaderFooterView(withIdentifier identifier: String) -> UITableViewHeaderFooterView? {
        
        if let registeredView = self.reuseIdentifiers.headerFooters[identifier] {
            
            // create new cell
            switch registeredView {
                
            // initialize from cell class
            case let .class(viewClass):
                
                return viewClass.init(reuseIdentifier: identifier)
            }
            
        } else {
            
            // not cached and not registered
            return nil
        }
    }
    
    /// Returns an accessory view that is displayed above the table.
    public var tableHeaderView: UIView? {
        
        didSet { didSetTableHeaderFooterView(newValue: tableHeaderView, oldValue: oldValue) }
    }
    
    /// Returns an accessory view that is displayed below the table.
    public var tableFooterView: UIView? {
        
        didSet { didSetTableHeaderFooterView(newValue: tableFooterView, oldValue: oldValue) }
    }
    
    /// The height of section headers in the table view.
    public var sectionHeaderHeight: CGFloat = UITableView.defaultHeaderFooterHeight
    
    /// The height of section footers in the table view.
    public var sectionFooterHeight: CGFloat = UITableView.defaultHeaderFooterHeight
    
    /// Returns the header view associated with the specified section.
    ///
    /// - Parameter section: An index number that identifies a section of the table.
    /// Table views in a plain style have a section index of zero.
    ///
    /// - Returns: The header view associated with the section, or nil if the section does not have a header view.
    public func headerView(forSection section: Int) -> UITableViewHeaderFooterView? {
        
        return cache.sections[section].headerView as? UITableViewHeaderFooterView
    }
    
    /// Returns the footer view associated with the specified section.
    ///
    /// - Parameter section: An index number that identifies a section of the table.
    /// Table views in a plain style have a section index of zero.
    ///
    /// - Returns: The footer view associated with the section, or nil if the section does not have a footer view.
    public func footerView(forSection section: Int) -> UITableViewHeaderFooterView? {
        
        return cache.sections[section].footerView as? UITableViewHeaderFooterView
    }
    
    // MARK: - Accessing Cells and Sections
    
    /// Returns the table cell at the specified index path.
    ///
    /// - Parameter indexPath: The index path locating the row in the table view.
    ///
    /// - Returns: An object representing a cell of the table,
    /// or `nil` if the cell is not visible or `indexPath` is out of range.
    public func cellForRow(at indexPath: IndexPath) -> UITableViewCell? {
        
        return cache.cells.cached[indexPath]
    }
    
    /// Returns an index path representing the row and section of a given table-view cell.
    ///
    /// - Returns: An index path representing the row and section of the cell, or nil if the index path is invalid.
    public func indexPath(for cell: UITableViewCell) -> IndexPath? {
        
        return cache.cells.cached.first(where: { $0.value === cell })?.key
    }
    
    /// Returns an index path identifying the row and section at the given point.
    public func indexPathForRow(at point: CGPoint) -> IndexPath? {
        
        let paths = indexPathsForRows(in: CGRect(x: point.x, y: point.y, width: 1, height: 1))
        
        return paths?.first
    }
    
    /// An array of index paths each representing a row enclosed by a given rectangle.
    ///
    /// - Parameter rect: A rectangle defining an area of the table view in local coordinates.
    ///
    /// - Returns: An array of `IndexPath` each representing a row and section index
    /// identifying a row within rect. Returns an empty array if there aren’t any rows to return.
    public func indexPathsForRows(in rect: CGRect) -> [IndexPath]? {
        
        // why is the return value for this an optional array Apple?
        // the docs state otherwise
        // bad Swift overlay
        // https://developer.apple.com/documentation/uikit/uitableview/1614991-indexpathsforrows
        
        updateSectionsCacheIfNeeded()
        
        var results = [IndexPath]()
        
        var offset = tableHeaderView?.frame.size.height ?? 0.0
        
        for (sectionIndex, section) in cache.sections.enumerated() {
            
            let rowHeights = section.rowHeights
            
            offset += section.headerHeight
            
            if (offset + section.rowsHeight) >= rect.origin.y {
                
                for (row, height) in rowHeights.enumerated() {
                    
                    let simpleRowRect = CGRect(x: rect.origin.x, y: offset, width: rect.size.width, height: height)
                    
                    let pastEnd = simpleRowRect.origin.y > rect.origin.y + rect.size.height
                    
                    if rect.intersects(simpleRowRect) {
                        
                        results.append(IndexPath(row: row, section: sectionIndex))
                        
                    } else if pastEnd {
                        
                        // do nothing
                    }
                    
                    offset += height
                }
                
            } else {
                
                offset += section.rowsHeight
            }
            
            offset += section.footerHeight
        }
        
        return results
    }
    
    /// The table cells that are visible in the table view.
    ///
    /// The value of this property is an array containing `UITableViewCell` objects,
    /// each representing a visible cell in the table view.
    public var visibleCells: [UITableViewCell] {
        
        return indexPathsForVisibleRows?.compactMap { cellForRow(at: $0) } ?? []
    }
    
    /// An array of index paths each identifying a visible row in the table view.
    public var indexPathsForVisibleRows: [IndexPath]? {
        
        layoutTableView()
        
        return Array(cache.cells.cached.keys)
            .filter { self.bounds.intersects(self.rectForRow(at: $0)) } // get visible cells
            .sorted()
    }
    
    // MARK: - Estimating Element Heights
    
    /// The estimated height of rows in the table view.
    public var estimatedRowHeight: CGFloat = 0.0
    
    /// The estimated height of section headers in the table view.
    public var estimatedSectionHeaderHeight: CGFloat = 0.0
    
    /// The estimated height of section footers in the table view.
    public var estimatedSectionFooterHeight: CGFloat = 0.0
    
    // MARK: - Scrolling the Table View
    
    /// Scrolls through the table view until a row identified by index path is at a particular location on the screen.
    public func scrollToRow(at indexPath: IndexPath,
                            at scrollPosition: UITableViewScrollPosition,
                            animated: Bool) {
        
        _scrollToRow(at: indexPath, at: scrollPosition, animated: animated)
    }
    
    // optional variant
    private func _scrollToRow(at indexPath: IndexPath?,
                            at scrollPosition: UITableViewScrollPosition,
                            animated: Bool) {
        
        scrollRectToVisible(_rectForRow(at: indexPath), at: scrollPosition, animated: animated)
    }
    
    /// Scrolls the table view so that the selected row nearest to a specified position in the table view is at that position.
    public func scrollToNearestSelectedRow(at scrollPosition: UITableViewScrollPosition,
                                           animated: Bool) {
        
        scrollRectToVisible(_rectForRow(at: indexPathForSelectedRow), at: scrollPosition, animated: animated)
    }
    
    // MARK: - Managing Selections
    
    /// An index path identifying the row and section of the selected row.
    public private(set) var indexPathForSelectedRow: IndexPath?
    
    /// The index paths representing the selected rows.
    public var indexPathsForSelectedRows: [IndexPath]? {
        
        if let indexPath = indexPathForSelectedRow {
            
            return [indexPath]
            
        } else {
            
            return nil
        }
    }
    
    /// Selects a row in the table view identified by index path, optionally scrolling the row to a location in the table view.
    public func selectRow(at indexPath: IndexPath?,
                          animated: Bool,
                          scrollPosition: UITableViewScrollPosition) {
        
        reloadDataIfNeeded()
        
        // deselect previous row, and select new one
        if indexPathForSelectedRow != indexPath {
            
            // deleselect old row
            if let indexPath = indexPathForSelectedRow {
                
                deselectRow(at: indexPath, animated: animated)
            }
            
            // set new value
            indexPathForSelectedRow = indexPath
            
            // select new row
            if let indexPath = indexPath {
                
                cellForRow(at: indexPath)?.isSelected = true
            }
        }
        
        // scroll to new row
        _scrollToRow(at: indexPath, at: scrollPosition, animated: animated)
    }
    
    /// Deselects a given row identified by index path, with an option to animate the deselection.
    public func deselectRow(at indexPath: IndexPath,
                            animated: Bool) {
        
        guard indexPath == indexPathForSelectedRow
            else { return }
        
        // FIXME: deselect animated
        self.cellForRow(at: indexPath)?.isSelected = false
        self.indexPathForSelectedRow = nil
    }
    
    /// A Boolean value that determines whether users can select a row.
    public var allowsSelection: Bool = true
    
    /// A Boolean value that determines whether users can select more than one row outside of editing mode.
    public var allowsMultipleSelection: Bool = false
    
    /// A Boolean value that determines whether users can select cells while the table view is in editing mode.
    public var allowsSelectionDuringEditing: Bool = false
    
    /// A Boolean value that controls whether users can select more than one cell simultaneously in editing mode.
    public var allowsMultipleSelectionDuringEditing: Bool = false
    
    // MARK: - Inserting, Deleting, and Moving Rows and Sections
    
    /// Inserts rows in the table view at the locations identified by an array of index paths, with an option to animate the insertion.
    public func insertRows(at indexPaths: [IndexPath],
                           with animation: UITableViewRowAnimation) {
        
        // FIXME: Animate
        reloadData()
    }
    
    /// Deletes the rows specified by an array of index paths, with an option to animate the deletion.
    public func deleteRows(at indexPaths: [IndexPath],
                           with animation: UITableViewRowAnimation) {
        
        // FIXME: Animate
        reloadData()
    }
    
    /// Moves the row at a specified location to a destination location.
    public func moveRow(at indexPath: IndexPath,
                        to newIndexPath: IndexPath) {
        
        // FIXME: Animate
        reloadData()
    }
    
    /// Inserts one or more sections in the table view, with an option to animate the insertion.
    public func insertSections(_ sections: IndexSet,
                               with animation: UITableViewRowAnimation) {
        
        // FIXME: Animate
        reloadData()
    }
    
    /// Deletes one or more sections in the table view, with an option to animate the deletion.
    public func deleteSections(_ sections: IndexSet,
                               with animation: UITableViewRowAnimation) {
        
        // FIXME: Animate
        reloadData()
    }
    
    /// Moves a section to a new location in the table view.
    public func moveSection(_ section: Int,
                            toSection newSection: Int) {
        
        // FIXME: Animate
        reloadData()
    }
    
    /// Animates multiple insert, delete, reload, and move operations as a group.
    public func performBatchUpdates(_ updates: (() -> Void)?,
                                    completion: ((Bool) -> Void)? = nil) {
        
        beginUpdates()
        
        updates?()
        
        endUpdates()
        
        completion?(true)
    }
    
    /// Begins a series of method calls that insert, delete, or select rows and sections of the table view.
    public func beginUpdates() {
        
        
    }
    
    /// Concludes a series of method calls that insert, delete, select, or reload rows and sections of the table view.
    public func endUpdates() {
        
        
    }
    
    // MARK: - Managing the Editing of Table Cells
    
    /// A Boolean value that determines whether the table view is in editing mode.
    public var isEditing: Bool = false
    
    /// Toggles the table view into and out of editing mode.
    public func setEditing(_ editing: Bool, 
                           animated: Bool) {
        
        // FIXME: Animate
        self.isEditing = editing
    }
    
    // MARK: - Reloading the Table View
    
    /// Reloads the rows and sections of the table view.
    public func reloadData() {
        
        // clear cache
        
        // remove previous cells
        cache.cells.cached.values.forEach { $0.removeFromSuperview() }
        cache.cells.cached.removeAll()
        
        cache.cells.reusable.forEach { $0.removeFromSuperview() }
        cache.cells.reusable.removeAll()
        
        // clear selection
        indexPathForSelectedRow = nil
        indexPathForHighlightedRow = nil
        
        // rebuild section cache
        updateSectionsCache()
        setContentSize()
        
        // reset reload flag
        needsReload = false
    }
    
    /// Reloads the specified rows using an animation effect.
    public func reloadRows(at indexPaths: [IndexPath],
                           with animation: UITableViewRowAnimation) {
        
        reloadData()
    }
    
    /// Reloads the specified sections using a given animation effect.
    public func reloadSections(_ sections: IndexSet,
                               with animation: UITableViewRowAnimation) {
        
        reloadData()
    }
    
    /// Reloads the items in the index bar along the right side of the table view.
    ///
    /// This method gives you a way to update the section index after inserting
    /// or deleting sections without having to reload the whole table.
    public func reloadSectionIndexTitles() {
        
        
    }
    
    // MARK: - Accessing Drawing Areas of the Table View
    
    /// Returns the drawing area for a specified section of the table view.
    public func rect(forSection section: Int) -> CGRect {
        
        updateSectionsCacheIfNeeded()
        
        return rect(fromVerticalOffset: offset(forSection: section), height: cache.sections[section].sectionHeight)
    }
    
    /// Returns the drawing area for a row identified by index path.
    ///
    /// - Returns: A rectangle defining the area in which the table view draws the row or `.zero` if `indexPath` is invalid.
    public func rectForRow(at indexPath: IndexPath) -> CGRect {
        
        return _rectForRow(at: indexPath)
    }
    
    private func _rectForRow(at indexPath: IndexPath?) -> CGRect {
        
        updateSectionsCacheIfNeeded()
        
        // validate
        guard let indexPath = indexPath, // non-nil
            indexPath.section < cache.sections.count, // valid section
            indexPath.row < cache.sections[indexPath.section].numberOfRows // valid row
            else { return .zero }
        
        let sectionIndex = indexPath.section
        
        let section = cache.sections[sectionIndex]
        
        let row = indexPath.row
        
        let offset = self.offset(forSection: sectionIndex)
            + section.headerHeight
            + (0 ..< row).reduce(0) { $0 + section.rowHeights[$1] }
        
        return self.rect(fromVerticalOffset: offset, height: section.rowHeights[row])
    }
    
    /// Returns the drawing area for the footer of the specified section.
    public func rectForFooter(inSection section: Int) -> CGRect {
        
        updateSectionsCacheIfNeeded()
        
        return rect(fromVerticalOffset: offset(forSection: section), height: cache.sections[section].footerHeight)
    }
    
    /// Returns the drawing area for the header of the specified section.
    public func rectForHeader(inSection section: Int) -> CGRect {
        
        updateSectionsCacheIfNeeded()
        
        return rect(fromVerticalOffset: offset(forSection: section), height: cache.sections[section].headerHeight)
    }
    
    // MARK: - Overridden Methods
    
    open override func layoutSubviews() {
        
        backgroundView?.frame = self.bounds
        reloadDataIfNeeded()
        layoutTableView()
        super.layoutSubviews()
    }
    
    open override var frame: CGRect {
        
        didSet {
            
            let newValue = frame
            
            if newValue != oldValue {
                
                if oldValue.size.width != newValue.size.width {
                    
                    updateSectionsCache()
                }
                
                setContentSize()
            }
        }
    }
    
    // MARK: - Private
    
    internal static let defaultRowHeight: CGFloat = 44
    
    internal static let defaultHeaderFooterHeight: CGFloat = 22
    
    internal static let defaultSeparatorColor = UIColor(red: 0.88, green: 0.88, blue: 0.88, alpha: 1.0)
    
    internal static let defaultSeparatorInset = UIEdgeInsets(top: 0, left: 15, bottom: 0, right: 0)
    
    private static let defaultDataSource = DefaultDataSource()
    
    private static let defaultDelegate = DefaultDelegate()
    
    private var _dataSource: UITableViewDataSource {
        
        get { return self.dataSource ?? UITableView.defaultDataSource }
    }
    
    private var _delegate: UITableViewDelegate {
        
        get { return self.tableViewDelegate ?? UITableView.defaultDelegate }
    }
    
    private var cache = Cache()
    
    private var reuseIdentifiers = ReuseIdentifiers()
    
    private var needsReload = true
    
    /// An index path identifying the row and section of the highlighted row.
    private var indexPathForHighlightedRow: IndexPath?
    
    private func setupTableViewCommon() {
        
        // set default values
        
        // UIScrollView properties
        self.showsHorizontalScrollIndicator = false
        self.showsVerticalScrollIndicator = true
        //self.alwaysBounceVertical = true
        self.bounces = true
        
        // UIView
        switch style {
        case .plain:
            self.backgroundColor = .white
        case .grouped:
            break
        }
    }
    
    @inline(__always)
    private func reloadDataIfNeeded() {
        
        if needsReload {
            
            reloadData()
        }
    }
    
    @inline(__always)
    private func updateSectionsCacheIfNeeded() {
        
        if cache.sections.isEmpty {
            
            updateSectionsCache()
        }
    }
    
    private func dequeue<View>(with identifier: String, cache: inout Set<View>) -> View?
        where View: UIView, View: ReusableView {
        
        guard let existingViewIndex = cache.index(where: { $0.reuseIdentifier == identifier })
            else { return nil }
        
        // get cell
        let view = cache[existingViewIndex]
        
        // prepare UI
        view.prepareForReuse()
        
        // remove from cache
        cache.remove(at: existingViewIndex)
        
        return view
    }
    
    private func didSetTableHeaderFooterView(newValue: UIView?, oldValue: UIView?) {
        
        guard newValue !== oldValue
            else { return }
        
        // remove old header from super view
        oldValue?.removeFromSuperview()
        
        // update content size
        setContentSize()
        
        // add header as subview
        if let view = newValue {
            
            self.addSubview(view)
        }
    }
    
    private func updateSectionsCache() {
        
        // remove previous headers / footers
        cache.sections.forEach {
            $0.headerView?.removeFromSuperview()
            $0.footerView?.removeFromSuperview()
        }
        
        cache.sections.removeAll()
        
        // rebuild cache
        guard let dataSource = self.dataSource else { return }
        
        // compute the heights/offsets of everything
        let numberOfSections = self.numberOfSections
        
        for sectionIndex in 0 ..< numberOfSections {
            
            let numberOfRowsInSection = self.numberOfRows(inSection: sectionIndex)
            
            let section = Section()
            section.headerTitle = dataSource.tableView(self, titleForHeaderInSection: sectionIndex)
            section.footerTitle = dataSource.tableView(self, titleForFooterInSection: sectionIndex)
            section.headerHeight = _delegate.tableView(self, heightForHeaderInSection: sectionIndex)
            section.footerHeight = _delegate.tableView(self, heightForFooterInSection: sectionIndex)
            
            if section.headerHeight > 0, let view = _delegate.tableView(self, viewForHeaderInSection: sectionIndex) {
                section.headerView = view
            }
            if section.footerHeight > 0, let view = _delegate.tableView(self, viewForFooterInSection: sectionIndex) {
                section.footerView = view
            }
            
            // default section header view
            if section.headerView == nil, section.headerHeight > 0, let headerTitle = section.headerTitle {
                section.headerView = SectionLabel(title: headerTitle)
            }
            // default section footer view
            if section.footerView == nil, section.footerHeight > 0, let footerTitle = section.footerTitle {
                section.footerView = SectionLabel(title: footerTitle)
            }
            
            if let headerView = section.headerView {
                addSubview(headerView)
            } else {
                section.headerHeight = 0
            }
            
            if let footerView = section.footerView {
                addSubview(footerView)
            } else {
                section.footerHeight = 0
            }
            
            section.rowHeights = [CGFloat](repeating: 0, count: numberOfRowsInSection)
            
            for row in 0 ..< numberOfRowsInSection {
                
                let rowHeight = _delegate.tableView(self, heightForRowAt: IndexPath(row: row, section: sectionIndex))
                section.rowHeights[row] = rowHeight
            }
            
            cache.sections.append(section)
        }
    }
    
    private func layoutTableView() {
        
        var tableViewHeight: CGFloat = 0
        
        let contentOffsetY = contentOffset.y
        let visibleBounds = CGRect(x: 0, y: abs(contentOffsetY), width: bounds.size.width, height: bounds.size.height)
        
        // layout header
        if let headerView = tableHeaderView {
            
            // adjust header frame
            headerView.frame.origin = .zero
            headerView.frame.size.width = bounds.size.width
            
            // add to table view height
            tableViewHeight += headerView.frame.size.height
        }
        
        // layout sections
        
        // get availible cached cells and clear old cache
        var oldCells = cache.cells.cached
        cache.cells.cached.removeAll()
        
        for (sectionIndex, section) in cache.sections.enumerated() {
            
            // get section rect
            let sectionRect = rect(forSection: sectionIndex)
            
            // add to table view height
            tableViewHeight += sectionRect.height
            
            // layout if section is visible
            guard sectionRect.intersects(visibleBounds)
                else { continue }
            
            // layout section header and footer
            section.headerView?.frame = rectForHeader(inSection: sectionIndex)
            section.footerView?.frame = rectForFooter(inSection: sectionIndex)
            
            // layout visible section rows
            for row in 0 ..< section.numberOfRows {
                
                // create index path for row in section
                let indexPath = IndexPath(row: row, section: sectionIndex)
                
                // get layout rect for row
                let rowRect = rectForRow(at: indexPath)
                
                // layout cell if visible
                guard rowRect.intersects(visibleBounds),
                    rowRect.size.height > 0
                    else { continue }
                
                // get cell from previous cache or data source
                let cell = oldCells[indexPath] ?? _dataSource.tableView(self, cellForRowAt: indexPath)
                
                // add to cached visible cells
                cache.cells.cached[indexPath] = cell
                
                // remove from old cache
                oldCells[indexPath] = nil
                
                // configure cell
                cell.frame = rowRect
                cell.tableView = self
                cell.backgroundColor = backgroundColor
                cell.isHighlighted = indexPath == indexPathForHighlightedRow
                cell.isSelected = indexPathsForSelectedRows?.contains(indexPath) ?? false
                cell.configureSeparator(style: separatorStyle, color: separatorColor)
                
                // add cell as subview
                if subviews.contains(cell) == false {
                    
                    addSubview(cell)
                }
            }
        }
        
        // keep non-visible old cells with a reuse identifier in the reusable queue
        oldCells.values
            .forEach { $0.removeFromSuperview() }
        
        oldCells.values
            .filter { $0.reuseIdentifier?.isEmpty ?? false }
            .forEach { cache.cells.reusable.insert($0) }
        
        // layout table view footer
        if let footerView = tableFooterView {
            
            footerView.frame.origin = CGPoint(x: 0, y: tableViewHeight)
            footerView.frame.size.width = bounds.size.width
        }
    }
    
    private func setContentSize() {
        
        updateSectionsCacheIfNeeded()
        
        // calculate content height
        let height = (tableHeaderView?.frame.size.height ?? 0)
            + cache.sections.reduce(0) { $0 + $1.sectionHeight }
            + (tableFooterView?.frame.size.height ?? 0)
        
        self.contentSize = CGSize(width: 0, height: height)
    }
    
    private func scrollRectToVisible(_ rect: CGRect, at scrollPosition: UITableViewScrollPosition, animated: Bool) {
        
        var rect = rect
        
        if rect.isNull == false, rect.size.height > 0 {
            
            switch scrollPosition {
                
            case .none: break
                
            case .top:
                
                rect.size.height = self.bounds.size.height
                
            case .middle:
                
                rect.origin.y -= (self.bounds.size.height / 2.0) - rect.size.height
                rect.size.height = self.bounds.size.height
                
            case .bottom:
                
                rect.origin.y -= self.bounds.size.height - rect.size.height
                rect.size.height = self.bounds.size.height
            }
            
            self.scrollRectToVisible(rect, animated: animated)
        }
    }
    
    @inline(__always)
    private func rect(fromVerticalOffset verticalOffset: CGFloat, height: CGFloat) -> CGRect {
        
        return CGRect(x: 0, y: verticalOffset, width: self.bounds.size.width, height: height)
    }
    
    private func offset(forSection section: Int) -> CGFloat {
        
        updateSectionsCacheIfNeeded()
        
        var offset = self.tableHeaderView?.frame.size.height ?? 0
        
        for index in 0 ..< section {
            
            offset += cache.sections[index].sectionHeight
        }
        
        return offset
    }
}

// MARK: - Private Supporting Types

private extension UITableView {
    
    final class Cache {
        
        var sections = [Section]()
        var cells = (reusable: Set<UITableViewCell>(), cached: [IndexPath: UITableViewCell]())
    }
    
    final class ReuseIdentifiers {
        
        enum Cell {
            
            case `class`(UITableViewCell.Type)
            //case nib(UINib)
        }
        
        enum HeaderFooter {
            
            case `class`(UITableViewHeaderFooterView.Type)
            //case nib(UINib)
        }
        
        var cells = [String: Cell]()
        var headerFooters = [String: HeaderFooter]()
    }
    
    final class Section {
        
        var headerHeight: CGFloat = 0.0
        var footerHeight: CGFloat = 0.0
        var rowHeights = [CGFloat]()
        var headerView: UIView?
        var footerView: UIView?
        var headerTitle: String?
        var footerTitle: String?
        
        var numberOfRows: Int {
            
            @inline(__always)
            get { return rowHeights.count }
        }
        
        var rowsHeight: CGFloat {
            
            @inline(__always)
            get { return rowHeights.reduce(0, { $0 + $1 }) }
        }
        
        var sectionHeight: CGFloat {
            
            @inline(__always)
            get { return self.rowsHeight + self.headerHeight + self.footerHeight }
        }
    }
    
    class SectionLabel: UILabel {
        
        init(title: String) {
            super.init(frame: CGRect())
            self.font = UIFont.boldSystemFont(ofSize: 17)
            self.textColor = .white
            self.backgroundColor = UIColor(red: 0.9, green: 0.9, blue: 0.9, alpha: 0.8)
            //self.shadowColor = UIColor(red: (100 / 255.0), green: (105 / 255.0), blue: (110 / 255.0))
            //self.shadowOffset = CGSize(width: 0, height: 1)
        }
        
        #if os(iOS)
        public required init?(coder aDecoder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
        #endif
        
        override func draw(_ rect: CGRect) {
            /*
            let size: CGSize = bounds.size
            UIColor(red: CGFloat(166 / 255.0), green: CGFloat(177 / 255.0), blue: CGFloat(187 / 255.0), alpha: CGFloat(1)).setFill()
            UIRectFill(CGRect(x: 0, y: 0, width: size.width, height: 1.0))
            var startColor = UIColor(red: CGFloat(145 / 255.0), green: CGFloat(158 / 255.0), blue: CGFloat(171 / 255.0), alpha: CGFloat(1))
            var endColor = UIColor(red: CGFloat(185 / 255.0), green: CGFloat(193 / 255.0), blue: CGFloat(201 / 255.0), alpha: CGFloat(1))
            var colorSpace = CGColorSpaceCreateDeviceRGB()
            var locations: [CGFloat] = [0.0, 1.0]
            let gradientColors = [startColor.cgColor, endColor.cgColor]
            var gradient = CGGradientCreateWithColors(colorSpace, gradientColors, locations)
            UIGraphicsGetCurrentContext()?.drawLinearGradient(gradient, start: CGPoint(x: CGFloat(0.0), y: CGFloat(1.0)), end: CGPoint(x: CGFloat(0.0), y: CGFloat(size.height - 1.0)), options: [])
            UIColor(red: CGFloat(153 / 255.0), green: CGFloat(158 / 255.0), blue: CGFloat(165 / 255.0), alpha: CGFloat(1)).setFill()
            UIRectFill(CGRect(x: CGFloat(0.0), y: CGFloat(size.height - 1.0), width: CGFloat(size.width), height: CGFloat(1.0)))
             */
            super.draw(rect)
        }
    }
    
    /// Default data source
    final class DefaultDataSource: UITableViewDataSource {
        
        fileprivate init() { }
        
        func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
            
            return 0
        }
        
        func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
            
            fatalError("Should never request cell for table view with default data source")
        }
    }
    
    final class DefaultDelegate: UITableViewDelegate {
        
        fileprivate init() { }
    }
}

fileprivate final class UITableViewSubviewManager {
    
    private(set) weak var tableView: UITableView!
    
    private(set) var cellsReadyForReuse = [IndexPath: UITableViewCell]()
    
    private(set) var reusableCells = Set<UITableViewCell>()
    
    private(set)var dropAnimationCells = Set<UITableViewCell>()
    
    private(set) var reusePreventedCells = Set<UITableViewCell>()
    
    fileprivate init(tableView: UITableView) {
        
        self.tableView = tableView
    }
    
    func beginDropAnimation(for cell: UITableViewCell) {
        
        
    }
}

// MARK: - Supporting Types

/// The style of the table view.
public enum UITableViewStyle: Int {
    
    case plain
    case grouped
}

/// The position in the table view (top, middle, bottom) to which a given row is scrolled.
public enum UITableViewScrollPosition: Int {
    
    case none
    case top
    case middle
    case bottom
}

/// The type of animation when rows are inserted or deleted.
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

/// Requests icon to be shown in the section index of a table view.
///
/// If the data source includes this constant string in the array of strings it returns
/// in `sectionIndexTitles(for:)`, the section index displays a magnifying glass icon at
/// the corresponding index location. This location should generally be the first title in the index.
// http://stackoverflow.com/questions/235120/whats-the-uitableview-index-magnifying-glass-character
public let UITableViewIndexSearch: String = "{search}"

/// The default value for a given dimension.
///
/// Requests that UITableView use the default value for a given dimension.
public let UITableViewAutomaticDimension: CGFloat = -1.0

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

public extension UITableViewDataSource {
    
    func numberOfSections(in tableView: UITableView) -> Int { return 1 }
    
    func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? { return nil }
    
    func tableView(_ tableView: UITableView, titleForFooterInSection section: Int) -> String? { return nil }
    
    // Individual rows can opt out of having the -editing property set for them. If not implemented, all rows are assumed to be editable.
    func tableView(_ tableView: UITableView, canEditRowAt indexPath: IndexPath) -> Bool { return false }
    
    func tableView(_ tableView: UITableView, canMoveRowAt indexPath: IndexPath) -> Bool { return false }
    
    func sectionIndexTitles(for tableView: UITableView) -> [String]? { return nil }
    
    func tableView(_ tableView: UITableView, sectionForSectionIndexTitle title: String, at index: Int) -> Int { return index }
    
    func tableView(_ tableView: UITableView, commit editingStyle: UITableViewCellEditingStyle, forRowAt indexPath: IndexPath) { }
    
    func tableView(_ tableView: UITableView, moveRowAt sourceIndexPath: IndexPath, to destinationIndexPath: IndexPath) { }
}

public protocol UITableViewDelegate: UIScrollViewDelegate {
    
    func tableView(_ tableView: UITableView, willDisplay cell: UITableViewCell, forRowAt indexPath: IndexPath)
    
    func tableView(_ tableView: UITableView, willDisplayHeaderView view: UIView, forSection section: Int)
    
    func tableView(_ tableView: UITableView, willDisplayFooterView view: UIView, forSection section: Int)
    
    func tableView(_ tableView: UITableView, didEndDisplaying cell: UITableViewCell, forRowAt indexPath: IndexPath)
    
    func tableView(_ tableView: UITableView, didEndDisplayingHeaderView view: UIView, forSection section: Int)
    
    func tableView(_ tableView: UITableView, didEndDisplayingFooterView view: UIView, forSection section: Int)
    
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat
    
    func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat
    
    func tableView(_ tableView: UITableView, heightForFooterInSection section: Int) -> CGFloat
    
    func tableView(_ tableView: UITableView, estimatedHeightForRowAt indexPath: IndexPath) -> CGFloat
    
    func tableView(_ tableView: UITableView, estimatedHeightForHeaderInSection section: Int) -> CGFloat
    
    func tableView(_ tableView: UITableView, estimatedHeightForFooterInSection section: Int) -> CGFloat
    
    func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView?
    
    func tableView(_ tableView: UITableView, viewForFooterInSection section: Int) -> UIView?
    
    func tableView(_ tableView: UITableView, accessoryButtonTappedForRowWith indexPath: IndexPath)
    
    func tableView(_ tableView: UITableView, shouldHighlightRowAt indexPath: IndexPath) -> Bool
    
    func tableView(_ tableView: UITableView, didHighlightRowAt indexPath: IndexPath)
    
    func tableView(_ tableView: UITableView, didUnhighlightRowAt indexPath: IndexPath)
    
    func tableView(_ tableView: UITableView, willSelectRowAt indexPath: IndexPath) -> IndexPath?
    
    func tableView(_ tableView: UITableView, willDeselectRowAt indexPath: IndexPath) -> IndexPath?
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath)
    
    func tableView(_ tableView: UITableView, didDeselectRowAt indexPath: IndexPath)
    
    func tableView(_ tableView: UITableView, editingStyleForRowAt indexPath: IndexPath) -> UITableViewCellEditingStyle
    
    func tableView(_ tableView: UITableView, titleForDeleteConfirmationButtonForRowAt indexPath: IndexPath) -> String?
    
    func tableView(_ tableView: UITableView, editActionsForRowAt indexPath: IndexPath) -> [UITableViewRowAction]?
    
    func tableView(_ tableView: UITableView, shouldIndentWhileEditingRowAt indexPath: IndexPath) -> Bool
    
    func tableView(_ tableView: UITableView, willBeginEditingRowAt indexPath: IndexPath)
    
    func tableView(_ tableView: UITableView, didEndEditingRowAt indexPath: IndexPath?)
    
    func tableView(_ tableView: UITableView,
                   targetIndexPathForMoveFromRowAt sourceIndexPath: IndexPath,
                   toProposedIndexPath proposedDestinationIndexPath: IndexPath) -> IndexPath
}

public extension UITableViewDelegate {
    
    func tableView(_ tableView: UITableView, willDisplay cell: UITableViewCell, forRowAt indexPath: IndexPath) { }
    
    func tableView(_ tableView: UITableView, willDisplayHeaderView view: UIView, forSection section: Int) { }
    
    func tableView(_ tableView: UITableView, willDisplayFooterView view: UIView, forSection section: Int) { }
    
    func tableView(_ tableView: UITableView, didEndDisplaying cell: UITableViewCell, forRowAt indexPath: IndexPath) { }
    
    func tableView(_ tableView: UITableView, didEndDisplayingHeaderView view: UIView, forSection section: Int) { }
    
    func tableView(_ tableView: UITableView, didEndDisplayingFooterView view: UIView, forSection section: Int) { }
    
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat { return tableView.rowHeight }
    
    func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat { return tableView.sectionHeaderHeight }
    
    func tableView(_ tableView: UITableView, heightForFooterInSection section: Int) -> CGFloat { return tableView.sectionFooterHeight }
    
    func tableView(_ tableView: UITableView, estimatedHeightForRowAt indexPath: IndexPath) -> CGFloat { return tableView.estimatedRowHeight }
    
    func tableView(_ tableView: UITableView, estimatedHeightForHeaderInSection section: Int) -> CGFloat { return tableView.estimatedSectionHeaderHeight }
    
    func tableView(_ tableView: UITableView, estimatedHeightForFooterInSection section: Int) -> CGFloat { return tableView.estimatedSectionFooterHeight }
    
    func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? { return nil }
    
    func tableView(_ tableView: UITableView, viewForFooterInSection section: Int) -> UIView?  { return nil }
    
    func tableView(_ tableView: UITableView, accessoryButtonTappedForRowWith indexPath: IndexPath) { }
    
    func tableView(_ tableView: UITableView, shouldHighlightRowAt indexPath: IndexPath) -> Bool  { return true }
    
    func tableView(_ tableView: UITableView, didHighlightRowAt indexPath: IndexPath) { }
    
    func tableView(_ tableView: UITableView, didUnhighlightRowAt indexPath: IndexPath) { }
    
    func tableView(_ tableView: UITableView, willSelectRowAt indexPath: IndexPath) -> IndexPath?  { return indexPath }
    
    func tableView(_ tableView: UITableView, willDeselectRowAt indexPath: IndexPath) -> IndexPath? { return indexPath }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) { }
    
    func tableView(_ tableView: UITableView, didDeselectRowAt indexPath: IndexPath) { }
    
    func tableView(_ tableView: UITableView, editingStyleForRowAt indexPath: IndexPath) -> UITableViewCellEditingStyle { return .delete }
    
    func tableView(_ tableView: UITableView, titleForDeleteConfirmationButtonForRowAt indexPath: IndexPath) -> String? { return nil }
    
    func tableView(_ tableView: UITableView, editActionsForRowAt indexPath: IndexPath) -> [UITableViewRowAction]? { return nil }
    
    func tableView(_ tableView: UITableView, shouldIndentWhileEditingRowAt indexPath: IndexPath) -> Bool { return true }
    
    func tableView(_ tableView: UITableView, willBeginEditingRowAt indexPath: IndexPath) { }
    
    func tableView(_ tableView: UITableView, didEndEditingRowAt indexPath: IndexPath?) { }
    
    func tableView(_ tableView: UITableView,
                   targetIndexPathForMoveFromRowAt sourceIndexPath: IndexPath,
                   toProposedIndexPath proposedDestinationIndexPath: IndexPath) -> IndexPath {
        
        return proposedDestinationIndexPath
    }
}
