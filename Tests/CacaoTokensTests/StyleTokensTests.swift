import CacaoRender
import Foundation
#if canImport(CoreGraphics)
import CoreGraphics
#endif
import Testing
@testable import CacaoTokens

@Suite struct StyleTokensTests {

    /// Accents a desktop might serve, from dark to light, including ones
    /// that white text doesn't read on.
    static let accents: [ResolvedColor] = [
        StyleTokens.defaultAccentColor,
        ResolvedColor(rgb: 0x3584E4), // a lighter blue
        ResolvedColor(rgb: 0x2190A4), // teal
        ResolvedColor(rgb: 0x3A944A), // green
        ResolvedColor(rgb: 0xC88800), // amber
        ResolvedColor(rgb: 0xF5C211), // yellow
        ResolvedColor(rgb: 0xED5B00), // orange
        ResolvedColor(rgb: 0xE62D42), // red
        ResolvedColor(rgb: 0xD56199), // pink
        ResolvedColor(rgb: 0x9141AC), // purple
        ResolvedColor(rgb: 0x6F8396), // slate
        ResolvedColor(rgb: 0x9ACCFF), // pale blue
    ]

    /// Every combination of scheme, contrast and accent.
    static var everyAppearance: [StyleTokens] {
        accents.flatMap { accent in
            [false, true].flatMap { isDark in
                [false, true].map { isHighContrast in
                    StyleTokens(isDark: isDark, accentColor: accent, isHighContrast: isHighContrast)
                }
            }
        }
    }

    // MARK: Appearance

    @Test func whatThePortalDoesntServeIsTheDefault() {
        let tokens = StyleTokens(appearance: Appearance())
        #expect(tokens == StyleTokens())
        #expect(tokens.isDark == false)
        #expect(tokens.isHighContrast == false)
        #expect(tokens.accentColor == StyleTokens.defaultAccentColor)
        #expect(tokens.accentColor == ResolvedColor(rgb: 0x2F74D0))
    }

    @Test func noPreferenceIsLight() {
        #expect(StyleTokens(appearance: Appearance(colorScheme: .noPreference)).isDark == false)
        #expect(StyleTokens(appearance: Appearance(colorScheme: .light)).isDark == false)
        #expect(StyleTokens(appearance: Appearance(colorScheme: .dark)).isDark == true)
    }

    @Test func thePortalsValuesResolveTheTokens() {
        let appearance = Appearance(
            colorScheme: .dark,
            accentColor: Appearance.AccentColor(red: 0.8, green: 0.2, blue: 0.4),
            contrast: .high
        )
        let tokens = StyleTokens(appearance: appearance)
        #expect(tokens == StyleTokens(isDark: true, accentColor: ResolvedColor(red: 0.8, green: 0.2, blue: 0.4), isHighContrast: true))
        #expect(StyleTokens(appearance: Appearance(contrast: .normal)).isHighContrast == false)
    }

    @Test func theAccentConvertsBothWays() {
        let accent = Appearance.AccentColor(red: 0.25, green: 0.5, blue: 0.75)
        let color = ResolvedColor(accent)
        #expect(color == ResolvedColor(red: 0.25, green: 0.5, blue: 0.75, opacity: 1))
        #expect(Appearance.AccentColor(color) == accent)
    }

    @Test func theAccentIsOpaque() {
        let tokens = StyleTokens(accentColor: ResolvedColor(red: 1, green: 0, blue: 0, opacity: 0.3))
        #expect(tokens.accentColor.opacity == 1)
        #expect(tokens.selection.background.opacity == 1)
    }

    // MARK: Accent

    @Test func theAccentTintsWhatIsSelectedFocusedOrDefault() {
        let accent = ResolvedColor(rgb: 0x3A944A)
        let tokens = StyleTokens(accentColor: accent)
        #expect(tokens.selection.background == accent)
        #expect(tokens.menu.highlight == accent)
        #expect(tokens.checkbox.checkedFill == accent)
        #expect(tokens.defaultButton.fill.bottom == accent)
        #expect(tokens.searchField.focusedBorder == accent)
        #expect(tokens.focusRing.color == accent.opacity(0.55))
        #expect(tokens.sidebar.selection != StyleTokens().sidebar.selection)
    }

    @Test func neutralSurfacesDontFollowTheAccent() {
        let blue = StyleTokens()
        let green = StyleTokens(accentColor: ResolvedColor(rgb: 0x3A944A))
        #expect(blue.window == green.window)
        #expect(blue.titleBar == green.titleBar)
        #expect(blue.pushButton == green.pushButton)
        #expect(blue.menu.background == green.menu.background)
        #expect(blue.text.primary == green.text.primary)
    }

