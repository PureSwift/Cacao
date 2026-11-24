//
//  WindowColors.swift
//  CacaoTokens
//
//  Created by Alsey Coleman Miller on 11/23/26.
//

import CacaoRender

public extension StyleTokens {

    /// Windows: their background, border and shadow.
    struct WindowColors: Hashable, Sendable {

        /// What the window's content sits on.
        public var background: ResolvedColor

        /// The background of documents, lists, text views and fields.
        public var contentBackground: ResolvedColor

        /// The line around the window, inside its shadow, so windows stay
        /// apart where shadows are off.
        public var border: ResolvedColor

        /// The shadow of the focused window.
        public var shadow: Shadow

        /// The shadow of other windows: closer and lighter, so the focused
        /// window stands above them.
        public var inactiveShadow: Shadow

        init(_ resolver: Resolver) {
            background = resolver.windowBackground
            contentBackground = resolver.contentBackground
            border = resolver.pick(light: Palette.black.opacity(0.2), dark: Palette.black.opacity(0.7), highLight: Palette.black.opacity(0.7), highDark: Palette.white.opacity(0.6))
            shadow = Shadow(color: Palette.black.opacity(resolver.pick(light: 0.22, dark: 0.5)), radius: 20, offsetY: 6)
            inactiveShadow = Shadow(color: Palette.black.opacity(resolver.pick(light: 0.14, dark: 0.36)), radius: 10, offsetY: 3)
        }
    }

    /// The title bar, with the window buttons on its leading side.
    struct TitleBarColors: Hashable, Sendable {

        /// The title bar of the focused window: shaded a step darker toward
        /// the bottom.
        public var background: Gradient

        /// The title bar of other windows: flat, the window's background.
        public var inactiveBackground: Gradient

        /// The title of the focused window.
        public var text: ResolvedColor

        /// The title of other windows.
        public var inactiveText: ResolvedColor

        /// The line along the bottom, between the title bar and content.
        public var separator: ResolvedColor

        /// The close, minimize and zoom buttons.
        public var windowButton: WindowButtonColors

        init(_ resolver: Resolver) {
            background = resolver.pick(
                light: resolver.shaded(top: Palette.neutral100, bottom: Palette.neutral150),
                dark: resolver.shaded(top: Palette.neutral750, bottom: Palette.neutral800)
            )
            inactiveBackground = Gradient(resolver.windowBackground)
            text = resolver.primaryText
            inactiveText = resolver.pick(light: Palette.neutral500, dark: Palette.neutral500, highLight: Palette.neutral600, highDark: Palette.neutral300)
            separator = resolver.separator
            windowButton = WindowButtonColors(resolver)
        }
    }

    /// The close, minimize and zoom buttons: neutral circles with a glyph,
    /// all alike, until the close button is hovered.
    struct WindowButtonColors: Hashable, Sendable {

        /// A button's circle.
        public var fill: ResolvedColor

        /// A hovered button's circle.
        public var hoverFill: ResolvedColor

        /// A pressed button's circle.
        public var pressedFill: ResolvedColor

        /// A button's glyph.
        public var glyph: ResolvedColor

        /// The close button's circle while hovered or pressed: red, the one
        /// warning on the title bar.
        public var closeHoverFill: ResolvedColor

        /// The close button's glyph while hovered or pressed.
        public var closeHoverGlyph: ResolvedColor

        init(_ resolver: Resolver) {
            fill = resolver.ink(resolver.isHighContrast ? 0.16 : resolver.pick(light: 0.07, dark: 0.09))
            hoverFill = resolver.ink(resolver.isHighContrast ? 0.26 : resolver.pick(light: 0.13, dark: 0.16))
            pressedFill = resolver.ink(resolver.isHighContrast ? 0.36 : resolver.pick(light: 0.2, dark: 0.24))
            glyph = resolver.pick(light: Palette.neutral600, dark: Palette.neutral300, highLight: Palette.neutral900, highDark: Palette.light)
            closeHoverFill = Palette.destructive
            closeHoverGlyph = Palette.white
        }
    }

    /// A toolbar, which continues the title bar as one surface.
    struct ToolbarColors: Hashable, Sendable {

        /// The toolbar of the focused window.
        public var background: Gradient

        /// The toolbar of other windows.
        public var inactiveBackground: Gradient

        /// The line along the bottom, between the toolbar and content.
        public var separator: ResolvedColor

        init(_ resolver: Resolver) {
            let titleBar = TitleBarColors(resolver)
            background = titleBar.background
            inactiveBackground = titleBar.inactiveBackground
            separator = titleBar.separator
        }
    }

    /// A window's source list, along its leading edge.
    struct SidebarColors: Hashable, Sendable {

        /// The sidebar: a step off the window's background.
        public var background: ResolvedColor

        /// A row's label.
        public var text: ResolvedColor

        /// Section headers and counts.
        public var secondaryText: ResolvedColor

        /// The selected row in the focused window: the sidebar tinted with
        /// the accent, so it reads as selected without the weight of a
        /// list's selection. At high contrast, the accent.
        public var selection: ResolvedColor

        /// The selected row's label in the focused window.
        public var selectionText: ResolvedColor

        /// The selected row in other windows: neutral.
        public var inactiveSelection: ResolvedColor

        /// The selected row's label in other windows.
        public var inactiveSelectionText: ResolvedColor

        /// The line between the sidebar and the content.
        public var separator: ResolvedColor

        init(_ resolver: Resolver) {
            let background = resolver.pick(light: Palette.neutral100, dark: Palette.neutral800)
            self.background = background
            text = resolver.primaryText
            secondaryText = resolver.secondaryText
            if resolver.isHighContrast {
                selection = resolver.accentFill
                selectionText = resolver.onAccent
            } else {
                selection = background.mixed(with: resolver.accent, by: resolver.pick(light: 0.22, dark: 0.34))
                selectionText = resolver.primaryText
            }
            inactiveSelection = resolver.inactiveSelection
            inactiveSelectionText = resolver.primaryText
            separator = resolver.separator
        }
    }
}
