# Text measurement for host scenes

A third party `HostScene` can retain `window.textMeasurement` from the
`HostRuntime.openWindow` scene factory. The service is available before the
scene's first update and uses the window compositor's `SilicaTextEngine`.
The same service is available for popups and snapshots. Call it on the main actor.
Its public protocol and result types live in `CacaoRender`; clients do not need
access to CacaoCompositor internals.

```swift
import CacaoHost
import CacaoRender

// Inside your scene, after receiving window.textMeasurement:
let geometry = measurement.measure(resolvedText, in: ProposedViewSize(textFrame.size))
let caret = geometry.caretRect(for: scalarOffset)
let clickedOffset = geometry.offset(nearest: CGPoint(
    x: mouse.x - textFrame.minX,
    y: mouse.y - textFrame.minY
))
```

Use the exact `ResolvedText` and rectangle size used for drawing. Positions are
in points relative to that rectangle's top-left, including text alignment.
Each line exposes its frame, baseline, and boundary x positions so a client can
construct selection rectangles between the selected boundaries on each line.
Translate these rectangles by the text frame's origin before drawing them.
Empty text has one insertion position; supply an empty run with the intended
font to obtain its caret height.

Offsets count **Unicode scalars**, starting at zero, in the concatenation of
all runs. They do not count UTF-8 bytes, UTF-16 units, or Swift `Character`s.
This follows the current renderer, which draws scalar glyphs without cluster
shaping or bidirectional layout. Text inside a combining sequence can therefore
have an insertion position. A client that edits graphemes should constrain its
own selection offsets to grapheme boundaries.

For Graphite's MacRoman selections, decode the original bytes without Unicode
normalization. Convert a byte offset by decoding the byte prefix and counting
its scalars, for example:

```swift
let prefix = String(data: bytes.prefix(byteOffset), encoding: .macOSRoman)
let scalarOffset = prefix?.unicodeScalars.count
```

For the inverse, build a table of cumulative scalar counts for decoded byte
prefixes and look up the measured offset. Keep this mapping with the source
bytes; do not assume Unicode offsets equal UTF-8 or UTF-16 offsets. Encoding
arbitrary Unicode back to MacRoman may fail and is a client policy decision.

At soft wraps, an offset can have a position on both lines. `caretRect(for:)`
chooses the later line; a client needing upstream affinity can inspect the
individual lines. Newline offsets and spaces discarded at word wraps lie at
line ends. Hit testing first chooses the nearest line vertically, then the
nearest visible insertion x; it clamps outside points and breaks ties toward
the earlier line or boundary.

Measurement follows wrapping, font scaling, alignment, height limits and
truncation used for drawing. Hidden text has no insertion geometry, except
for the source offsets at the edges of an ellipsis. Caret lookup returns `nil`
for unrepresented offsets. Editable clients should normally remove line and
height limits so all source text remains available.
