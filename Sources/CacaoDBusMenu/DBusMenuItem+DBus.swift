//
//  DBusMenuItem+DBus.swift
//  CacaoDBusMenu
//
//  Created by Alsey Coleman Miller on 11/24/26.
//

public import DBus

// MARK: - Properties

public extension DBusMenuItem {

    /// The properties dbusmenu gives an item, by their names on the bus.
    enum Property: String, Hashable, Sendable, CaseIterable {
        case type = "type"
        case label = "label"
        case enabled = "enabled"
        case visible = "visible"
        case iconName = "icon-name"
        case iconData = "icon-data"
        case shortcut = "shortcut"
        case toggleType = "toggle-type"
        case toggleState = "toggle-state"
        case childrenDisplay = "children-display"
        case disposition = "disposition"
        case accessibleDescription = "accessible-desc"
    }

    /// The item's properties that aren't their defaults, which are what the
    /// bus carries: a property left out has its default.
    var properties: [Property: DBusMessageArgument] {
        var properties: [Property: DBusMessageArgument] = [:]
        if type != .standard {
            properties[.type] = .string(type.rawValue)
        }
        if !label.isEmpty {
            properties[.label] = .string(label)
        }
        if !isEnabled {
            properties[.enabled] = .boolean(false)
        }
        if !isVisible {
            properties[.visible] = .boolean(false)
        }
        if let iconName, !iconName.isEmpty {
            properties[.iconName] = .string(iconName)
        }
        if let iconData, !iconData.isEmpty {
            properties[.iconData] = .array(DBusMessageArgument.Array(type: .byte, iconData.map { .byte($0) })!)
        }
        if let shortcut {
            let chord = DBusMessageArgument.Array(type: .string, shortcut.keys.map { .string($0) })!
            properties[.shortcut] = .array(DBusMessageArgument.Array(type: .array(.string), [.array(chord)])!)
        }
        if let toggleType {
            properties[.toggleType] = .string(toggleType.rawValue)
            properties[.toggleState] = .int32(toggleState.rawValue)
        }
        if isSubmenu {
            properties[.childrenDisplay] = .string("submenu")
        }
        if disposition != .normal {
            properties[.disposition] = .string(disposition.rawValue)
        }
        if let accessibleDescription, !accessibleDescription.isEmpty {
            properties[.accessibleDescription] = .string(accessibleDescription)
        }
        return properties
    }

    /// Sets a property from its value on the bus, or back to its default
    /// with `nil`, as when `ItemsPropertiesUpdated` removes it. Values of
    /// the wrong type are read as the default, and properties this doesn't
    /// know are ignored.
    mutating func setProperty(_ name: String, to value: DBusMessageArgument?) {
        guard let property = Property(rawValue: name) else { return }
        let value = value.map(Self.unwrapped)
        switch property {
        case .type:
            type = value?.string.flatMap(ItemType.init(rawValue:)) ?? .standard
        case .label:
            label = value?.string ?? ""
        case .enabled:
            isEnabled = value?.boolean ?? true
        case .visible:
            isVisible = value?.boolean ?? true
        case .iconName:
            iconName = value?.string.flatMap { $0.isEmpty ? nil : $0 }
        case .iconData:
            if case let .array(array)? = value {
                let bytes = array.compactMap { element -> UInt8? in
                    if case let .byte(byte) = element { byte } else { nil }
                }
                iconData = bytes.isEmpty ? nil : bytes
            } else {
                iconData = nil
            }
        case .shortcut:
            shortcut = value.flatMap(Self.shortcut(from:))
        case .toggleType:
            toggleType = value?.string.flatMap(ToggleType.init(rawValue:))
        case .toggleState:
            if case let .int32(state)? = value {
                toggleState = ToggleState(value: state)
            } else {
                // The interface's default.
                toggleState = .indeterminate
            }
        case .childrenDisplay:
            isSubmenu = value?.string == "submenu"
        case .disposition:
            disposition = value?.string.flatMap(Disposition.init(rawValue:)) ?? .normal
        case .accessibleDescription:
            accessibleDescription = value?.string.flatMap { $0.isEmpty ? nil : $0 }
        }
    }

    /// The first chord of a `shortcut` value, an `aas`.
    private static func shortcut(from value: DBusMessageArgument) -> DBusMenuShortcut? {
        guard case let .array(chords) = value,
              case let .array(chord)? = chords.first else {
            return nil
        }
        return DBusMenuShortcut(keys: chord.compactMap(\.string))
    }

    /// The value inside any variants.
    private static func unwrapped(_ value: DBusMessageArgument) -> DBusMessageArgument {
        var value = value
        while case let .variant(variant) = value {
            value = variant.element
        }
        return value
    }
}

// MARK: - Layout

package extension DBusMenuItem {

    /// The item's properties as an `a{sv}`, those named in `names` or all
    /// of them when it's empty.
    func propertiesArgument(names: Set<String> = []) -> DBusMessageArgument {
        let entries = properties
            .filter { names.isEmpty || names.contains($0.key.rawValue) }
            .sorted { $0.key.rawValue < $1.key.rawValue }
            .map { DBusMessageArgument.Dictionary.Entry(key: .string($0.key.rawValue), value: .variant(.init($0.value))) }
        return .dictionary(DBusMessageArgument.Dictionary(keyType: .string, valueType: .variant, entries)!)
    }

    /// The item and its submenus to a depth (-1 for all, 0 for none) as a
    /// `(ia{sv}av)`, as `GetLayout` answers.
    func layoutArgument(depth: Int32 = -1, propertyNames: Set<String> = []) -> DBusMessageArgument {
        let children: [DBusMessageArgument] = depth == 0 ? [] : self.children.map {
            .variant(.init($0.layoutArgument(depth: depth - 1, propertyNames: propertyNames)))
        }
        return .struct(DBusMessageArgument.Structure([
            .int32(id),
            propertiesArgument(names: propertyNames),
            .array(DBusMessageArgument.Array(type: .variant, children)!),
        ])!)
    }

    /// The item and its submenus from a `(ia{sv}av)`.
    init(layout: DBusMessageArgument) throws(DBusMenuError) {
        var layout = layout
        while case let .variant(variant) = layout {
            layout = variant.element
        }
        guard case let .struct(structure) = layout, structure.count == 3,
              case let .int32(id) = structure[0],
              case let .dictionary(properties) = structure[1],
              case let .array(children) = structure[2] else {
            throw .invalidReply("A layout isn't a (ia{sv}av)")
        }
        self.init(id: id, isSubmenu: false)
        for entry in properties {
            if case let .string(name) = entry.key {
                setProperty(name, to: entry.value)
            }
        }
        self.children = try children.map { child throws(DBusMenuError) in
            try DBusMenuItem(layout: child)
        }
        if !self.children.isEmpty {
            isSubmenu = true
        }
    }

    /// The item's identifier and properties as a `(ia{sv})`, as
    /// `GetGroupProperties` answers and `ItemsPropertiesUpdated` sends.
    func itemPropertiesArgument(names: Set<String> = []) -> DBusMessageArgument {
        .struct(DBusMessageArgument.Structure([.int32(id), propertiesArgument(names: names)])!)
    }
}

// MARK: - Accessors

extension DBusMessageArgument {

    var string: String? {
        if case let .string(string) = self { string } else { nil }
    }

    var boolean: Bool? {
        if case let .boolean(boolean) = self { boolean } else { nil }
    }

    var int32: Int32? {
        if case let .int32(value) = self { value } else { nil }
    }

    var uint32: UInt32? {
        if case let .uint32(value) = self { value } else { nil }
    }
}
