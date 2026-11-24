//
//  StyleTokens.swift
//  CacaoTokens
//
//  Created by Alsey Coleman Miller on 11/23/26.
//

import CacaoRender

/// The colors, gradients, corner radii, fonts and metrics of the desktop's
/// look, resolved for one appearance: light or dark, tinted by an accent
/// color, at normal or high contrast.
///
/// Cacao's styles and Perry's AppKit controls read the same values from
/// here, so native and loaded apps match. Nothing here depends on SwiftUI.
///
/// ```swift
/// let tokens = StyleTokens(appearance: appearance) // from the settings portal
/// let fill = tokens.defaultButton.fill.paint(minY: 0, maxY: tokens.metrics.controlHeight)
/// ```
///
/// The look is Cacao's own, after elementary's Pantheon: neutral surfaces
/// a step apart, subtly shaded controls, the accent saved for what is
/// selected, focused or the default action, and window buttons on the
/// left. `Documentation/StyleTokens.md` says where each number comes from.
public struct StyleTokens: Hashable, Sendable {

    // MARK: Appearance

    /// Whether these are the dark tokens.
    public let isDark: Bool

    /// The accent the tokens are tinted with, opaque.
    public let accentColor: ResolvedColor

    /// Whether these are the high-contrast tokens.
    public let isHighContrast: Bool

    // MARK: Colors

    /// Text and glyphs.
    public var text: TextColors

    /// Lines between content.
    public var separator: SeparatorColors

    /// Selected rows, items and text.
    public var selection: SelectionColors

    /// The ring around the focused control.
    public var focusRing: FocusRingColors

    /// Windows: their background, border and shadow.
    public var window: WindowColors

    /// The title bar, with the window buttons on its leading side.
    public var titleBar: TitleBarColors

    /// A toolbar, which continues the title bar.
    public var toolbar: ToolbarColors

    /// A window's source list.
    public var sidebar: SidebarColors

    /// A push button.
    public var pushButton: ButtonColors

    /// The default push button, the one Return presses: tinted with the
    /// accent.
    public var defaultButton: ButtonColors

    /// A segmented control.
    public var segmentedControl: SegmentedControlColors

    /// A search field.
    public var searchField: SearchFieldColors

    /// A checkbox.
    public var checkbox: CheckboxColors

    /// Menus: pop-up, context and the menu bar's.
    public var menu: MenuColors

    /// The desktop's menu bar.
    public var menuBar: MenuBarColors

    // MARK: Shape and type

    /// Corner radii.
    public var radii: Radii

    /// Sizes, paddings and spacing.
    public var metrics: Metrics

    /// Fonts.
    public var fonts: Fonts

    // MARK: Resolving

    /// The accent when the desktop names none: Cacao's blue, `#2F74D0`.
    public static let defaultAccentColor = Palette.accent

    /// The tokens for the appearance the settings portal serves. What it
    /// doesn't serve is the desktop's default: light, Cacao's blue accent
    /// and normal contrast.
    public init(appearance: Appearance = Appearance()) {
        self.init(
            isDark: appearance.isDark,
            accentColor: appearance.accentColor.map(ResolvedColor.init),
            isHighContrast: appearance.isHighContrast
        )
    }

    /// The tokens for a color scheme, accent and contrast. With no accent,
    /// Cacao's blue. The accent's opacity is ignored.
    public init(isDark: Bool = false, accentColor: ResolvedColor? = nil, isHighContrast: Bool = false) {
        let resolver = Resolver(
            isDark: isDark,
            accent: (accentColor ?? Self.defaultAccentColor).opacity(1),
            isHighContrast: isHighContrast
        )
        self.isDark = isDark
        self.accentColor = resolver.accent
        self.isHighContrast = isHighContrast
        self.text = TextColors(resolver)
        self.separator = SeparatorColors(resolver)
        self.selection = SelectionColors(resolver)
        self.focusRing = FocusRingColors(resolver)
        self.window = WindowColors(resolver)
        self.titleBar = TitleBarColors(resolver)
        self.toolbar = ToolbarColors(resolver)
        self.sidebar = SidebarColors(resolver)
        self.pushButton = ButtonColors(push: resolver)
        self.defaultButton = ButtonColors(default: resolver)
        self.segmentedControl = SegmentedControlColors(resolver)
        self.searchField = SearchFieldColors(resolver)
        self.checkbox = CheckboxColors(resolver)
        self.menu = MenuColors(resolver)
        self.menuBar = MenuBarColors(resolver)
        self.radii = Radii()
        self.metrics = Metrics()
        self.fonts = Fonts()
    }
}

