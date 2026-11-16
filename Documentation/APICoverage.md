# SwiftUI API coverage

What Cacao implements of Apple's SwiftUI, by area.

| Mark | Meaning |
|---|---|
| ✅ | Implemented, with SwiftUI's behavior |
| ◐ | Implemented, simplified (the note says how) |
| ○ | Compiles, without effect yet |
| ✗ | Missing |

`Tests/LayoutParity` compiles its layout cases and a sample app
(`SampleApp.swift`) against both Apple's SwiftUI and Cacao. The layout cases
must produce the same frames in both, and the sample app runs in Cacao's
tests.

## App and scenes

| API | | Notes |
|---|---|---|
| `App`, `Scene`, `SceneBuilder` | ✅ | |
| `WindowGroup` (title, id) | ✅ | The first scene opens at launch. |
| `WindowGroup(for:)` with a value binding | ✅ | |
| `Window` | ✅ | Unique: opening it again brings it to the front. |
| `openWindow`, `dismissWindow` | ✅ | |
| `defaultSize` | ✅ | |
| `commands`, `CommandMenu`, `CommandGroup` | ◐ | Shortcuts work in every window; macOS shows the menus in the menu bar. Group placements pick the menu, not the position in it. |
| `Settings`, `SettingsLink`, `openSettings` | ✅ | The settings shortcut opens it. |
| `MenuBarExtra` | ◐ | A tray icon with a menu of the content's buttons; the menu style only. |
| `DocumentGroup`, `FileDocument`, `ReferenceFileDocument` | ◐ | New, Open…, Save and Save As… in the File menu, through the system's dialogs; the window's title shows the file and whether it's edited. No autosave, prompt to save on close, recent documents or undo. |

## State and data flow

| API | | Notes |
|---|---|---|
| `@State`, `@Binding` | ✅ | |
| `@Environment` (key paths, `@Observable` objects) | ✅ | |
| `@Observable`, `@Bindable` | ✅ | Reads in `body`, `ForEach` closures and `Canvas` drawing are tracked. |
| `ObservableObject`, `@Published`, `@StateObject`, `@ObservedObject`, `@EnvironmentObject` | ✅ | Combine's on Apple platforms; Cacao's own where there's no Combine. |
| `@AppStorage` | ✅ | `UserDefaults`; every view using a key updates. |
| `@SceneStorage` | ◐ | Kept while the app runs. |
| `@FocusState`, `@GestureState`, `@Namespace` | ✅ | |
| `EnvironmentKey`, `EnvironmentValues` | ✅ | |
| `@Entry` | ✅ | In `EnvironmentValues` extensions. |
| `PreferenceKey`, `preference`, `onPreferenceChange`, `transformPreference` | ✅ | |
| `anchorPreference`, `Anchor`, `overlayPreferenceValue`, `backgroundPreferenceValue` | ✅ | |
| `onAppear`, `onDisappear`, `onChange`, `task`, `task(id:)` | ✅ | |
| `onReceive`, `Publisher.values` | ✅ | Combine's publishers on Apple platforms; elsewhere Cacao's: subjects, `Just`, `Timer.publish`, notifications, `$published`, `objectWillChange`, without demand. |

## Layout

| API | | Notes |
|---|---|---|
| `HStack`, `VStack`, `ZStack`, `Spacer`, `Divider` | ✅ | Frames match Apple's (`LayoutParity`). |
| `Layout`, `AnyLayout`, `LayoutValueKey`, `layoutPriority` | ✅ | |
| `frame`, `padding`, `offset`, `position`, `fixedSize`, `aspectRatio` | ✅ | |
| `alignmentGuide`, custom alignments | ✅ | |
| `overlay`, `background` | ✅ | |
| `GeometryReader`, `GeometryProxy`, `onGeometryChange` | ✅ | Readers update when what they read changes. |
| Coordinate spaces (`.local`, `.global`, `.named`) | ✅ | |
| `ViewThatFits` | ✅ | |
| `zIndex` | ✅ | |
| `safeAreaInset`, `safeAreaPadding`, `ignoresSafeArea` | ◐ | Window safe area from SDL; the keyboard's isn't separate. |
| `Grid`, `GridRow`, `LazyVGrid`, `LazyHGrid` | ✅ | |
| `LazyVStack`, `LazyHStack` | ✅ | Rows are created as they scroll into view. |
| `containerRelativeFrame` | ✅ | Relative to the nearest scroll view, or the window. |

## Views and controls

