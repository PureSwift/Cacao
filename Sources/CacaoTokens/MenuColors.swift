//
//  MenuColors.swift
//  CacaoTokens
//
//  Created by Alsey Coleman Miller on 11/23/26.
//

import CacaoRender

public extension StyleTokens {

    /// Menus: pop-up, context, and those the menu bar opens.
    struct MenuColors: Hashable, Sendable {

        /// The menu: opaque, so it reads the same wherever it opens and
        /// needs no blur.
        public var background: ResolvedColor

        /// The line around the menu.
        public var border: ResolvedColor

        public var shadow: Shadow

        /// An item's title.
        public var text: ResolvedColor

        /// A disabled item's title.
        public var disabledText: ResolvedColor

        /// An item's key equivalent, at its trailing end.
        public var shortcutText: ResolvedColor

        /// The highlighted item: the accent.
        public var highlight: ResolvedColor

        /// The highlighted item's title, key equivalent and glyphs.
        public var highlightText: ResolvedColor

        /// The line between groups of items.
        public var separator: ResolvedColor

        init(_ resolver: Resolver) {
            background = resolver.pick(light: Palette.neutral0, dark: Palette.neutral800)
            border = resolver.pick(light: Palette.black.opacity(0.14), dark: Palette.black.opacity(0.7), highLight: Palette.black.opacity(0.6), highDark: Palette.white.opacity(0.55))
            shadow = Shadow(color: Palette.black.opacity(resolver.pick(light: 0.2, dark: 0.5)), radius: 14, offsetY: 5)
            text = resolver.primaryText
            disabledText = resolver.disabledText
            shortcutText = resolver.secondaryText
            highlight = resolver.accentFill
            highlightText = resolver.onAccent
            separator = resolver.separator
        }
    }

    /// The desktop's menu bar, along the top of the screen.
    struct MenuBarColors: Hashable, Sendable {

        /// The bar: nearly opaque, so the wallpaper only tints it.
        public var background: ResolvedColor

        /// Menu titles, the clock and status items.
        public var text: ResolvedColor

        /// The title of the menu that is open: a neutral pill behind it,
        /// so the accent stays with the menu's highlighted item.
        public var highlight: ResolvedColor

        public var highlightText: ResolvedColor

        /// The line along the bottom of the bar.
        public var separator: ResolvedColor

        init(_ resolver: Resolver) {
            background = resolver.pick(light: Palette.neutral50.opacity(0.94), dark: Palette.neutral900.opacity(0.94), highLight: Palette.neutral50, highDark: Palette.neutral900)
            text = resolver.primaryText
            highlight = resolver.ink(resolver.isHighContrast ? 0.2 : resolver.pick(light: 0.1, dark: 0.14))
            highlightText = resolver.primaryText
            separator = resolver.separator
        }
    }
}