// MARK: - Resolver

/// What every token is derived from, and the colors several share.
struct Resolver {

    let isDark: Bool

    let accent: ResolvedColor

    let isHighContrast: Bool

    /// One value for light, another for dark.
    func pick<T>(light: T, dark: T) -> T {
        isDark ? dark : light
    }

    /// One value for each scheme at normal contrast, and others at high.
    func pick<T>(light: T, dark: T, highLight: T, highDark: T) -> T {
        isHighContrast ? pick(light: highLight, dark: highDark) : pick(light: light, dark: dark)
    }

    /// A shading: black over light surfaces, white over dark ones, at an
    /// opacity.
    func ink(_ opacity: Float) -> ResolvedColor {
        pick(light: Palette.black, dark: Palette.white).opacity(opacity)
    }

    /// A gradient, flattened to its bottom color at high contrast, where
    /// surfaces are flat so edges and text stand out.
    func shaded(top: ResolvedColor, bottom: ResolvedColor) -> StyleTokens.Gradient {
        isHighContrast ? .init(bottom) : .init(top: top, bottom: bottom)
    }

    // MARK: Shared colors

    /// The window's background, which most text sits on.
    var windowBackground: ResolvedColor {
        pick(light: Palette.neutral50, dark: Palette.neutral850)
    }

    /// The background of documents, lists and fields: brighter than the
    /// window in light, darker in dark.
    var contentBackground: ResolvedColor {
        pick(light: Palette.neutral0, dark: Palette.neutral900)
    }

    var primaryText: ResolvedColor {
        pick(light: Palette.neutral900, dark: Palette.light)
    }

    var secondaryText: ResolvedColor {
        pick(light: Palette.neutral600, dark: Palette.neutral400, highLight: Palette.neutral750, highDark: Palette.neutral200)
    }

    var disabledText: ResolvedColor {
        pick(light: Palette.neutral400, dark: Palette.neutral600, highLight: Palette.neutral500, highDark: Palette.neutral500)
    }

    /// The accent as a fill behind text: selections, highlighted menu
    /// items, default buttons and checked checkboxes. At high contrast,
    /// darkened until white text reads on it at 4.5:1, or for accents that
    /// dark text reads on better, lightened until dark text does.
    var accentFill: ResolvedColor {
        guard isHighContrast else {
            return accent
        }
        if Palette.white.contrastRatio(on: accent) >= Palette.neutral900.contrastRatio(on: accent) {
            return accent.readable(on: Palette.white, minimum: 4.5, toward: Palette.black)
        } else {
            return accent.readable(on: Palette.neutral900, minimum: 4.5, toward: Palette.white)
        }
    }

    /// Text and glyphs on the accent fill: white where it reads at 3:1, the
    /// bar for large text and controls, else the dark end of the ramp. At
    /// high contrast, whichever reads better, at 4.5:1 or more.
    var onAccent: ResolvedColor {
        let white = Palette.white
        let dark = Palette.neutral900
        let fill = accentFill
        if isHighContrast {
            return white.contrastRatio(on: fill) >= dark.contrastRatio(on: fill) ? white : dark
        }
        return white.contrastRatio(on: fill) >= 3 ? white : dark
    }

    /// The accent as text on the window background: moved toward black in
    /// light or white in dark until it reads at 4.5:1, or 7:1 at high
    /// contrast.
    var accentText: ResolvedColor {
        accent.readable(
            on: windowBackground,
            minimum: isHighContrast ? 7 : 4.5,
            toward: pick(light: Palette.black, dark: Palette.white)
        )
    }

    /// Hairlines between content.
    var separator: ResolvedColor {
        ink(isHighContrast ? 0.45 : pick(light: 0.12, dark: 0.10))
    }

    /// The edge of a control.
    var controlBorder: ResolvedColor {
        pick(light: Palette.black.opacity(0.18), dark: Palette.black.opacity(0.55), highLight: Palette.black.opacity(0.6), highDark: Palette.white.opacity(0.55))
    }

    /// A selection while its window or list isn't focused.
    var inactiveSelection: ResolvedColor {
        pick(light: Palette.neutral200, dark: Palette.neutral700, highLight: Palette.neutral300, highDark: Palette.neutral600)
    }
}
