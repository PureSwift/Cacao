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
| `Settings`, `MenuBarExtra`, `DocumentGroup`, `commands` | ✗ | |

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
| `@Entry` | ✗ | Needs a macro target. |
| `PreferenceKey`, `preference`, `onPreferenceChange`, `transformPreference` | ✅ | |
| `anchorPreference`, `Anchor`, `overlayPreferenceValue`, `backgroundPreferenceValue` | ✅ | |
| `onAppear`, `onDisappear`, `onChange`, `task`, `task(id:)` | ✅ | |
| `onReceive` | ✗ | |

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
| `containerRelativeFrame` | ✗ | |

## Views and controls

| API | | Notes |
|---|---|---|
| `Text` (fonts, weight, italic, monospaced digits, `textCase`) | ✅ | |
| `underline`, `strikethrough`, `kerning`, `tracking`, `baselineOffset`, `truncationMode`, `minimumScaleFactor`, `lineSpacing` | ○ | |
| `Image` (resources, data, resizing, template rendering) | ✅ | |
| `Image(systemName:)` | ○ | Sized like a symbol; draws nothing yet. |
| `Shape`s, `Path`, fills and strokes, `strokeBorder` | ✅ | |
| `Color`, `ShapeStyle`, `foregroundStyle`, `tint` | ✅ | Gradients resolve to a color. |
| `Button` and styles, `Toggle` and styles, `Slider`, `Stepper` | ✅ | |
| `TextField`, `SecureField`, `TextEditor` | ✅ | |
| `Picker` (menu, segmented, inline), `Menu` | ✅ | |
| `ProgressView`, `Label`, `Link`, `DisclosureGroup` | ✅ | |
| `LabeledContent`, `ContentUnavailableView` | ✅ | |
| `DatePicker`, `ColorPicker`, `Gauge`, `ShareLink` | ✗ | |
| `Canvas`, `GraphicsContext` | ◐ | Paths, text, images, transforms, opacity and clips; no symbols, gradients or blend modes. |
| `TimelineView` | ✅ | |

## Lists and navigation

| API | | Notes |
|---|---|---|
| `List` (selection, sections), `Form`, `Section`, `ForEach` | ✅ | |
| `listStyle`, `listRowBackground`, `listRowInsets`, `listRowSeparator` | ○ | One list style. |
| `NavigationStack`, `NavigationPath`, `NavigationLink`, `navigationDestination` | ✅ | Pushes slide in; pops slide out. |
| `NavigationSplitView` | ◐ | Fixed column widths. |
| `TabView`, `Tab`, `tabItem` | ✅ | |
| `toolbar`, `ToolbarItem`, `ToolbarItemGroup`, `navigationTitle`, `searchable` | ✅ | |
| `sheet`, `fullScreenCover`, `alert`, `confirmationDialog`, `popover`, `contextMenu` | ✅ | Presentations animate in and out. |
| `presentationDetents`, `interactiveDismissDisabled` | ○ | |

## Scrolling

| API | | Notes |
|---|---|---|
| `ScrollView` with physics (rubber band, momentum) | ✅ | |
| `ScrollViewReader`, `scrollTo` (animated) | ✅ | Also for lazy rows not created yet. |
| `scrollTargetBehavior` (`.paging`, `.viewAligned`), `scrollTargetLayout` | ✅ | |
| `scrollIndicators`, `scrollDisabled` | ✅ | |
| `scrollPosition`, `defaultScrollAnchor`, `refreshable` | ○ | `refreshable` sets the environment's action. |

## Animation

| API | | Notes |
|---|---|---|
| `withAnimation`, `animation(_:value:)`, `Transaction`, `withTransaction` | ✅ | |
| Curves: linear, ease, timing curve, springs, `delay`, `speed`, `repeat` | ✅ | |
| `Animatable`, `AnimatablePair`, `VectorArithmetic` | ✅ | |
| Transitions: opacity, scale, offset, move, slide, push, asymmetric, combined | ✅ | |
| `matchedGeometryEffect` | ◐ | Frames only. |
| `scaleEffect`, `rotationEffect` | ✅ | Drawn on the GPU. |
| `contentTransition`, `phaseAnimator`, `keyframeAnimator` | ✗ | `contentTransition` compiles. |

## Input

| API | | Notes |
|---|---|---|
| `TapGesture`, `SpatialTapGesture`, `LongPressGesture`, `DragGesture`, `MagnifyGesture` | ✅ | Pinches from trackpads. |
| `RotateGesture` | ◐ | SDL reports no rotations. |
| `simultaneously`, `sequenced`, `exclusively`, `onChanged`, `onEnded`, `updating`, `map` | ✅ | |
| `gesture`, `highPriorityGesture`, `simultaneousGesture`, `GestureMask` | ✅ | |
| `onTapGesture(count:)`, `onLongPressGesture` | ✅ | |
| `onHover`, `onContinuousHover` | ✅ | |
| `keyboardShortcut`, `onKeyPress`, `focusable`, `focused`, `onSubmit` | ✅ | |
| `onDrag`, `onDrop`, `draggable`, `dropDestination` | ✗ | |

## Effects

| API | | Notes |
|---|---|---|
| `opacity`, `clipShape`, `clipped`, `cornerRadius`, `compositingGroup`, `drawingGroup` | ✅ | |
| `shadow` | ◐ | Not blurred. |
| `mask` | ◐ | Shape masks. |
| `border` | ✅ | |
| `blur`, `brightness`, `contrast`, `saturation`, `grayscale`, `hueRotation` | ○ / ✗ | `blur` compiles. |

## Accessibility

| API | | Notes |
|---|---|---|
| `accessibilityLabel`, `accessibilityValue`, `accessibilityHint` | ✅ | |
| `accessibilityAddTraits`, `accessibilityRemoveTraits`, `accessibilityHidden` | ✅ | |
| `accessibilityElement(children:)`, `accessibilityAction` | ✅ | |
| `accessibilityIdentifier` | ✅ | |
| Platform bridge (AT-SPI, NSAccessibility) | ✗ | `ViewGraph.accessibilityTree()` gives a bridge what to expose. |

## Other

| API | | Notes |
|---|---|---|
| `preferredColorScheme`, `colorScheme` | ✅ | |
| `help`, `badge`, `redacted`, `controlSize`, `submitLabel`, `autocorrectionDisabled`, `imageScale`, `symbolRenderingMode` | ○ | |
| `import SwiftUI` on Linux | ✅ | The `SwiftUI` module re-exports Cacao. |