    @Test func textOnTheAccentIsWhiteUnlessItWouldntRead() {
        #expect(StyleTokens().text.onAccent == ResolvedColor(rgb: 0xFFFFFF))
        #expect(StyleTokens(accentColor: ResolvedColor(rgb: 0x3584E4)).text.onAccent == ResolvedColor(rgb: 0xFFFFFF))
        #expect(StyleTokens(accentColor: ResolvedColor(rgb: 0xF5C211)).text.onAccent == Palette.neutral900)
        #expect(StyleTokens(accentColor: ResolvedColor(rgb: 0x9ACCFF)).text.onAccent == Palette.neutral900)
    }

    @Test func whiteTextReadsOnTheDefaultAccentAndCloseButton() {
        let white = ResolvedColor(rgb: 0xFFFFFF)
        #expect(white.contrastRatio(on: StyleTokens.defaultAccentColor) >= 4.5)
        let button = StyleTokens().titleBar.windowButton
        #expect(button.closeHoverGlyph.contrastRatio(on: button.closeHoverFill) >= 4.5)
    }

    // MARK: Contrast

    @Test(arguments: everyAppearance)
    func textReads(_ tokens: StyleTokens) {
        let background = tokens.window.background
        let minimum: Double = tokens.isHighContrast ? 7 : 4.5
        #expect(tokens.text.primary.contrastRatio(on: background) >= 7)
        #expect(tokens.text.primary.contrastRatio(on: tokens.window.contentBackground) >= 7)
        #expect(tokens.text.secondary.contrastRatio(on: background) >= minimum)
        #expect(tokens.text.link.contrastRatio(on: background) >= minimum)
        #expect(tokens.sidebar.text.contrastRatio(on: tokens.sidebar.background) >= 7)
        #expect(tokens.titleBar.text.contrastRatio(on: tokens.titleBar.background.bottom) >= 7)
        #expect(tokens.pushButton.text.contrastRatio(on: tokens.pushButton.fill.bottom) >= 7)
        #expect(tokens.menu.text.contrastRatio(on: tokens.menu.background) >= 7)
        #expect(tokens.menu.shortcutText.contrastRatio(on: tokens.menu.background) >= minimum)
        #expect(tokens.searchField.text.contrastRatio(on: tokens.searchField.background) >= 7)
    }

    @Test(arguments: everyAppearance)
    func textOnTheAccentReads(_ tokens: StyleTokens) {
        let minimum: Double = tokens.isHighContrast ? 4.5 : 3
        #expect(tokens.selection.text.contrastRatio(on: tokens.selection.background) >= minimum)
        #expect(tokens.menu.highlightText.contrastRatio(on: tokens.menu.highlight) >= minimum)
        #expect(tokens.checkbox.checkmark.contrastRatio(on: tokens.checkbox.checkedFill) >= minimum)
        #expect(tokens.defaultButton.text.contrastRatio(on: tokens.defaultButton.fill.bottom) >= minimum)
    }

    @Test(arguments: everyAppearance)
    func selectedRowsRead(_ tokens: StyleTokens) {
        #expect(tokens.sidebar.selectionText.contrastRatio(on: tokens.sidebar.selection) >= 4.5)
        #expect(tokens.sidebar.inactiveSelectionText.contrastRatio(on: tokens.sidebar.inactiveSelection) >= 4.5)
        #expect(tokens.selection.inactiveText.contrastRatio(on: tokens.selection.inactiveBackground) >= 4.5)
        #expect(tokens.segmentedControl.selectedText.contrastRatio(on: tokens.segmentedControl.selectedFill.bottom) >= 4.5)
    }

    @Test(arguments: everyAppearance)
    func highContrastIsFlatWithStrongerEdges(_ tokens: StyleTokens) {
        guard tokens.isHighContrast else {
            return
        }
        let normal = StyleTokens(isDark: tokens.isDark, accentColor: tokens.accentColor)
        #expect(tokens.titleBar.background.isFlat)
        #expect(tokens.pushButton.fill.isFlat)
        #expect(tokens.pushButton.hoverFill.isFlat)
        #expect(tokens.defaultButton.fill.isFlat)
        #expect(tokens.pushButton.highlight.opacity == 0)
        #expect(tokens.focusRing.color.opacity == 1)
        let background = tokens.window.background
        #expect(tokens.separator.regular.contrastRatio(on: background) > normal.separator.regular.contrastRatio(on: background))
        #expect(tokens.pushButton.border.contrastRatio(on: background) > normal.pushButton.border.contrastRatio(on: background))
    }

    @Test func normalContrastIsShaded() {
        for isDark in [false, true] {
            let tokens = StyleTokens(isDark: isDark)
            #expect(!tokens.titleBar.background.isFlat)
            #expect(!tokens.pushButton.fill.isFlat)
            #expect(!tokens.defaultButton.fill.isFlat)
            #expect(tokens.titleBar.inactiveBackground.isFlat)
            #expect(tokens.pushButton.pressedFill.isFlat)
            // Shaded darker toward the bottom.
            #expect(tokens.pushButton.fill.top.relativeLuminance > tokens.pushButton.fill.bottom.relativeLuminance)
            #expect(tokens.titleBar.background.top.relativeLuminance > tokens.titleBar.background.bottom.relativeLuminance)
        }
    }