| API | | Notes |
|---|---|---|
| `Text` (fonts, weight, italic, monospaced digits, `textCase`) | ✅ | |
| `underline`, `strikethrough` (with patterns), `kerning`, `tracking`, `baselineOffset`, `lineSpacing` | ✅ | On `Text` and on views. |
| `lineLimit`, `truncationMode`, `minimumScaleFactor` | ✅ | Truncated lines end in an ellipsis; head and middle truncation for single lines. |
| `allowsTightening` | ○ | |
| `Image` (resources, data, resizing, template rendering) | ✅ | |
| `Image(systemName:)`, `imageScale` | ◐ | Cacao's own drawings of about 60 common symbols, in the foreground style; others are empty. |
| `Shape`s (`UnevenRoundedRectangle` too), `Path`, fills and strokes, `strokeBorder` | ✅ | |
| `Color`, `ShapeStyle`, `foregroundStyle`, `tint`, `.tint` style, `Color.mix` | ✅ | Color spaces (linear is converted to sRGB; Display P3 draws as sRGB); `Color(NSColor)` on macOS follows light and dark. |
| `LinearGradient`, `RadialGradient`, `EllipticalGradient`, `AngularGradient`, `Color.gradient` | ✅ | As views, fills and strokes of shapes, and text styles. |
| `Button` and styles, `Toggle` and styles, `Slider`, `Stepper` | ✅ | |
| `TextField`, `SecureField`, `TextEditor` | ✅ | Moves and deletes by characters and words; undo and redo; the caret blinks. |
| `Picker` (menu, segmented, inline), `Menu` | ✅ | |
| `ProgressView`, `Label`, `Link`, `DisclosureGroup` | ✅ | |
| `LabeledContent`, `ContentUnavailableView` | ✅ | |
| `DatePicker` | ◐ | Compact (popovers) and graphical styles; other styles show as one of these. |
| `ColorPicker` | ◐ | A palette with hue, saturation, brightness and opacity sliders; no `CGColor` binding. |
| `Gauge` | ✅ | Linear and circular styles. |
| `ShareLink`, `SharePreview` | ◐ | AppKit's share picker on macOS; elsewhere a menu that copies and opens URLs. Previews aren't shown. |
| `Canvas`, `GraphicsContext` | ✅ | Paths, text, images and system images, gradients and tiled images, transforms, clips (inverse too), layers, `clipToLayer`, blend modes, filters (shadow, blur, color), resolved text, images and symbols. No `withCGContext`. |
| `TimelineView` | ✅ | |

## Lists and navigation

| API | | Notes |
|---|---|---|
| `List` (selection, sections), `Form`, `Section`, `ForEach` | ✅ | |
| `listStyle`, `listRowBackground`, `listRowInsets`, `listRowSeparator`, `listRowSeparatorTint`, `scrollContentBackground` | ◐ | Plain, inset, grouped, inset grouped and sidebar styles. Row modifiers work inside custom row views. |
| `NavigationStack`, `NavigationPath`, `NavigationLink`, `navigationDestination` | ✅ | Pushes slide in; pops slide out. |
| `NavigationSplitView` | ◐ | Column widths, visibility and dragging dividers; the sidebar toggle is in the detail's bar. |
| `TabView`, `Tab`, `tabItem` | ✅ | Tab items set in custom views' bodies too. |
| `toolbar`, `ToolbarItem`, `ToolbarItemGroup`, `navigationTitle`, `searchable` | ✅ | |
| `toolbar(removing:)` | ◐ | Removes the sidebar toggle; `.title` has no effect. |
| `sheet`, `fullScreenCover`, `alert`, `confirmationDialog`, `popover`, `contextMenu` | ✅ | Presentations animate in and out. |
| `swipeActions` | ◐ | In the row's context menu, as on the Mac; there's no swipe. |
| `onExitCommand` | ✅ | Escape while the view or a descendant has focus. |
| `presentationDetents`, `interactiveDismissDisabled` | ○ | |

## Scrolling

| API | | Notes |
|---|---|---|
| `ScrollView` with physics (rubber band, momentum) | ✅ | |
| `ScrollViewReader`, `scrollTo` (animated) | ✅ | Also for lazy rows not created yet. |
| `scrollTargetBehavior` (`.paging`, `.viewAligned`), `scrollTargetLayout` | ✅ | |
| `scrollIndicators`, `scrollDisabled` | ✅ | |
| `scrollPosition(id:anchor:)`, `defaultScrollAnchor` (and its roles) | ◐ | The position follows a scroll target layout's views; there's no `ScrollPosition` type yet. |
| `refreshable` | ○ | Sets the environment's action. |

