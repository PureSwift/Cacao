//
//  DBusMenuEvent.swift
//  CacaoDBusMenu
//
//  Created by Alsey Coleman Miller on 11/24/26.
//

public import DBus

/// Something the user did to a menu item, which the menu bar tells the app
/// with `Event`.
public struct DBusMenuEvent: Hashable, Sendable {

    /// What happened.
    public enum Kind: Hashable, Sendable {

        /// The item was chosen: the app performs its action.
        case clicked

        /// The pointer is over the item.
        case hovered

        /// The item's submenu opened.
        case opened

        /// The item's submenu closed.
        case closed

        /// An event the interface doesn't name.
        case other(String)

        /// The kind an `eventId` names.
        public init(rawValue: String) {
            switch rawValue {
            case "clicked": self = .clicked
            case "hovered": self = .hovered
            case "opened": self = .opened
            case "closed": self = .closed
            default: self = .other(rawValue)
            }
        }

        /// The `eventId` it's sent as.
        public var rawValue: String {
            switch self {
            case .clicked: "clicked"
            case .hovered: "hovered"
            case .opened: "opened"
            case .closed: "closed"
            case let .other(name): name
            }
        }
    }

    /// The item's identifier.
    public var id: Int32

    public var kind: Kind

    /// What the event carries, which none of the named events use.
    public var data: DBusMessageArgument

    /// When it happened, in the X server's or compositor's time, if the
    /// menu bar knows: an app can use it to raise its window.
    public var timestamp: UInt32

    public init(id: Int32, kind: Kind, data: DBusMessageArgument = .int32(0), timestamp: UInt32 = 0) {
        self.id = id
        self.kind = kind
        self.data = data
        self.timestamp = timestamp
    }
}
