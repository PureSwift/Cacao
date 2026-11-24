//
//  DBusMenuShortcut.swift
//  CacaoDBusMenu
//
//  Created by Alsey Coleman Miller on 11/24/26.
//

/// The keys that choose a menu item, as dbusmenu's `shortcut` property
/// holds them: the modifiers' names, then the key's, such as
/// `["Control", "q"]`.
///
/// Keys are named as X keysyms are, which is what GTK's and Qt's exporters
/// send: a character for most (`q`, `1`), and a name for the rest
/// (`comma`, `Return`, `F5`). Modifiers are `Control`, `Alt`, `Shift` and
/// `Super`. On this desktop, Mac apps' Command key is Super, so a menu bar
/// can show their shortcuts with the glyphs they were written with.
public struct DBusMenuShortcut: Hashable, Sendable {

    /// The modifier keys held.
    public var modifiers: Modifiers

    /// The key's name.
    public var key: String

    public init(_ key: String, modifiers: Modifiers = []) {
        self.key = key
        self.modifiers = modifiers
    }

    /// The shortcut for a character, such as `q` or `,`, named as the
    /// property names it.
    public init(character: Character, modifiers: Modifiers = []) {
        self.init(Self.keyName(for: character), modifiers: modifiers)
    }

    /// A shortcut from the property's names. Modifiers may come in any
    /// order, and Qt's names (`Ctrl`, `Meta`) are read too; returns `nil`
    /// without a key.
    public init?(keys: [String]) {
        guard let key = keys.last, !key.isEmpty else { return nil }
        var modifiers: Modifiers = []
        for name in keys.dropLast() {
            guard let modifier = Modifiers(name: name) else { return nil }
            modifiers.insert(modifier)
        }
        self.init(key, modifiers: modifiers)
    }

    /// The names the property holds: the modifiers, in the order Control,
    /// Alt, Shift, Super, then the key.
    public var keys: [String] {
        Modifiers.ordered.filter { modifiers.contains($0.modifier) }.map(\.name) + [key]
    }
}

// MARK: - Modifiers

public extension DBusMenuShortcut {

    /// Modifier keys.
    struct Modifiers: OptionSet, Hashable, Sendable {

        public let rawValue: UInt8

        public init(rawValue: UInt8) {
            self.rawValue = rawValue
        }

        public static let control = Modifiers(rawValue: 1 << 0)

        public static let alt = Modifiers(rawValue: 1 << 1)

        public static let shift = Modifiers(rawValue: 1 << 2)

        /// The logo key: Command, for Mac apps on this desktop.
        public static let `super` = Modifiers(rawValue: 1 << 3)

        /// The modifiers, with their names, in the order they're written.
        static let ordered: [(modifier: Modifiers, name: String)] = [
            (.control, "Control"),
            (.alt, "Alt"),
            (.shift, "Shift"),
            (.super, "Super"),
        ]

        /// The modifier a name stands for.
        init?(name: String) {
            switch name.lowercased() {
            case "control", "ctrl", "primary": self = .control
            case "alt", "mod1", "option": self = .alt
            case "shift": self = .shift
            case "super", "meta", "logo", "command", "mod4": self = .super
            default: return nil
            }
        }
    }
}

// MARK: - Showing

public extension DBusMenuShortcut {

    /// The shortcut as a Mac menu shows it: the modifiers' glyphs, in the
    /// order Control, Option, Shift, Command (Super), then the key's, such
    /// as `⇧⌘D`.
    var glyphs: String {
        var string = ""
        if modifiers.contains(.control) { string += "⌃" }
        if modifiers.contains(.alt) { string += "⌥" }
        if modifiers.contains(.shift) { string += "⇧" }
        if modifiers.contains(.super) { string += "⌘" }
        return string + keyGlyph
    }

    /// The key as menus show it: a capital for a letter, a symbol for a
    /// named key with one, and the name otherwise.
    var keyGlyph: String {
        if let glyph = Self.glyphs[key] {
            return glyph
        }
        if let character = character {
            return String(character).uppercased()
        }
        return String(key.map { $0 == "_" ? " " : $0 })
    }

    /// The character the key types, if it types one.
    var character: Character? {
        if key.count == 1 {
            return key.first
        }
        return Self.characters[key]
    }
}

// MARK: - Key names

extension DBusMenuShortcut {

    /// Keysym names of characters that aren't their own name.
    static let characters: [String: Character] = [
        "space": " ",
        "exclam": "!",
        "quotedbl": "\"",
        "numbersign": "#",
        "dollar": "$",
        "percent": "%",
        "ampersand": "&",
        "apostrophe": "'",
        "parenleft": "(",
        "parenright": ")",
        "asterisk": "*",
        "plus": "+",
        "comma": ",",
        "minus": "-",
        "period": ".",
        "slash": "/",
        "colon": ":",
        "semicolon": ";",
        "less": "<",
        "equal": "=",
        "greater": ">",
        "question": "?",
        "at": "@",
        "bracketleft": "[",
        "backslash": "\\",
        "bracketright": "]",
        "asciicircum": "^",
        "underscore": "_",
        "grave": "`",
        "braceleft": "{",
        "bar": "|",
        "braceright": "}",
        "asciitilde": "~",
    ]

    /// Names of characters, the other way.
    static let names: [Character: String] = Dictionary(
        uniqueKeysWithValues: characters.map { ($0.value, $0.key) }
    )

    /// Symbols for named keys, as Mac menus show them.
    static let glyphs: [String: String] = [
        "Return": "↩",
        "KP_Enter": "⌤",
        "Escape": "⎋",
        "Tab": "⇥",
        "BackSpace": "⌫",
        "Delete": "⌦",
        "Up": "↑",
        "Down": "↓",
        "Left": "←",
        "Right": "→",
        "Page_Up": "⇞",
        "Page_Down": "⇟",
        "Home": "↖",
        "End": "↘",
        "space": "Space",
    ]

    /// Named keys for the control characters that stand for them, such as
    /// `\r` for Return.
    static let controlNames: [Character: String] = [
        "\r": "Return",
        "\n": "Return",
        "\u{1B}": "Escape",
        "\t": "Tab",
        "\u{8}": "BackSpace",
        "\u{7F}": "Delete",
    ]

    /// The keysym name of the key that types a character.
    static func keyName(for character: Character) -> String {
        if let name = controlNames[character] ?? names[character] {
            return name
        }
        return String(character).lowercased()
    }
}
