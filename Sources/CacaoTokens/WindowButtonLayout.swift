//
//  WindowButtonLayout.swift
//  CacaoTokens
//
//  Created by Alsey Coleman Miller on 11/24/26.
//

import Foundation

/// Which window buttons a title bar shows, and at which end.
///
/// Cacao's title bars put close, minimize and maximize at the leading end.
/// A desktop can ask for another order with GNOME's `button-layout`
/// setting, in `org.gnome.desktop.wm.preferences`, which the settings
/// portal serves:
///
/// ```swift
/// WindowButtonLayout(setting: "close,minimize:maximize")
/// // close and minimize at the leading end, maximize at the trailing
/// ```
public struct WindowButtonLayout: Hashable, Sendable {

    /// A window button.
    public enum Button: String, Hashable, Sendable, CaseIterable {

        /// Closes the window.
        case close

        /// Hides the window in the dock.
        case minimize

        /// Makes the window fill the screen, or puts it back.
        case maximize
    }

    /// The buttons at the title bar's leading end, from the edge in.
    public var leading: [Button]

    /// The buttons at the title bar's trailing end, in order toward the
    /// edge.
    public var trailing: [Button]

    public init(leading: [Button], trailing: [Button] = []) {
        self.leading = leading
        self.trailing = trailing
    }

    /// Cacao's: close, minimize and maximize at the leading end.
    public static let standard = WindowButtonLayout(leading: [.close, .minimize, .maximize])

    /// The layout a `button-layout` setting describes: names separated by
    /// commas, the leading end's before a colon and the trailing end's
    /// after it, as in `close,minimize,maximize:` or `appmenu:close`.
    ///
    /// What isn't a window button, such as `appmenu`, `icon` or `spacer`,
    /// is left out, and so is a button named twice after the first time.
    /// A setting without a colon is all leading.
    public init(setting: String) {
        let ends = setting.split(separator: ":", maxSplits: 1, omittingEmptySubsequences: false)
        var seen = Set<Button>()
        func buttons(_ end: Substring?) -> [Button] {
            guard let end else { return [] }
            return end.split(separator: ",").compactMap { name in
                guard let button = Button(rawValue: name.trimmingCharacters(in: .whitespaces)),
                      seen.insert(button).inserted else {
                    return nil
                }
                return button
            }
        }
        let leading = buttons(ends.first)
        let trailing = buttons(ends.count > 1 ? ends[1] : nil)
        self.init(leading: leading, trailing: trailing)
    }

    /// The layout as a `button-layout` setting.
    public var setting: String {
        leading.map(\.rawValue).joined(separator: ",") + ":" + trailing.map(\.rawValue).joined(separator: ",")
    }

    /// Every button shown, leading end first.
    public var buttons: [Button] {
        leading + trailing
    }
}
