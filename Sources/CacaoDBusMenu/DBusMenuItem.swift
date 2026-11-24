//
//  DBusMenuItem.swift
//  CacaoDBusMenu
//
//  Created by Alsey Coleman Miller on 11/24/26.
//

/// An item of a menu, with the items of its submenu: what an app exports
/// and a menu bar reads.
///
/// The menu itself is an item too, the root, whose identifier is 0 and
/// whose children are the menus in the bar (or the items of a context
/// menu). Every other item has an identifier of its own, which stays the
/// same while the item is in the menu, so clicks find it after updates.
public struct DBusMenuItem: Identifiable, Hashable, Sendable {

    /// The root's identifier.
    public static let rootID: Int32 = 0

    /// The item's identifier, unique in the menu.
    public var id: Int32

    /// What kind of item it is.
    public var type: ItemType

    /// The label, with an underscore before the mnemonic's character and
    /// doubled underscores for underscores shown. `DBusMenuLabel` reads
    /// and makes them.
    public var label: String

    /// Whether the item can be chosen.
    public var isEnabled: Bool

    /// Whether the item is shown.
    public var isVisible: Bool

    /// The name of an icon in the icon theme, shown before the label.
    public var iconName: String?

    /// A PNG of an icon, shown before the label when there's no `iconName`.
    public var iconData: [UInt8]?

    /// The keys that choose the item: shown by the menu bar, and handled by
    /// the app.
    public var shortcut: DBusMenuShortcut?

    /// Whether the item shows a checkmark or radio button, if it's a toggle.
    public var toggleType: ToggleType?

    /// The toggle's state, if the item is one.
    public var toggleState: ToggleState

    /// How the item is presented: as information, or as a warning.
    public var disposition: Disposition

    /// A description for screen readers, when the label isn't enough.
    public var accessibleDescription: String?

    /// Whether the item opens a submenu: whether it has children, or will
    /// when asked with `AboutToShow`.
    public var isSubmenu: Bool

    /// The items of the submenu.
    public var children: [DBusMenuItem]

    public init(
        id: Int32,
        type: ItemType = .standard,
        label: String = "",
        isEnabled: Bool = true,
        isVisible: Bool = true,
        iconName: String? = nil,
        iconData: [UInt8]? = nil,
        shortcut: DBusMenuShortcut? = nil,
        toggleType: ToggleType? = nil,
        toggleState: ToggleState = .off,
        disposition: Disposition = .normal,
        accessibleDescription: String? = nil,
        isSubmenu: Bool? = nil,
        children: [DBusMenuItem] = []
    ) {
        self.id = id
        self.type = type
        self.label = label
        self.isEnabled = isEnabled
        self.isVisible = isVisible
        self.iconName = iconName
        self.iconData = iconData
        self.shortcut = shortcut
        self.toggleType = toggleType
        self.toggleState = toggleState
        self.disposition = disposition
        self.accessibleDescription = accessibleDescription
        self.isSubmenu = isSubmenu ?? !children.isEmpty
        self.children = children
    }
}

// MARK: - Making items

public extension DBusMenuItem {

    /// A menu: the root, holding the menus of the bar or the items of a
    /// context menu.
    static func root(_ children: [DBusMenuItem]) -> DBusMenuItem {
        DBusMenuItem(id: rootID, isSubmenu: true, children: children)
    }

    /// A line between groups of items.
    static func separator(id: Int32) -> DBusMenuItem {
        DBusMenuItem(id: id, type: .separator)
    }

    /// An item with a title, which is shown as it is: underscores in it
    /// aren't mnemonics.
    init(
        id: Int32,
        title: String,
        isEnabled: Bool = true,
        shortcut: DBusMenuShortcut? = nil,
        children: [DBusMenuItem] = []
    ) {
        self.init(
            id: id,
            label: DBusMenuLabel(title: title).rawValue,
            isEnabled: isEnabled,
            shortcut: shortcut,
            children: children
        )
    }

    /// The label as shown, without its mnemonic's marker.
    var title: String {
        DBusMenuLabel(rawValue: label).title
    }
}

// MARK: - Supporting types

public extension DBusMenuItem {

    /// What kind of item an item is.
    enum ItemType: String, Hashable, Sendable, CaseIterable {

        /// An item that can be chosen, or that opens a submenu.
        case standard

        /// A line between groups of items.
        case separator
    }

    /// The control a toggle shows.
    enum ToggleType: String, Hashable, Sendable, CaseIterable {

        /// A checkmark, for an item that's on or off on its own.
        case checkmark

        /// A radio button, for one of a group of items, of which one is on.
        case radio
    }

    /// Whether a toggle is on.
    enum ToggleState: Int32, Hashable, Sendable, CaseIterable {

        case off = 0

        case on = 1

        /// Neither: some of what it stands for is on, as a dash shows.
        case indeterminate = -1

        /// The state a `toggle-state` value stands for: values other than 0
        /// and 1 are indeterminate.
        public init(value: Int32) {
            self = ToggleState(rawValue: value) ?? .indeterminate
        }
    }

    /// How an item is presented.
    enum Disposition: String, Hashable, Sendable, CaseIterable {

        case normal

        /// Information for the user.
        case informative

        /// Something the user should be careful of.
        case warning

        /// Something that went wrong.
        case alert
    }
}

// MARK: - Finding items

public extension DBusMenuItem {

    /// The item with an identifier, this one or one in its submenus.
    func item(withID id: Int32) -> DBusMenuItem? {
        if self.id == id {
            return self
        }
        for child in children {
            if let item = child.item(withID: id) {
                return item
            }
        }
        return nil
    }

    /// Changes the item with an identifier, this one or one in its
    /// submenus. Returns whether there was one.
    @discardableResult
    mutating func modifyItem(withID id: Int32, _ modify: (inout DBusMenuItem) -> Void) -> Bool {
        if self.id == id {
            modify(&self)
            return true
        }
        for index in children.indices {
            if children[index].modifyItem(withID: id, modify) {
                return true
            }
        }
        return false
    }

    /// Calls `body` with this item and every item in its submenus, parents
    /// before their children.
    func forEach(_ body: (DBusMenuItem) throws -> Void) rethrows {
        try body(self)
        for child in children {
            try child.forEach(body)
        }
    }
}
