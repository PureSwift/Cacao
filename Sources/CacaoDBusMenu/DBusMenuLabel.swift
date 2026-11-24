//
//  DBusMenuLabel.swift
//  CacaoDBusMenu
//
//  Created by Alsey Coleman Miller on 11/24/26.
//

/// A menu item's label as dbusmenu writes it: an underscore marks the
/// mnemonic, the character the user can press to choose the item while
/// its menu is open, and two underscores are one shown.
///
/// ```swift
/// DBusMenuLabel(rawValue: "_File").title      // "File"
/// DBusMenuLabel(rawValue: "_File").mnemonic   // "F"
/// DBusMenuLabel(title: "Save_As").rawValue    // "Save__As"
/// ```
public struct DBusMenuLabel: RawRepresentable, Hashable, Sendable {

    /// The label, with its markers.
    public let rawValue: String

    public init(rawValue: String) {
        self.rawValue = rawValue
    }

    /// A label showing `title`, with the mnemonic at a character offset in
    /// it, if any.
    public init(title: String, mnemonicOffset: Int? = nil) {
        var label = ""
        for (offset, character) in title.enumerated() {
            if offset == mnemonicOffset {
                label.append("_")
            }
            if character == "_" {
                label.append("__")
            } else {
                label.append(character)
            }
        }
        self.rawValue = label
    }

    /// The text shown, without the markers.
    public var title: String {
        parsed.title
    }

    /// The mnemonic's character offset in `title`, for underlining it.
    public var mnemonicOffset: Int? {
        parsed.mnemonicOffset
    }

    /// The mnemonic, if the label has one.
    public var mnemonic: Character? {
        let parsed = parsed
        guard let offset = parsed.mnemonicOffset else { return nil }
        return Array(parsed.title)[offset]
    }

    /// The title and the first mnemonic; a marker at the end marks nothing.
    private var parsed: (title: String, mnemonicOffset: Int?) {
        var title = ""
        var count = 0
        var mnemonicOffset: Int?
        var characters = rawValue.makeIterator()
        while let character = characters.next() {
            guard character == "_" else {
                title.append(character)
                count += 1
                continue
            }
            guard let next = characters.next() else { break }
            if next != "_", mnemonicOffset == nil {
                mnemonicOffset = count
            }
            title.append(next)
            count += 1
        }
        return (title, mnemonicOffset)
    }
}