## Animation

| API | | Notes |
|---|---|---|
| `withAnimation`, `animation(_:value:)`, `Transaction`, `withTransaction` | ✅ | |
| Curves: linear, ease, timing curve, springs, `delay`, `speed`, `repeat` | ✅ | |
| `Animatable`, `AnimatablePair`, `VectorArithmetic` | ✅ | |
| Transitions: opacity, scale, offset, move, slide, push, asymmetric, combined | ✅ | |
| `matchedGeometryEffect` | ✅ | |
| `scaleEffect`, `rotationEffect` | ✅ | Drawn on the GPU. |
| `PhaseAnimator`, `phaseAnimator`, `KeyframeAnimator`, `keyframeAnimator`, `KeyframeTimeline` | ✅ | Linear, spring, cubic and move keyframes. |
| `contentTransition` | ◐ | Text fades between strings, and numeric text rolls; interpolation fades too. |

## Input

| API | | Notes |
|---|---|---|
| `TapGesture`, `SpatialTapGesture`, `LongPressGesture`, `DragGesture`, `MagnifyGesture` | ✅ | Pinches from trackpads. |
| `RotateGesture` | ◐ | Trackpads on macOS, touchpads under Wayland, and touch screens. Touchpads under X11 report no rotations. |
| `simultaneously`, `sequenced`, `exclusively`, `onChanged`, `onEnded`, `updating`, `map` | ✅ | |
| `gesture`, `highPriorityGesture`, `simultaneousGesture`, `GestureMask` | ✅ | |
| `onTapGesture(count:)`, `onLongPressGesture` | ✅ | |
| `onHover`, `onContinuousHover` | ✅ | |
| `pointerStyle` | ◐ | The system pointer closest to each style; no custom images. |
| `fileImporter`, `fileExporter` | ◐ | The system's open and save dialogs; cancelling calls nothing. |
| `keyboardShortcut`, `onKeyPress`, `focusable`, `focused`, `onSubmit` | ✅ | |
| `draggable`, `dropDestination` | ✅ | Between views, and files and text dropped from the system. `Transferable` is Apple's on macOS and Cacao's own elsewhere. |
| `onDrag`, `onDrop` (item providers), `DropDelegate` | ◐ | On Linux, Cacao's `NSItemProvider` loads data, strings and URLs. Drop proposals don't change the drag's operation. |

## Effects

| API | | Notes |
|---|---|---|
| `opacity`, `clipShape`, `clipped`, `cornerRadius`, `compositingGroup`, `drawingGroup` | ✅ | Shape clips are anti-aliased, and may be concave. |
| `shadow` | ✅ | Blurred on the GPU. |
| `mask` | ✅ | Any view, by its alpha. |
| `border` | ✅ | |
| `blur` | ✅ | On the GPU, by downsampling. |
| `brightness`, `contrast`, `saturation`, `grayscale`, `hueRotation`, `colorInvert`, `colorMultiply`, `luminanceToAlpha` | ✅ | Applied to colors and images as they're drawn. |

## Accessibility

| API | | Notes |
|---|---|---|
| `accessibilityLabel`, `accessibilityValue`, `accessibilityHint` | ✅ | |
| `accessibilityAddTraits`, `accessibilityRemoveTraits`, `accessibilityHidden` | ✅ | |
| `accessibilityElement(children:)`, `accessibilityAction` | ✅ | |
| `accessibilityIdentifier` | ✅ | |
| NSAccessibility bridge (macOS) | ✅ | Windows show their elements to VoiceOver, with press actions. |
| AT-SPI bridge (Linux) | ✗ | |

## Other

| API | | Notes |
|---|---|---|
| `preferredColorScheme`, `colorScheme` | ✅ | |
| `locale`, `calendar`, `timeZone` | ✅ | |
| `help` | ✅ | A tooltip after the pointer rests a second, and the accessibility hint. |
| `badge` | ◐ | On list rows and tabs. |
| `redacted`, `unredacted`, `redactionReasons` | ◐ | Placeholder redaction draws text and images as shapes; `privacy` has no effect. |
| `controlSize` | ◐ | Sizes bordered buttons. |
| `submitLabel`, `autocorrectionDisabled`, `symbolRenderingMode` | ○ | |
| `import SwiftUI`, `import Combine` on Linux | ✅ | The `SwiftUI` and `Combine` modules re-export Cacao and Foundation. |
