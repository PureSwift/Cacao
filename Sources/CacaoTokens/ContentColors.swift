//
//  ContentColors.swift
//  CacaoTokens
//
//  Created by Alsey Coleman Miller on 11/23/26.
//

import CacaoRender

public extension StyleTokens {

    /// Text and glyphs.
    ///
    /// On the window background, primary text reads at 7:1 or better and
    /// secondary text at 4.5:1 (7:1 at high contrast), WCAG's AAA and AA
    /// bars. Disabled text is meant to recede, so it has no bar.
    struct TextColors: Hashable, Sendable {

        /// Labels, titles and body text.
        public var primary: ResolvedColor

        /// Subtitles, captions and other supporting text.
        public var secondary: ResolvedColor

        /// The text of disabled controls and items.
        public var disabled: ResolvedColor

        /// A field's placeholder.
        public var placeholder: ResolvedColor

        /// Links and other text in the accent color, made readable on the
        /// window background for any accent.
        public var link: ResolvedColor

        /// Text and glyphs on an accent fill.
        public var onAccent: ResolvedColor

        init(_ resolver: Resolver) {
            primary = resolver.primaryText
            secondary = resolver.secondaryText
            disabled = resolver.disabledText
            placeholder = resolver.pick(light: Palette.neutral500, dark: Palette.neutral500, highLight: Palette.neutral600, highDark: Palette.neutral400)
            link = resolver.accentText
            onAccent = resolver.onAccent
        }
    }

    /// Lines between content.
    struct SeparatorColors: Hashable, Sendable {

        /// A hairline drawn over any surface: translucent, so it darkens
        /// (or in dark, lightens) what it's on by the same amount.
        public var regular: ResolvedColor

        /// The same line, opaque, for where translucent lines would
        /// overlap and double up.
        public var opaque: ResolvedColor

        init(_ resolver: Resolver) {
            regular = resolver.separator
            opaque = resolver.separator.composited(over: resolver.windowBackground)
        }
    }

    /// Selected rows, items and text.
    struct SelectionColors: Hashable, Sendable {

        /// A selected row in a focused list: the accent (at high contrast,
        /// made to read with its text at 4.5:1).
        public var background: ResolvedColor

        /// The text of a selected row in a focused list.
        public var text: ResolvedColor

        /// A selected row in a list that isn't focused, or whose window
        /// isn't: neutral, so only one place shows the accent.
        public var inactiveBackground: ResolvedColor

        /// The text of a selected row in a list that isn't focused.
        public var inactiveText: ResolvedColor

        /// Selected text in a field or text view: the accent, translucent,
        /// so the text keeps its color.
        public var textHighlight: ResolvedColor

        init(_ resolver: Resolver) {
            background = resolver.accentFill
            text = resolver.onAccent
            inactiveBackground = resolver.inactiveSelection
            inactiveText = resolver.primaryText
            textHighlight = resolver.accent.opacity(resolver.pick(light: 0.28, dark: 0.42, highLight: 0.4, highDark: 0.55))
        }
    }

    /// The ring around the focused control, drawn `metrics.focusRingWidth`
    /// wide just outside the control's edge.
    struct FocusRingColors: Hashable, Sendable {

        /// The ring: the accent, translucent so it softens over the
        /// control's edge; at high contrast, the readable accent, opaque.
        public var color: ResolvedColor

        init(_ resolver: Resolver) {
            color = resolver.isHighContrast
                ? resolver.accentText
                : resolver.accent.opacity(resolver.pick(light: 0.55, dark: 0.7))
        }
    }
}
