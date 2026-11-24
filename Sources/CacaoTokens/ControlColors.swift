//
//  ControlColors.swift
//  CacaoTokens
//
//  Created by Alsey Coleman Miller on 11/23/26.
//

import CacaoRender

public extension StyleTokens {

    /// A push button, in each of its states.
    ///
    /// Buttons are shaded a step darker toward the bottom, with a lighter
    /// line along the top inside edge; pressed buttons are flat and a step
    /// darker. At high contrast every fill is flat.
    struct ButtonColors: Hashable, Sendable {

        public var fill: Gradient

        public var hoverFill: Gradient

        public var pressedFill: Gradient

        public var disabledFill: Gradient

        /// The line around the button.
        public var border: ResolvedColor

        /// The line along the top inside edge, for a slight bevel. Clear at
        /// high contrast.
        public var highlight: ResolvedColor

        /// The label and its icon.
        public var text: ResolvedColor

        public var disabledText: ResolvedColor

        init(push resolver: Resolver) {
            fill = resolver.pick(
                light: resolver.shaded(top: Palette.neutral0, bottom: ResolvedColor(rgb: 0xF1F0EE)),
                dark: resolver.shaded(top: ResolvedColor(rgb: 0x4A4846), bottom: ResolvedColor(rgb: 0x403E3C))
            )
            hoverFill = resolver.pick(
                light: resolver.shaded(top: Palette.neutral0, bottom: ResolvedColor(rgb: 0xF7F6F4)),
                dark: resolver.shaded(top: ResolvedColor(rgb: 0x53514F), bottom: ResolvedColor(rgb: 0x484644))
            )
            pressedFill = Gradient(resolver.pick(light: ResolvedColor(rgb: 0xE2E0DD), dark: ResolvedColor(rgb: 0x33312F)))
            disabledFill = Gradient(resolver.pick(light: Palette.neutral100, dark: Palette.neutral800))
            border = resolver.controlBorder
            highlight = resolver.isHighContrast ? .clear : Palette.white.opacity(resolver.pick(light: 0.8, dark: 0.07))
            text = resolver.primaryText
            disabledText = resolver.disabledText
        }

        init(default resolver: Resolver) {
            let accent = resolver.accentFill
            let white = Palette.white
            let black = Palette.black
            fill = resolver.shaded(top: accent.mixed(with: white, by: 0.12), bottom: accent)
            hoverFill = resolver.shaded(top: accent.mixed(with: white, by: 0.2), bottom: accent.mixed(with: white, by: 0.08))
            pressedFill = Gradient(accent.mixed(with: black, by: 0.15))
            let push = ButtonColors(push: resolver)
            disabledFill = push.disabledFill
            border = resolver.isHighContrast ? resolver.controlBorder : accent.mixed(with: black, by: 0.25)
            highlight = resolver.isHighContrast ? .clear : white.opacity(0.18)
            text = resolver.onAccent
            disabledText = push.disabledText
        }
    }

    /// A segmented control: a row of segments in one track, the selected
    /// one pressed in.
    struct SegmentedControlColors: Hashable, Sendable {

        /// The track, which unselected segments show: a push button's fill.
        public var fill: Gradient

        /// The selected segment: a pressed button's, so it reads as held
        /// down. At high contrast, the accent.
        public var selectedFill: Gradient

        /// The line around the track.
        public var border: ResolvedColor

        /// The lines between segments.
        public var divider: ResolvedColor

        public var text: ResolvedColor

        public var selectedText: ResolvedColor

        public var disabledText: ResolvedColor

        init(_ resolver: Resolver) {
            let push = ButtonColors(push: resolver)
            fill = push.fill
            border = push.border
            divider = resolver.isHighContrast ? push.border : Palette.black.opacity(resolver.pick(light: 0.14, dark: 0.4))
            text = push.text
            disabledText = push.disabledText
            if resolver.isHighContrast {
                selectedFill = Gradient(resolver.accentFill)
                selectedText = resolver.onAccent
            } else {
                selectedFill = push.pressedFill
                selectedText = resolver.primaryText
            }
        }
    }

    /// A search field: a rounded field with a magnifier at its leading
    /// end.
    struct SearchFieldColors: Hashable, Sendable {

        public var background: ResolvedColor

        public var border: ResolvedColor

        /// The border while the field has focus, inside the focus ring.
        public var focusedBorder: ResolvedColor

        public var text: ResolvedColor

        public var placeholder: ResolvedColor

        /// The magnifier and the clear button.
        public var icon: ResolvedColor

        init(_ resolver: Resolver) {
            background = resolver.contentBackground
            border = resolver.controlBorder
            focusedBorder = resolver.isHighContrast ? resolver.accentText : resolver.accent
            text = resolver.primaryText
            placeholder = TextColors(resolver).placeholder
            icon = resolver.secondaryText
        }
    }

    /// A checkbox: a rounded square, filled with the accent while checked.
    struct CheckboxColors: Hashable, Sendable {

        public var fill: ResolvedColor

        public var border: ResolvedColor

        public var checkedFill: ResolvedColor

        public var checkedBorder: ResolvedColor

        /// The check, or the dash of a mixed state.
        public var checkmark: ResolvedColor

        public var disabledFill: ResolvedColor

        public var disabledCheckmark: ResolvedColor

        init(_ resolver: Resolver) {
            fill = resolver.pick(light: Palette.neutral0, dark: ResolvedColor(rgb: 0x403E3C))
            border = resolver.pick(light: Palette.black.opacity(0.28), dark: Palette.black.opacity(0.6), highLight: Palette.black.opacity(0.7), highDark: Palette.white.opacity(0.6))
            checkedFill = resolver.accentFill
            checkedBorder = resolver.isHighContrast ? resolver.controlBorder : resolver.accentFill.mixed(with: Palette.black, by: 0.25)
            checkmark = resolver.onAccent
            disabledFill = resolver.pick(light: Palette.neutral100, dark: Palette.neutral800)
            disabledCheckmark = resolver.disabledText
        }
    }
}

private extension ResolvedColor {

    static let clear = ResolvedColor(red: 0, green: 0, blue: 0, opacity: 0)
}