    // MARK: Light and dark

    @Test func darkSurfacesAreDark() {
        let light = StyleTokens()
        let dark = StyleTokens(isDark: true)
        #expect(light.window.background.relativeLuminance > 0.8)
        #expect(dark.window.background.relativeLuminance < 0.05)
        #expect(dark.text.primary.relativeLuminance > 0.8)
        #expect(light.window.contentBackground.relativeLuminance > light.window.background.relativeLuminance)
        #expect(dark.window.contentBackground.relativeLuminance < dark.window.background.relativeLuminance)
        // Pressed buttons are a step darker in either scheme.
        #expect(light.pushButton.pressedFill.top.relativeLuminance < light.pushButton.fill.bottom.relativeLuminance)
        #expect(dark.pushButton.pressedFill.top.relativeLuminance < dark.pushButton.fill.bottom.relativeLuminance)
    }

    @Test func theSidebarIsAStepOffTheWindow() {
        for isDark in [false, true] {
            let tokens = StyleTokens(isDark: isDark)
            #expect(tokens.sidebar.background != tokens.window.background)
            let ratio = tokens.sidebar.background.contrastRatio(on: tokens.window.background)
            #expect(ratio > 1.02 && ratio < 1.3)
        }
    }

    @Test func theToolbarContinuesTheTitleBar() {
        for isDark in [false, true] {
            let tokens = StyleTokens(isDark: isDark)
            #expect(tokens.toolbar.background == tokens.titleBar.background)
            #expect(tokens.toolbar.inactiveBackground == tokens.titleBar.inactiveBackground)
        }
    }

    @Test func theOpaqueSeparatorMatchesTheTranslucentOne() {
        for isDark in [false, true] {
            let tokens = StyleTokens(isDark: isDark)
            #expect(tokens.separator.opaque.opacity == 1)
            let composited = tokens.separator.regular.composited(over: tokens.window.background)
            #expect(composited == tokens.separator.opaque)
        }
    }

    // MARK: Shape and type

    @Test func metricsFitTogether() {
        let tokens = StyleTokens()
        let metrics = tokens.metrics
        #expect(tokens.radii.searchField == metrics.controlHeight / 2)
        #expect(tokens.radii.menuItem == tokens.radii.menu - metrics.menuInset)
        #expect(metrics.titleBarHeight - metrics.windowButtonSize == 20)
        #expect(metrics.unifiedToolbarHeight - metrics.controlHeight == 20)
        #expect(metrics.smallControlHeight < metrics.controlHeight)
        #expect(metrics.controlHeight < metrics.largeControlHeight)
        #expect(metrics.checkboxSize > tokens.radii.checkbox * 2)
        for value in [metrics.spacingTight, metrics.spacing, metrics.spacingLoose, metrics.contentPadding, metrics.groupSpacing] {
            #expect(value.truncatingRemainder(dividingBy: 4) == 0)
        }
    }

    @Test func fontsAreTheSystemFont() {
        let fonts = StyleTokens().fonts
        #expect(fonts.body == ResolvedFont(size: 14))
        #expect(fonts.body.name == nil)
        #expect(fonts.windowTitle.weight == 600)
        #expect(fonts.monospace.design == .monospaced)
        #expect(fonts.caption.size < fonts.callout.size)
        #expect(fonts.callout.size < fonts.body.size)
        #expect(fonts.body.size < fonts.title.size)
        #expect(fonts.title.size < fonts.largeTitle.size)
    }

    // MARK: Values

    @Test func gradientsPaintTopToBottom() {
        let gradient = StyleTokens.Gradient(top: ResolvedColor(rgb: 0xFFFFFF), bottom: ResolvedColor(rgb: 0x000000))
        #expect(!gradient.isFlat)
        let paint = gradient.paint(minY: 4, maxY: 36)
        #expect(paint.stops == gradient.stops)
        #expect(paint.geometry == .axial(start: CGPoint(x: 0, y: 4), end: CGPoint(x: 0, y: 36)))
        let flat = StyleTokens.Gradient(ResolvedColor(rgb: 0x808080))
        #expect(flat.isFlat)
        #expect(flat.top == flat.bottom)
    }

    @Test func shadowsFallStraightDown() {
        let shadow = StyleTokens().window.shadow
        #expect(shadow.effect == ShadowEffect(color: shadow.color, radius: shadow.radius, offset: CGSize(width: 0, height: shadow.offsetY)))
        #expect(StyleTokens(isDark: true).window.shadow.color.opacity > shadow.color.opacity)
    }
}
