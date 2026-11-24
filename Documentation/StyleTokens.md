# Style tokens

`CacaoTokens` holds the desktop's look as values: colors, gradients, corner radii, fonts and metrics, resolved for an appearance. Cacao's styles and Perry's AppKit controls read the same values, so native and loaded apps match. The module depends only on `CacaoRender`, for its color, gradient, font and shadow types. It has no SwiftUI, SDL or D-Bus.

```swift
import CacaoTokens

let tokens = StyleTokens(appearance: appearance) // what CacaoDBus read from the portal
tokens.defaultButton.fill.paint(minY: 0, maxY: tokens.metrics.controlHeight)
tokens.menu.highlight
tokens.radii.control
tokens.fonts.windowTitle
```

## Appearance

`Appearance` is the settings portal's `org.freedesktop.appearance` namespace: `color-scheme`, `accent-color` and `contrast`, each `nil` when the portal doesn't serve it. `CacaoDBus`'s `PortalAppearance` is this type, so what the observer reads resolves tokens with no conversion.

| Portal value | Tokens |
| --- | --- |
| `color-scheme` 1 (dark) | Dark |
| `color-scheme` 0 (no preference), 2 (light), or unset | Light, the desktop's default |
| `accent-color` (r, g, b) | Tinted with that color, its opacity ignored |
| `accent-color` unset or out of range | Tinted with Cacao's blue, `#2F74D0` |
| `contrast` 1 (high) | High contrast |
| `contrast` 0 or unset | Normal contrast |

Inside Cacao, `EnvironmentValues.styleTokens` resolves them from the environment's color scheme and contrast, tinted with whatever `Color.accentColor` resolves to, so `.tint(_:)` tints the tokens too.

## The look

The look is Cacao's own, after elementary's Pantheon: neutral surfaces a step apart, subtly shaded controls, the accent saved for what is selected, focused or the default action, a global menu bar, and window buttons on the left. No value is taken from Apple's platforms, and the window buttons deliberately differ from Apple's: they are all the same neutral circle with a glyph, and only the close button turns red, only while hovered.

## Where the numbers come from

### Colors

- **One neutral ramp** (`Palette.swift`), from `#FFFFFF` to `#171615`, made for Cacao. Each step is a little warmer than gray (red one to three levels above blue), so the desktop reads as neutral without a blue cast. Light and dark use the same ramp, ends swapped, the way elementary's palette serves both of its styles.
- **Surfaces a step apart.** Window, sidebar, title bar and content backgrounds are neighboring steps, between 1.02:1 and 1.3:1 apart, enough to see the edge and not enough to look like separate panels.
- **Text by contrast ratio.** WCAG 2.2's relative luminance and contrast ratio (§1.4.3, §1.4.6, §1.4.11) set the text colors: primary text reads at 7:1 or better on every surface (AAA), secondary text at 4.5:1 (AA), or 7:1 at high contrast. Disabled text is meant to recede and has no bar. The tests check every pair against a dozen accents, light and dark, normal and high contrast.
- **The accent stays readable for any color.** Text on an accent fill is white where it reads at 3:1 (the bar for large text and controls), else the dark end of the ramp. Link text is the accent moved toward black (light) or white (dark) in tenths until it reads at 4.5:1 on the window, 7:1 at high contrast. At high contrast, accent fills are also darkened (or, for pale accents, lightened) until their text reads at 4.5:1.
- **Cacao's blue, `#2F74D0`**, is the lightest mid blue that white label text reads on at 4.5:1, so a default button's label passes with no adjustment.
- **The close button's red, `#CC4136`**, is a warm red that a white glyph reads on at 4.5:1.
- **Translucent lines.** Separators and borders are black (light) or white (dark) at an opacity, so they darken or lighten whatever they're on by the same amount: 12% and 10% for separators, 45% at high contrast. `separator.opaque` is the same line composited over the window background.

### Gradients

Shading is subtle and always top to bottom: title bars and push buttons are a step of the ramp darker at the bottom, default buttons run from the accent mixed with 12% white down to the accent. Pressed and inactive surfaces are flat. At high contrast every gradient is flat, as edges and text matter more than depth there.

### Radii

They grow with what they round: 4 points for checkboxes and menu items, 6 for controls and selections, 8 for menus, 10 for windows and popovers. A shape inside a rounded container takes the container's radius less the inset (a menu item 4 points inside an 8-point menu is rounded by 4). The search field is a pill: half the control height.

### Metrics

- **Spacing steps by 4**: 4, 8, 12, 16, 24.
- **Controls are 32 points**: a 14-point label's line, about 18 points, with 7 above and below. Small controls are 24, large 40, for a dialog's main action or a touch screen.
- **Title bar 38 points**: an 18-point window button with 10 above and below. Joined with a toolbar, 52: a 32-point control with the same 10.
- **The menu bar is 28 points**, the exclusive zone the shell's layer-shell bar reserves.
- **Lists**: 30-point sidebar rows, 32-point list rows, 26-point menu items, all a 14-point line with room for a 16-point icon.

### Fonts

The system font (fontconfig's default sans-serif on Linux), at 14 points for body text. The 10.5 to 11-point desktop fonts common on Linux are 14 to 14.7 pixels at 96 dots per inch, and a whole number keeps glyphs on the pixel grid at 1× and 2×. Smaller and larger sizes step by about a fifth: 11, 12, 14, 20, 28. Monospaced text is 13 points, a point smaller so it sets to the same visual size as the proportional font.

## The desktop's look

Cacao's built-in styles draw from these tokens under the desktop's look, `InterfaceLook.desktop`, which every app's windows get by default:

- **Buttons**: `.automatic` and `.bordered` are push buttons, `.borderedProminent` the default button in the accent. In a toolbar, automatic buttons are flat until hovered.
- **Segmented pickers**: one shaded track, the selected segment pressed in.
- **Text and search fields**: the content background in a rounded border, ringed with the accent while focused. A search field is a pill with a magnifier.
- **Sidebars**: `.sidebar` lists, and lists in a split view's sidebar column, on the sidebar background with the selection tinted by the accent.
- **Toolbars**: shaded like the title bar they continue, the title between the items, search at the trailing end.
- **Menus, checkboxes, forms and switches**: opaque rounded menus, accent-filled checkboxes and switches, and forms on the window's background.

Styles an app writes itself draw the same under either look, and any view can ask for Cacao's stock styles with `.interfaceLook(.stock)`. Views drawn outside an app's windows, as in tests, have the stock look.

Whether third-party apps get the desktop's look by default is one line: `InterfaceLook.appDefault`. It is `.desktop`, so every Cacao app matches the desktop with the stock styles still selectable, as the desktop plan recommends. Set to `.stock`, only apps that set it back to `.desktop` in their `init()`, such as the desktop's own, get the look.

## What's next

The window chrome draws the title bar and window buttons from the `titleBar` tokens. Perry's `Cells.swift` and `Controls.swift` read the same tokens for AppKit's controls.
