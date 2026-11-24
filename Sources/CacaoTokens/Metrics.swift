//
//  Metrics.swift
//  CacaoTokens
//
//  Created by Alsey Coleman Miller on 11/23/26.
//

import Foundation
#if canImport(CoreGraphics)
import CoreGraphics
#endif

public extension StyleTokens {

    /// Corner radii, in points.
    ///
    /// Radii grow with the size of what they round: 4 for the smallest
    /// controls, 6 for controls, 8 for menus, 10 for windows. Shapes inside
    /// a rounded container take the container's radius less the inset, so
    /// a menu item 4 points inside an 8-point menu is rounded by 4.
    struct Radii: Hashable, Sendable {

        /// A checkbox.
        public var checkbox: CGFloat = 4

        /// Push buttons, segmented controls and text fields.
        public var control: CGFloat = 6

        /// A search field: fully round at the regular control height, a
        /// pill.
        public var searchField: CGFloat = 16

        /// A selected row in a sidebar or list, inset from its edges.
        public var selection: CGFloat = 6

        /// A menu.
        public var menu: CGFloat = 8

        /// A menu's highlighted item, inset `Metrics.menuInset` inside it.
        public var menuItem: CGFloat = 4

        /// The highlight behind an open menu bar title.
        public var menuBarItem: CGFloat = 5

        /// Popovers, sheets and alerts.
        public var popover: CGFloat = 10

        /// A window's top corners. Its bottom corners are square where the
        /// window meets a screen edge, and rounded the same elsewhere.
        public var window: CGFloat = 10

        public init() { }
    }

    /// Sizes, paddings and spacing, in points.
    ///
    /// Spacing steps by 4. Controls are 32 points tall: a 14-point label's
    /// line, about 18 points, with 7 points above and below. The title bar
    /// fits the window buttons with 10 points around them, and a title bar
    /// joined with a toolbar fits a regular control the same way.
    struct Metrics: Hashable, Sendable {

        // MARK: Spacing

        /// Between items in a tight group, like a label and its icon.
        public var spacingTight: CGFloat = 4

        /// Between controls in a row.
        public var spacing: CGFloat = 8

        /// Between rows of a form.
        public var spacingLoose: CGFloat = 12

        /// Between a window's edges and its content.
        public var contentPadding: CGFloat = 16

        /// Between groups of controls.
        public var groupSpacing: CGFloat = 24

        // MARK: Window

        /// The desktop's menu bar.
        public var menuBarHeight: CGFloat = 28

        /// Space before and after a menu bar title.
        public var menuBarItemPadding: CGFloat = 10

        /// A title bar on its own.
        public var titleBarHeight: CGFloat = 38

        /// A title bar joined with a toolbar.
        public var unifiedToolbarHeight: CGFloat = 52

        /// A toolbar below the title bar.
        public var toolbarHeight: CGFloat = 44

        /// The diameter of a window button.
        public var windowButtonSize: CGFloat = 18

        /// The size of a window button's glyph.
        public var windowButtonGlyphSize: CGFloat = 8

        /// Between window buttons.
        public var windowButtonSpacing: CGFloat = 8

        /// From the window's leading edge to the first window button.
        public var windowButtonInset: CGFloat = 12

        /// A window's border.
        public var windowBorderWidth: CGFloat = 1

        // MARK: Controls

        /// A small control, for dense panels.
        public var smallControlHeight: CGFloat = 24

        /// A regular control.
        public var controlHeight: CGFloat = 32

        /// A large control, for the main action of a dialog or a touch
        /// screen.
        public var largeControlHeight: CGFloat = 40

        /// Space before and after a small control's label.
        public var smallControlPadding: CGFloat = 8

        /// Space before and after a regular control's label.
        public var controlPadding: CGFloat = 12

        /// Space before and after a large control's label.
        public var largeControlPadding: CGFloat = 16

        /// The narrowest a push button with a label gets.
        public var buttonMinimumWidth: CGFloat = 72

        /// A control's border.
        public var borderWidth: CGFloat = 1

        /// The side of a checkbox.
        public var checkboxSize: CGFloat = 18

        /// The stroke of a check or dash.
        public var checkmarkWidth: CGFloat = 2

        /// Between a checkbox and its label.
        public var checkboxLabelSpacing: CGFloat = 8

        /// The magnifier in a search field.
        public var searchFieldIconSize: CGFloat = 14

        /// The focus ring's width.
        public var focusRingWidth: CGFloat = 3

        /// Between a control's edge and its focus ring. The ring's corners
        /// are the control's radius plus this and the ring's width.
        public var focusRingOffset: CGFloat = 0

        // MARK: Lists and menus

        /// A hairline separator.
        public var separatorWidth: CGFloat = 1

        /// A sidebar's width, until the user resizes it.
        public var sidebarWidth: CGFloat = 220

        /// A sidebar row.
        public var sidebarRowHeight: CGFloat = 30

        /// How far a sidebar's selection is inset from the sidebar's edges.
        public var sidebarSelectionInset: CGFloat = 8

        /// A list or table row.
        public var listRowHeight: CGFloat = 32

        /// A menu item.
        public var menuItemHeight: CGFloat = 26

        /// Space before a menu item's title and after its key equivalent.
        public var menuItemPadding: CGFloat = 12

        /// How far a menu's items, and their highlight, are inset from its
        /// edges.
        public var menuInset: CGFloat = 4

        /// The height a separator takes in a menu: its line and the space
        /// around it.
        public var menuSeparatorHeight: CGFloat = 9

        /// The narrowest a menu gets.
        public var menuMinimumWidth: CGFloat = 180

        public init() { }
    }
}
