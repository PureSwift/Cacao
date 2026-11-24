//
//  Palette.swift
//  CacaoTokens
//
//  Created by Alsey Coleman Miller on 11/23/26.
//

import CacaoRender

/// The handful of colors every token is made from: one neutral ramp, the
/// default accent, and the red of a hovered close button. Everything else
/// is one of these, a mix of them with the accent, or black or white at an
/// opacity.
///
/// The ramp is Cacao's own. Its steps are spaced so that neighbors read as
/// surfaces a step apart (window, sidebar, title bar) and the far ends meet
/// the contrast targets in `StyleTokens` (primary text at least 7:1 and
/// secondary text at least 4.5:1 on any surface). Each step is a little
/// warmer than gray, red highest and blue lowest by one to three levels,
/// so the desktop reads as neutral without the blue cast of cooler grays.
/// The same ramp serves light and dark, its ends swapping roles, the way
/// elementary's palette serves both of its styles.
enum Palette {

    static let neutral0 = ResolvedColor(rgb: 0xFFFFFF)
    static let neutral50 = ResolvedColor(rgb: 0xF8F7F6)
    static let neutral100 = ResolvedColor(rgb: 0xF0EFED)
    static let neutral150 = ResolvedColor(rgb: 0xE7E5E2)
    static let neutral200 = ResolvedColor(rgb: 0xDCDAD6)
    static let neutral300 = ResolvedColor(rgb: 0xC5C2BD)
    static let neutral400 = ResolvedColor(rgb: 0xA6A39E)
    static let neutral500 = ResolvedColor(rgb: 0x817E79)
    static let neutral600 = ResolvedColor(rgb: 0x625F5B)
    static let neutral700 = ResolvedColor(rgb: 0x474542)
    static let neutral750 = ResolvedColor(rgb: 0x3B3937)
    static let neutral800 = ResolvedColor(rgb: 0x312F2D)
    static let neutral850 = ResolvedColor(rgb: 0x282725)
    static let neutral900 = ResolvedColor(rgb: 0x1F1E1D)
    static let neutral950 = ResolvedColor(rgb: 0x171615)

    /// The light end, for text on dark surfaces: a step below white, so
    /// large areas of it don't glare.
    static let light = ResolvedColor(rgb: 0xEFEEEC)

    static let white = ResolvedColor(red: 1, green: 1, blue: 1)

    static let black = ResolvedColor(red: 0, green: 0, blue: 0)

    /// Cacao's blue, `#2F74D0`: the accent when the desktop names none.
    /// Picked as the lightest mid blue that white label text still reads on
    /// at 4.5:1, WCAG's bar for body text, so a default button's label
    /// passes without any adjustment.
    static let accent = ResolvedColor(rgb: 0x2F74D0)

    /// The fill of a hovered close button, `#CC4136`: a warm red that
    /// white glyphs read on at 4.5:1. Only the close button is colored,
    /// and only while hovered; the window buttons are otherwise neutral.
    static let destructive = ResolvedColor(rgb: 0xCC4136)
}
