# Cacao: SwiftUI for Linux and macOS — Plan

Status: **Phase 13 done** (list styles and row modifiers, scroll
positions and anchors, tooltips, redaction, control sizes, content
transitions, badges). What's implemented is in [API coverage](APICoverage.md).

Notes:
- Phase 1: 26 layout cases match Apple's SwiftUI frame for frame on macOS
  (`Tests/LayoutParity`), including the finding that stacks size spacers
  after every other child.
- Phase 2: the compositor keeps rasterized text and shapes in textures;
  scrolling over content already drawn does no evaluation, layout,
  rasterization or upload (`CompositorTests`).
- Phase 3: a 10,000-row `List` keeps under 900 nodes. In a debug build,
  scrolling takes 1.6 ms a frame at the median; frames that create rows
  peak at 10 ms (`ListScrollBenchmark`). Measurements and explicit
  alignments are cached across layout passes, and unchanged subtrees
  keep their placement.
- Phase 4: lists and forms flatten their content's structure (tuples,
  groups, conditionals, `ForEach`, sections) into rows, lazily for lists.
  Navigation stacks keep every screen alive and draw the top one; bars show
  what screens set through `navigationTitle`, `toolbar` and `searchable`.
  Presentations are keyed to the view that presents them and update without
  re-evaluating the window's content.
- Phase 5: after each layout, the graph animates what an update changed:
  frames, and the values of animatable behaviors (colors, opacity, shapes,
  scale and rotation), from where they show to where they go, in the
  update's transaction. Inserted views transition in, removed views keep
  drawing as they transition out, and matched geometry moves between views.
  `Animatable` views and modifiers re-evaluate each frame. Scale and
  rotation draw through offscreen layers as transformed quads; moves only
  shift drawing. Gestures run per interaction, by precedence: high priority
  gestures outermost first, then the others innermost first; the first that
  hasn't failed reports, and recognizing cancels the rest. Controls' taps and
  drags take part as gestures. In a release build, 40 rows animating
  frames, shapes, opacity and scale at once take 2.9 ms a frame.
- Phase 6: layout settles in one pass when it changes views, like geometry
  readers given a new size or reading geometry that moved. A sample app
  written for SwiftUI (`Tests/LayoutParity/SampleApp.swift`) compiles
  against Apple's SwiftUI and against Cacao, and runs in Cacao's tests; it
  found `onSubmit`'s label differing from SwiftUI's. Four more layout cases
  (`GeometryReader`, `ViewThatFits`, `position`, `safeAreaInset`) match
  Apple's frames, 30 in all. `ObservableObject` and `@Published` are
  Combine's on Apple platforms and Cacao's own on Linux. Navigation pushes,
  sheets, dialogs and popups animate by default, unless a transaction
  disables animations.
- Phase 7: gradients are drawn by Silica as pixels masked by the shape, so
  strokes and fills get them alike. Blur runs on the GPU: the layer is
  halved again and again with linear filtering, then drawn back up, about
  one halving per doubling of the radius. Shadows blur the view's
  silhouette, which is now the shadow's color exactly (it was the view's
  colors tinted). Color effects (saturation, hue rotation and the like) are
  matrices applied to the colors of what's drawn and to images as they're
  decoded, so they cost nothing per frame. Phase and keyframe animators run
  on the graph's clock through wakeups, like `TimelineView`, so tests drive
  them with simulated time. Without Combine, Cacao provides the publishers
  `onReceive` takes. `@Entry` is a macro target on swift-syntax.
- Phase 8: masks draw the mask into one offscreen layer and the content
  into another, and keep the content only where the mask is opaque
  (destination-in blending), so a view's alpha masks any content. Shape
  clips draw their shape as such a mask, anti-aliased and right for
  concave shapes, instead of a triangle fan. Text in a gradient style is
  the gradient masked by the text. Silica draws images y-up, so `Canvas`
  images had been upside down; they're drawn upright now. Text editing
  moves by grapheme clusters (an emoji flag or an accented letter is one
  step), by words with option (control on Linux), and joins typing in one
  undo step.
- Phase 9: `Image(systemName:)` draws Cacao's own vector versions of
  common symbols (SF Symbols aren't available on Linux, nor licensed for
  redistribution). Command menus live in each window's graph as an unseen
  layer, so their shortcuts work everywhere, and the host reads their items
  from there; on macOS they fill the menu bar when opened. Menu bar extras
  are SDL tray icons whose menus come from a graph of their content. Drags
  within a window move values; drops from the system arrive as file URLs
  and text, converted to what the destination takes. On macOS, each window
  shows its accessibility tree to VoiceOver as NSAccessibility elements.
