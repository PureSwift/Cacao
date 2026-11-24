//
//  Fonts.swift
//  CacaoTokens
//
//  Created by Alsey Coleman Miller on 11/23/26.
//

import CacaoRender
import Foundation
#if canImport(CoreGraphics)
import CoreGraphics
#endif

public extension StyleTokens {

    /// Fonts, in points: the system font, which fontconfig picks on Linux
    /// (`name` is `nil`), and its monospaced design.
    ///
    /// The body size is 14: the 10.5 to 11-point desktop fonts common on
    /// Linux are 14 to 14.7 pixels at 96 dots per inch, and a whole number
    /// keeps glyphs on the pixel grid at 1× and 2×. Smaller and larger
    /// sizes step by about a fifth.
    struct Fonts: Hashable, Sendable {

        /// Body text, list rows and labels.
        public var body = ResolvedFont(size: 14)

        /// Body text that stands out, like a section's first line.
        public var headline = ResolvedFont(size: 14, weight: 600)

        /// Supporting text: subtitles, status lines, sidebar sections.
        public var callout = ResolvedFont(size: 12)

        /// The smallest text: captions and badges.
        public var caption = ResolvedFont(size: 11)

        /// A view's title.
        public var title = ResolvedFont(size: 20, weight: 600)

        /// A large title, at the top of a page or a welcome window.
        public var largeTitle = ResolvedFont(size: 28, weight: 700)

        /// A window's title, in its title bar.
        public var windowTitle = ResolvedFont(size: 14, weight: 600)

        /// A regular control's label.
        public var control = ResolvedFont(size: 14)

        /// A small control's label.
        public var smallControl = ResolvedFont(size: 12)

        /// A default button's label: a little heavier, as it's the one to
        /// press.
        public var defaultControl = ResolvedFont(size: 14, weight: 500)

        /// A menu item's title.
        public var menu = ResolvedFont(size: 14)

        /// A menu bar title.
        public var menuBar = ResolvedFont(size: 14)

        /// The menu bar title of the focused app's own menu.
        public var menuBarApplication = ResolvedFont(size: 14, weight: 700)

        /// Code and other fixed-width text.
        public var monospace = ResolvedFont(size: 13, design: .monospaced)

        public init() { }
    }
}
