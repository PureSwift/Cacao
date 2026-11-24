//
//  DBusMenuInterface.swift
//  CacaoDBusMenu
//
//  Created by Alsey Coleman Miller on 11/24/26.
//

public import DBus

/// The names of `com.canonical.dbusmenu`, the D-Bus interface apps serve
/// their menus with, and the global menu bars of KDE, Unity and this
/// desktop read.
public enum DBusMenuInterface {

    /// The interface.
    public static let name = DBusInterface(rawValue: "com.canonical.dbusmenu")!

    /// The version of the interface the exporter serves.
    public static let version: UInt32 = 3

    /// The object path apps serve their main menu at, by convention.
    public static let defaultPath = DBusObjectPath(rawValue: "/MenuBar")!

    // MARK: Methods

    static let getLayout = DBusMember(rawValue: "GetLayout")!
    static let getGroupProperties = DBusMember(rawValue: "GetGroupProperties")!
    static let getProperty = DBusMember(rawValue: "GetProperty")!
    static let event = DBusMember(rawValue: "Event")!
    static let eventGroup = DBusMember(rawValue: "EventGroup")!
    static let aboutToShow = DBusMember(rawValue: "AboutToShow")!
    static let aboutToShowGroup = DBusMember(rawValue: "AboutToShowGroup")!

    // MARK: Signals

    static let itemsPropertiesUpdated = DBusMember(rawValue: "ItemsPropertiesUpdated")!
    static let layoutUpdated = DBusMember(rawValue: "LayoutUpdated")!
    static let itemActivationRequested = DBusMember(rawValue: "ItemActivationRequested")!
}

/// The direction labels read in, which the menu bar lays menus out by.
public enum DBusMenuTextDirection: String, Sendable, CaseIterable {

    /// Left to right.
    case leftToRight = "ltr"

    /// Right to left.
    case rightToLeft = "rtl"
}

/// Whether the menu asks for attention.
public enum DBusMenuStatus: String, Sendable, CaseIterable {

    /// Shown as usual.
    case normal

    /// Shown so the user notices it, as when the app is asked for something
    /// from its menus.
    case notice
}

/// An error from a menu's app, or from a call to it.
public enum DBusMenuError: Error, Equatable, Sendable {

    /// The menu has no item with this identifier.
    case unknownItem(Int32)

    /// The app answered with something the interface doesn't allow.
    case invalidReply(String)
}