- Canvas: drawing commands with blend modes, filters or masks, and
  layers, composite on their own: each draws into its own bitmap, which is
  masked, filtered (shadows and blurs as three box blurs) and blended into
  the result in software, by the W3C compositing formulas. Runs of plain
  commands still draw together with Silica in one pass, so canvases without
  these features cost what they did. Symbols are the canvas's tagged
  children, laid out but not shown, whose drawings become commands.
  Rotating a canvas found that Silica's Cairo backend transposed affine
  matrices (`b` and `c` swapped), so rotations turned the wrong way on
  Linux; that is fixed in Silica (PureSwift/Silica#22).
- Phase 10: a built-in modifier that lays out or draws applies to each of
  several views, as in SwiftUI, when its content's structure (tuples,
  groups, conditionals, `ForEach`, a custom modifier's content, other
  built-in modifiers) holds them. Views that aren't the source of a matched
  geometry group are placed in the source's frame after each layout: each
  lines up its own anchor with the source's, and without `.position` keeps
  its origin, as Apple's SwiftUI does (33 layout cases now match). Column
  widths reach the split view through a preference, and hidden columns keep
  their state without being drawn. `onDrag` and `onDrop` carry item
  providers; on Linux, Cacao provides the part of `NSItemProvider` they use.
- Phase 11: a modifier over a custom view whose body is several views
  passes down to that view, which applies it to each; the custom view keeps
  its node and state, and modifiers switch back when its body becomes one
  view (34 layout cases match Apple's SwiftUI). This found that a node
  turning transparent, or a transparent node resolved alone, left its
  layout parent's list of children stale; it's now cleared. Split view
  dividers resize the column before them, within its width range, and the
  detail's bar has a sidebar toggle. `ShareLink` opens AppKit's share
  picker on macOS, through the host, and elsewhere shows a menu that copies
  the items and opens URLs.
- Phase 12: a document group's windows each keep their document, read
  once from the file they open, and the window's title shows the file's
  name and whether it's edited. The File menu gets New, Open…, Save and
  Save As…; open and save dialogs are the host's, which SDL3 provides on
  macOS and Linux (through the desktop portal or zenity). File importers
  and exporters use the same dialogs. On Linux, Cacao provides
  `FileWrapper`, and file name extensions for common types; apps declare
  their own types' with `UTType.declareFilenameExtension`. The view under
  the pointer picks the pointer, the innermost style winning: text fields
  show a text pointer, links a hand, split view dividers a resize pointer.
- Rotation input: `RotateGesture` gets trackpad rotations on macOS from
  AppKit, which the host watches for, and two-finger turns on touch
  screens everywhere, which the host follows from SDL's touches; the angle
  keeps counting past a half turn. Under Wayland, SDL reports a touchpad
  pinch's scale but drops its rotation, so a small C target
  (`CacaoWayland`) asks the compositor for pinch gestures itself, on SDL's
  connection but its own event queue, with its own pointer object for the
  seat; the host dispatches that queue each loop. On Linux, tests bind it
  against a minimal compositor made with libwayland-server, which sends
  pinches and checks the rotations arrive.
- Phase 13: list rows read what their views set (background, insets,
  separators, badges) through a preference, so it works inside custom row
  views, and keep it as state that changes only when it does; rows that
  set nothing add no views. Grouped styles draw each row's piece of its
  section's card, rounded at the section's ends, from where the lazy stack
  says the row is. A lazy list of 10,000 rows still keeps under 600 nodes.
  Scroll positions follow a scroll target layout's views, found by binary
  search among a lazy stack's rows. Help shows as a tooltip, in a layer
  above presentations, after the pointer rests a second. Text with a
  content transition is a view per string, so a change in an animated
  update transitions out the old string and in the new.
- Known gaps, for later phases:
  - Tab switches don't animate (nor do they in SwiftUI by default).
  - No AT-SPI bridge on Linux yet.
  - Menu bar extras have no window style.
  - Document windows don't ask to save edits when closed, autosave, or
    keep a list of recent documents; there's no undo manager for them.
  - `ShareLink` on Linux copies and opens; there's no system share sheet.
    Previews aren't shown.
  - Touchpads rotate on Linux under Wayland only; X11's pinches have no
    rotation through SDL, which Cacao doesn't read from XInput itself.
  - On macOS, the system's trackpad momentum arrives as more scrolling, so
    snapping scroll views settle after it ends; paging moves at most a page.
  - `Canvas` composites blend modes and filters in software, at a cost
    for large canvases that use them.
  - Toolbar items are found from the structure of toolbar content, as picker
    options are; `bottomBar` items show in the navigation bar.
  - The sidebar toggle is in the detail column's bar, not the window's
    toolbar.
  - On Linux, `NSItemProvider` loads data and strings and URLs, not other
    object types.
  - Text input has no spell checking.
  - `Picker` reads its options from the structure of its content (tags,
    `ForEach`), not from evaluated views.
  - `Image(systemName:)` draws about 60 common symbols (Q6).
  - Trackpad and wheel scrolling, and input methods, haven't been tried by
    hand on Linux.

Replace Cacao's 2017 UIKit clone (≈70 `UI*` files, SDL2 + Cairo) with a
pure‑Swift implementation of the SwiftUI API. App code written against Apple's
SwiftUI should compile against `import Cacao` (and, on Linux, `import SwiftUI`)
with no changes, and run in a native window on Linux and macOS.

---

## 1. What the reference implementations teach

| | AndroidSwiftUI (`SwiftUICore`) | LinuxAppRuntime (`LinuxUI`/`LinuxSDL`) | Perry (OpenSwiftUI) |
|---|---|---|---|
| Front end | Evaluates `body` into a stringly‑typed `RenderNode` IR (≈5.7k lines, no deps) | Consumes the same style of IR from a guest (AppRuntime `DynamicUI`) | Full attribute graph (`_makeView`, `ViewInputs/Outputs`), C++ graph (Compute) |
| Why an IR | Must cross JNI to Kotlin | Must cross guest/host boundary (wasm / slice) | Matches Apple ABI |
| Layout | **None** – delegated to Compose | Pure Swift propose→size→place; no priorities / alignment guides | Faithful `Layout`, `StackLayout`, alignment guides, `ViewDimensions` (≈20k lines) |
| Drawing | Compose | `Canvas` protocol over `SDL_Renderer`, SDL3_ttf + fontconfig; no paths, transforms, images, group opacity | `DisplayList` → CALayer / UIView |
| Linux | Builds (Android CI only) | Yes | stdout renderer only, needs C++ interop |
| Tests | 123 Swift Testing tree assertions | Fake text engine + recording canvas; SDL offscreen | Large, Darwin‑centric |

**Takeaways**

1. **Cacao is in‑process.** Both IRs exist only to cross a process/language
   boundary. Cacao doesn't need stringly‑typed props, callback IDs or byte
   codecs: nodes can hold typed values and Swift closures directly.
2. **Borrow SwiftUICore's evaluator design**: path‑based identity,
   `_ConditionalContent` branch identity, `ForEach` id paths, state boxes keyed
   by path + property label, `StateReflector` seam, parameter‑pack
   `ViewBuilder`, `withObservationTracking`, subtree re‑evaluation, its test
   style. Not as a dependency (no layout hook, no `EnvironmentKey`, no
   App/Scene, stringly IR) but as a starting point we adapt.
3. **Borrow OpenSwiftUI's layout semantics**: `Layout` protocol shape,
   `ProposedViewSize` (nil / 0 / ∞), `ViewDimensions`, `AlignmentID` and
   explicit alignment, `ViewSpacing` / edge spacing, and the
   `StackLayout` priority + flexibility distribution algorithm, frame / padding
   / aspect‑ratio / fixedSize math. These files have no attribute‑graph
   coupling and are MIT. **Avoid** the attribute graph, `_GraphValue`,
   RenderBox, private‑framework shims and env‑var‑driven manifest.
4. **Borrow LinuxAppRuntime's host pieces**: layout‑box → painter split,
   `TextEngine` / `RecordingCanvas` test doubles, hit‑testing by roles,
   scroll chaining, lazy visible‑range placement, grid track resolution,
   text‑field editor model, SDL3 key mapping, offscreen SDL tests.
5. **Use a `DisplayList`** (OpenSwiftUI's idea) as the boundary between the
   view system and the renderer, and render it with a **GPU layer compositor**
   (the Core Animation model), not by repainting a CPU bitmap each frame.
   Smooth scrolling and animation come from *compositing cached layers on the
   GPU*: a scroll or an opacity/transform animation changes only a layer's
   transform, so no layout, no repaint and no texture upload happens. Content is
   rasterized only when it changes. LinuxUI's direct `SDL_Renderer` canvas is
   GPU‑backed but repaints everything every frame and can't do paths,
   transforms, group opacity or rounded clips; a Cairo/Silica bitmap of the
   whole window can do all of those but is CPU‑bound and must re‑upload the
   window on every scroll step. The compositor takes the GPU path from the
   first and the vector features from the second, only where they're needed.
6. **Borrow Perry's runtime (outside the SwiftUI folder)**: Perry's
   `PerryQuartzCore` already does exactly this on Linux. It draws each layer's
   content with CoreGraphics over `SilicaCairo` only when it changes, and
   composites the textures every frame with the SDL3 renderer.
   `PerryScrollPhysics` gives it UIScrollView‑quality scrolling (velocity,
   deceleration, rubber band, spring‑back). Cacao adopts both designs. It
   ports the compositor to typed `SDL3Swift` instead of `dlopen`'d symbols,
   and adds GPU rounded clips and tiling where Perry falls back to per‑frame
   CPU drawing.

---

## 2. Architecture

```
 App / Scene / View (public SwiftUI API)
        │  evaluate body (state, environment, observation)
        ▼
 ViewGraph: retained tree of ViewNodes (typed, path identity, dirty flags)
        │  layout: propose → sizeThatFits → placeSubviews  (Layout protocol)
        ▼
 DisplayList (items: content | effect(child list); versioned, stable ids)
        │  commit (diff by id + version)
        ▼
 Layer tree (retained; position/bounds/transform/opacity/clip/scroll offset)
        │  per layer, only when its content version changes:
        │    GPU primitives (rects, rounded rects, ellipses, strokes, gradients)
        │    glyph atlas text
        │    CPU raster fallback → texture (arbitrary paths, Canvas, shadows/blur)
        ▼
 Compositor (SDL3 render API: Metal / Vulkan / D3D12 / OpenGL), vsync‑paced
        │  per frame: walk layers, apply transforms/opacity/clips, draw textures
        ▼
 Host (SDL3): windows, frame clock, input → hit test → actions/gestures/focus
              scroll physics + animations run on the frame clock
```

### 2.1 Modules (one package)

| Target | Contents | Depends on |
|---|---|---|
| `Cacao` | Public SwiftUI API, evaluator, `ViewGraph`, layout, `DisplayList`, layer tree model, animation, scroll physics, gestures, focus, text model. **No SDL, no GPU** – builds and tests headless anywhere. Geometry types (`CGPoint`/`CGSize`/`CGRect`/`CGAffineTransform`) from Foundation; own `Path`. | Foundation, Observation |
| `CacaoScrollPhysics` | Velocity tracking, deceleration, rubber band, spring‑back (ported from Perry's `PerryScrollPhysics`; pure Swift, no deps) | – |
| `CacaoCompositor` (internal) | Layer tree → GPU: texture cache keyed by layer + content version, compositing pass, offscreen passes for group opacity / rounded clips / masks; layer‑content drawing through Silica; `TextEngine` over Silica fonts | `Cacao`, Silica (`SilicaCairo` on Linux, `SilicaCoreGraphics` on macOS) |
| `CacaoSDL` | SDL3 window(s), main loop + vsync frame clock, event translation (precise trackpad deltas, touch), clipboard, IME, cursor, display scale; SDL3 renderer backend of the compositor; implements `App.main()` | `CacaoCompositor`, `CacaoScrollPhysics`, `SDL3Swift` |
| `SwiftUI` (Linux only, optional) | `@_exported import Cacao` + `CacaoSDL`, so unmodified sources `import SwiftUI` | `Cacao`, `CacaoSDL` |
| `CacaoDemo` | Catalog app exercising every component | `Cacao`, `CacaoSDL` |
| `CacaoTests`, `CacaoCompositorTests`, `CacaoSDLTests`, benchmark | see §5 | |

Swift tools 6.4+, Swift 6 language mode, `@MainActor` on the view system (it is
single‑threaded by design; this is clearer than SwiftUICore's
"main by convention").

### 2.2 Front end: evaluation and state

- `View` with `associatedtype Body: View`, `@ViewBuilder var body`, `Never` body
  for primitives; built‑ins conform to an internal `_PrimitiveView` that
  creates/updates a typed `ViewNode`.
- `ViewBuilder` with parameter packs, `buildIf/Either/Optional/Limited
  Availability`; `TupleView`, `_ConditionalContent`, `Optional`, `ForEach`,
  `Group`, `AnyView`, `EmptyView`.
- **Retained `ViewNode` tree** keyed by structural path (type + position, `/true`
  `/false` branches, `#id` for `ForEach`, explicit `.id(_:)`). On update, the
  node's view value is replaced and `body` re‑run only if inputs changed
  (`Equatable` fast path / memberwise compare via reflection fallback) or state
  it owns/observes is dirty.
- Dynamic properties via a `DynamicProperty` protocol + reflection seam:
  `@State`, `@Binding`, `@Environment` (keypath + object), `@Observable` /
  `@Bindable` (Swift Observation, per‑node `withObservationTracking`),
  `@FocusState`, `@AppStorage`, `@SceneStorage`, `@Namespace`,
  `@GestureState`, `@StateObject` / `@ObservedObject` / `@EnvironmentObject`
  (see open question Q5).
- `EnvironmentValues` with real `EnvironmentKey`s (font, foregroundStyle,
  colorScheme, layoutDirection, isEnabled, dismiss, openURL, displayScale, …)
  and `@Entry`‑style custom keys.
- `PreferenceKey` reduced bottom‑up during layout; `onPreferenceChange`,
  `anchorPreference`, `GeometryReader`, `GeometryProxy`, coordinate spaces.
- State boxes owned by nodes and **released when the node is removed**
  (fixing SwiftUICore's never‑pruned storage).
- `onAppear` / `onDisappear` / `task` / `onChange` driven by node insertion and
  removal.

### 2.3 Layout

- Public `Layout` protocol (`sizeThatFits`, `placeSubviews`, `Cache`,
  `spacing`, `explicitAlignment`, `layoutProperties`), `LayoutSubviews`,
  `LayoutSubview`, `ProposedViewSize`, `ViewDimensions`, `ViewSpacing`,
  `AnyLayout`, `LayoutValueKey`, `layoutPriority`.
- **All built‑ins are `Layout` conformers** (one code path): `HStack`,
  `VStack`, `ZStack`, `Grid`/`GridRow`, `LazyV/HStack`, `LazyV/HGrid`,
  `ViewThatFits`, `ScrollView` content, frame / padding / offset / position /
  aspectRatio / fixedSize / safeAreaInset / overlay / background.
- Stack distribution ported from OpenSwiftUI `StackLayout` (priority groups,
  least‑flexible first, spacing by edge category); alignment guides and
  `alignmentGuide(_:computeValue:)`.
- Per‑node cache: `sizeThatFits` memoized by proposal for the pass; layout
  invalidated by dirty flags propagated up from changed nodes.
- Lazy containers place only the visible range (LinuxUI approach), realising
  rows on demand and recycling node subtrees outside the viewport.
- Safe area (window insets, keyboard) as layout input.

### 2.4 Display list, layers and GPU compositing

The model is Core Animation's, and Perry's `PerryQuartzCore` already proves it
on Linux with this exact stack (SilicaCairo for content, SDL3 renderer for
compositing, `PerryScrollPhysics` for scrolling):

- `DisplayList.Item { id, frame, version, value }`, `value` =
  `.content(.color | .shape(Path, Paint, FillStyle/StrokeStyle) | .text(Run) | .image(CGImage) | .canvas(closure))`
  or `.effect(.opacity | .clip(Path) | .transform | .shadow | .blend | .mask | .compositingGroup | .scroll(offset), DisplayList)`.
- **Commit** turns the display list into a retained **layer tree**, diffing by
  item id + version. A layer has geometry (position, bounds, bounds origin for
  scrolling), transform, opacity, clip, and *content* (a list of drawing
  items). Layer boundaries go where things change independently: every
  scroll view's content, every view with an animated transform/opacity,
  `compositingGroup`/`drawingGroup`, and large subtrees.
- **Content is rasterized only when its version changes**: each layer's
  content is drawn once with Silica (`SilicaCairo` on Linux,
  `SilicaCoreGraphics` on macOS) into a pixel buffer at
  `displayScale`, uploaded to a GPU texture, and cached. Plain rectangular
  fills skip textures entirely (`SDL_RenderFillRect`).
- **Every frame, the compositor only draws textures**: walks the layer tree
  back‑to‑front with `SDL_RenderTexture` / `SDL_RenderGeometry`, applying
  transform, opacity (`SDL_SetTextureAlphaModFloat`) and rectangular clips.
  Scrolling and transform/opacity animations change layer properties only,
  so there is **no layout, no evaluation, no rasterization and no upload while
  scrolling or animating**. Only newly exposed lazy rows are evaluated and
  drawn.
- **Beyond Perry**, where Perry redraws through CoreGraphics every frame:
  - rounded‑corner clips and `clipShape`: render the subtree into an
    offscreen target texture, then draw it through a rounded‑rect triangle fan
    with UVs (`SDL_RenderGeometry` with a texture);
  - group opacity / `compositingGroup`: offscreen target + alpha mod;
  - affine transforms beyond rotation: textured quads with transformed
    vertices;
  - very tall layers (long `ScrollView` content): tiled into ≤2048 px tiles,
    rasterizing only tiles near the viewport (`CATiledLayer` idea);
  - texture memory budget with LRU eviction of off‑screen layers.
- The SDL3 renderer picks the native GPU API (Metal on macOS; Vulkan or
  OpenGL on Linux). The compositor sits behind a small `CompositorBackend`
  protocol so an `SDL_GPU` (shader‑based) backend can replace it later
  without touching layers, for example for blur and real shadows.
- **Text**: `Text` (verbatim, `LocalizedStringKey`, concatenation, `+`,
  `AttributedString` subset, markdown subset), measured and wrapped by a
  `TextEngine` protocol; default implementation over Silica `CGFont`
  (fontconfig/FreeType via Cairo on Linux, CoreText on macOS). Fixed‑metric
  engine for tests.
- **Shapes and drawing**: `Shape`, `InsettableShape`, `Path`, `Rectangle`,
  `RoundedRectangle`, `UnevenRoundedRectangle`, `Circle`, `Ellipse`,
  `Capsule`, trims, `fill`/`stroke`, `ShapeStyle` (`Color`, gradients,
  `.tint`, hierarchical styles), `Canvas` + `GraphicsContext` on top of the
  same context.
- **Images**: PNG via Silica, asset lookup by name from `Bundle.module`,
  `resizable`, `scaledToFit/Fill`, `renderingMode`; SF Symbols mapped to a
  bundled open icon set (see Q6).
### 2.5 Scrolling

Smooth scrolling is a design requirement, not polish:

- A `ScrollView`'s content is its own layer (tiled when large). The scroll
  offset is the layer's bounds origin, a compositor property: changing it
  costs one frame of texture draws.
- **Physics** from Perry's `PerryScrollPhysics` (≈130 lines, pure Swift):
  `VelocityTracker` (last 100 ms), `Deceleration` at UIScrollView's 0.998
  per ms with `glide` for predicted rest position, `rubberBand` overscroll
  and critically damped `SpringBack`. Used for touch drags, mouse drags
  and flicks.
- **Trackpads and wheels**: SDL3's float wheel deltas drive the offset 1:1
  for precise trackpads, with momentum when the platform sends it; discrete
  mouse wheels animate to the target with a short ease, so a notch is never
  a jump.
- Driven by a **vsync frame clock** in the main loop (the `CADisplayLink`
  idea): physics and animations step once per presented frame using the
  frame's target timestamp, and the loop sleeps when nothing is moving.
- Lazy stacks/lists realize rows inside the viewport plus an overscan margin
  ahead of the scroll direction. Evaluation, layout and rasterization of new
  rows are budgeted per frame, so they don't cause dropped frames.
- `scrollTargetBehavior` (paging / view‑aligned) via `glide` + snap;
  `ScrollViewReader.scrollTo`, `scrollPosition`, `onScrollGeometryChange`,
  scroll indicators that fade on their own layer; nested scroll views chain
  (LinuxAppRuntime's innermost‑that‑can‑move rule).
- Acceptance: a 10,000‑row `List` scrolls at the display's refresh rate with
  no frame over budget, on a mid‑range Linux machine and on macOS, measured by
  a frame‑time overlay and a benchmark test.

### 2.6 Host (SDL3)

- `App.main()` (so `@main struct MyApp: App` works): creates the SDL main
  loop, one SDL window per `WindowGroup` / `Window` scene instance,
  `Settings` ignored or mapped to a window on Linux.
- Main loop: `SDL_WaitEventTimeout` plus a registered user event to wake for
  `MainActor` jobs, timers and animation frames (LinuxAppRuntime pattern);
  integrate `DispatchQueue.main` / `RunLoop.main` draining so `Task { @MainActor }`
  and `async` `.task {}` work.
- Input: pointer, wheel/trackpad, keyboard, text input + IME
  (`SDL_StartTextInput`), clipboard, cursor shapes, HiDPI scale, light/dark
  from `SDL_GetSystemTheme`.
- Hit testing over the display list using `contentShape` / `allowsHitTesting`;
  gesture system (`TapGesture`, `LongPressGesture`, `DragGesture`,
  `MagnifyGesture`, `RotateGesture`, `simultaneously`, `sequenced`,
  `exclusively`, `highPriorityGesture`); focus system (`focusable`,
  `@FocusState`, Tab traversal, `onKeyPress`, `keyboardShortcut`).

### 2.7 Controls, containers and presentations

Rendered natively in Swift with a neutral theme (libadwaita‑like on Linux,
macOS‑like on macOS — see Q7), each style a `ButtonStyle`/`ToggleStyle`/… so
user styles work:

`Button`, `Toggle`, `Slider`, `Stepper`, `TextField`, `SecureField`,
`TextEditor`, `Picker` (menu / segmented / inline / wheel), `DatePicker`,
`ColorPicker` (later), `ProgressView`, `Gauge`, `Label`, `Link`, `Menu`,
`DisclosureGroup`, `Divider`, `Spacer`, `ScrollView` + `ScrollViewReader`,
`List` (static + data, `Section`, selection, swipe actions → context menu,
`onDelete`/`onMove`), `Form`, `Table` (later), `NavigationStack` +
`NavigationPath` + `navigationDestination`, `NavigationSplitView`,
`TabView`, `.toolbar`, `.searchable`, `.sheet`, `.fullScreenCover`,
`.popover`, `.alert`, `.confirmationDialog`, `.contextMenu`.

### 2.8 Animation

`Animatable`, `VectorArithmetic`, `AnimatableData` pairs, `Animation`
(linear/ease/spring/`timingCurve`/repeat/delay/speed), `Transaction`,
`withAnimation`, `.animation(_:value:)`, `.transition` + `AnyTransition`
(opacity/scale/slide/move/offset/asymmetric/combined),
`matchedGeometryEffect`, `TimelineView`, `PhaseAnimator`/`KeyframeAnimator`
(later). Interpolation happens on layout geometry and display‑list values,
driven by the host's frame clock.

---

## 3. What happens to the existing code

- Tag the current `develop` head as `uikit-legacy` (and/or keep a
  `legacy/uikit` branch) so the UIKit clone stays reachable.
- Delete: `Sources/Cacao/**` (UIKit), `Sources/CacaoDemo/**`,
  `Tests/CacaoTests/**`, `iOS/` Xcode project, `Resources/PaintCode`,
  `Resources/ReadmeImages` (replaced with new screenshots).
- Dependencies: keep Silica (move to the `SilicaCairo` / `SilicaCoreGraphics`
  products), replace direct `Cairo` + `SDL` (SDL2) with `SDL3Swift`; drop the
  `Cairo` direct dependency.
- Rewrite `README.md`: what Cacao is now, build instructions
  (`brew install sdl3 cairo fontconfig` / `apt install libsdl3-dev libcairo2-dev libfontconfig-dev`),
  supported API matrix.

---

## 4. Phases and milestones

Each phase ends green on macOS and Linux CI.

| Phase | Scope | Done when |
|---|---|---|
| **0. Reset** ✅ | Tag legacy, remove UIKit code, new manifest/targets, CI (macOS + Ubuntu, `swift test`), README stub | Empty `Cacao` builds and tests on both OSes |
| **1. Core** ✅ | `View`, `ViewBuilder`, `ViewNode` tree + identity, `@State`/`@Binding`/`@Environment`/`EnvironmentKey`/`@Observable`, preferences; `Text`, `Color`, `Spacer`, `Divider`, stacks, `ForEach`, `Group`, `AnyView`; `Layout` protocol + stack/frame/padding/alignment; `DisplayList` | Headless tests produce correct frames for the stack/frame matrix (cross‑checked against Apple SwiftUI on macOS — §5) |
| **2. Compositor + host** ✅ | Layer tree + commit, SDL3 GPU compositor with texture cache, Silica layer‑content drawing, text engine, SDL3 host with vsync frame clock, `App`/`WindowGroup`, hit testing, `Button`, `onTapGesture`, `Shape`s, `Image`, `ScrollView` with `CacaoScrollPhysics`, frame‑time overlay | `CacaoDemo` runs on Linux and macOS; a long `ScrollView` scrolls with zero rasterization per frame (asserted by compositor counters) |
| **3. Lazy content & controls** ✅ | Lazy stacks/`List` with overscan + per‑frame budget, tiling, GPU rounded clips / group opacity; Toggle, Slider, Stepper, TextField/SecureField/TextEditor, Picker, ProgressView, Label, Link, Menu, DisclosureGroup, styles, focus + keyboard | 10,000‑row `List` scroll benchmark holds refresh rate (§2.5); "Controls" catalog screen interactive |
| **4. Containers & navigation** ✅ | Form/Section, lazy grids, Grid, NavigationStack/SplitView, TabView, toolbar, searchable, sheets/alerts/dialogs/popovers/context menus | Catalog navigation + list screens |
| **5. Animation & gestures** ✅ | Animatable, transactions, transitions (run as compositor‑side property animations where possible), matchedGeometryEffect, full gesture set, TimelineView, Canvas, scroll target behaviors | Animated catalog screens hold refresh rate on a mid‑range Linux box |
| **6. Polish** ✅ | GeometryReader/coordinate spaces edge cases, ViewThatFits, safe area, accessibility hooks (AT‑SPI later), multi‑window, `SwiftUI` alias module, docs | API coverage table published; sample apps compile unchanged |
| **7. Completeness** ✅ | Gradients, blur and blurred shadows, color effects, text decorations and spacing, `onReceive` (with publishers where there's no Combine), `containerRelativeFrame`, phase and keyframe animators, `DatePicker`, `ColorPicker`, `Gauge`, `@Entry` | Effects demo screen draws them through the GPU compositor on macOS and Linux |
| **8. Fidelity** ✅ | Masks by any view, anti-aliased concave clips, gradient text, truncation and shrinking text, gradient strokes in `Canvas`, editing by characters and words, undo, caret blink | Effects demo screen shows them on macOS and Linux |
| **9. Desktop integration** ✅ | Symbol images, drag and drop, menu commands, `Settings`, `MenuBarExtra`, NSAccessibility bridge | Demo shows symbols, menus, settings and a tray item on macOS; Linux builds and tests |
| **10. Fidelity II** ✅ | Modifiers applied per view, `matchedGeometryEffect` properties, anchors and sources, `NavigationSplitView` column widths and visibility, `onDrag`/`onDrop` with item providers and `DropDelegate` | Layout cases match Apple's SwiftUI; tests pass on macOS and Linux |
| **11. Fidelity III** ✅ | Modifiers over custom views of several views, resizable split view columns, sidebar toggle and `toolbar(removing:)`, `ShareLink` | Layout cases match Apple's SwiftUI; tests pass on macOS and Linux |
| **12. Documents** ✅ | `DocumentGroup`, `FileDocument`, `ReferenceFileDocument`, File menu commands, `fileImporter`/`fileExporter` through SDL's dialogs, window titles, pointer styles | Document tests pass with a fake dialog host on macOS and Linux |
| **13. Modifiers** ✅ | List styles and row modifiers, `scrollPosition`, `defaultScrollAnchor`, `help` tooltips, `redacted`, `controlSize`, `contentTransition`, `badge`, `UnevenRoundedRectangle` | Tests pass on macOS and Linux; lazy lists stay under their node budget |

---

## 5. Testing

- **Swift Testing** throughout.
- `CacaoTests` (headless, no SDL/Cairo): evaluate views, assert node tree,
  identity, state retention/reset, environment, preferences; run layout with
  `FixedTextEngine` and assert frames; assert display‑list items;
  drive input through a synthetic host (`tap(label:)`, `type(_:)`).
- **Layout parity**: on macOS, a test helper renders the same view with Apple
  SwiftUI (`ImageRenderer` / `NSHostingView.fittingSize` + geometry
  preferences) and compares child frames to Cacao's, for a corpus of layout
  cases. This keeps stack/frame/alignment behaviour honest.
- `CacaoCompositorTests`: commit/diff of layer trees (which layers get
  re‑rasterized for a given change; scrolling must re‑rasterize none);
  layer content drawn to a Silica bitmap and compared with reference PNGs
  (per‑OS, with tolerance); scroll physics curves against Perry's values.
- `CacaoSDLTests`: `SDL_VIDEO_DRIVER=offscreen` (software renderer), skipped
  if SDL can't start; window creation, key translation, composited
  screenshot.
- **Performance**: a benchmark target scrolls a 10,000‑row `List` and an
  image grid programmatically and reports frame‑time percentiles plus counts
  of rasterizations, uploads and evaluations per frame. CI fails on
  regressions in the counts (deterministic); frame times are tracked but not
  gated, since CI has no GPU.
- Coverage gate added once Phase 1 lands.

---

## 6. Open questions for review

1. **Module naming.** Ship the API as `import Cacao`, plus an optional Linux‑only
   `SwiftUI` module re‑exporting it so unmodified sources compile? (On macOS a
   module named `SwiftUI` would clash with Apple's.) *Recommended: yes, both.*
2. **SwiftUICore: depend vs adapt.** Plan above *adapts* its evaluator design
   into Cacao (typed nodes, layout‑aware, App/Scene, EnvironmentKey). The
   alternative is upstreaming those changes into SwiftUICore and sharing one
   front end between AndroidSwiftUI and Cacao — more coordination, less
   duplication. *Recommended: adapt now, consider converging later.*
3. **GPU backend.** *Recommended:* the SDL3 renderer API (Metal / Vulkan /
   D3D / GL chosen by SDL), compositing cached layer textures as Perry does,
   with Silica drawing layer content only when it changes. Alternatives:
   - (b) `SDL_GPU` with Cacao's own shaders: rounded clips, blur, real
     shadows and gradients all on the GPU, but considerably more work up
     front. The `CompositorBackend` protocol keeps this as a later upgrade.
   - (c) Draw vectors on the GPU too, with ThorVG or Skia: the least CPU
     rasterization, but a large C++ dependency and harder Linux builds.
4. **Share with Perry.** Copy `PerryScrollPhysics` and the compositor design
   into Cacao, or pull both into small shared PureSwift packages (for
   example `ScrollPhysics`, and a `LayerCompositor` over SDL3 + Silica) that
   Perry and Cacao both depend on? *Recommended: copy now; extract once both
   are stable.*
5. **`ObservableObject` / `@StateObject` / `@Published`.** Combine isn't on
   Linux. Options: (a) support only `@Observable`; (b) provide a minimal
   `ObservableObject` + `@Published` + `objectWillChange` in Cacao (Linux only,
   re‑exported Combine on macOS); (c) depend on OpenCombine.
   *Recommended: (b).*
6. **Symbols.** Map common SF Symbol names to a bundled open icon set
   (e.g. Lucide / Material Symbols, both permissively licensed) vs. Unicode
   fallbacks only.
7. **Look and feel.** One neutral theme everywhere, or per‑platform
   (libadwaita‑like on Linux, macOS‑like on macOS)?
8. **Legacy UIKit code.** Tag + delete (recommended), or keep it as a separate
   `CacaoUIKit` target for now?
9. **Minimum platforms / toolchain.** Swift 6.4+, macOS 14+, Ubuntu 22.04+ with
   SDL3 from source/PPA (SDL3 isn't in 22.04 apt) — acceptable?
