# DarwinUI on Cacao

[DarwinAppRuntime](https://github.com/PureSwift/DarwinAppRuntime)'s SwiftUI
renderer, `DarwinUI`, compiled and tested against Cacao: a real SwiftUI
code base, as a check on Cacao's compatibility.

- **Linux:** `DarwinUI`'s sources compile unmodified, through Cacao's
  `SwiftUI` and `Combine` modules. Only its `#if os(macOS)` code is taken
  as `#if !os(iOS)`, since Linux is neither.
- **macOS:** `import SwiftUI` and `import Combine` are Apple's there, so
  `sync.sh` puts `import Cacao` in their place.

`DarwinHost` here is the part of DarwinAppRuntime's host the renderer uses:
its logger, `DarwinBundle` and `HostModule`. `RenderingTests` hosts
`RendererView` in a Cacao view graph where DarwinAppRuntime's hosts it in an
`NSHostingView`; DarwinUI's other tests run as they are. All pass on
macOS. On Linux, `releasingTheRendererRemovesItsScene` fails: the renderer's
`deinit` doesn't see its main-actor test as the main thread
(`Thread.isMainThread`), so it removes the scene a turn of the main queue
later.

## Running

With DarwinAppRuntime and AppRuntime checked out beside Cacao (or
`DARWIN_APP_RUNTIME_PATH` and `APPRUNTIME_PATH` pointing at them):

```sh
./sync.sh
swift test
```

`RendererDemo` shows the rendering tests' tree in a window; `DEMO_MODIFIERS`
applies every test modifier to every node, and `DEMO_DETAIL` pushes the
detail level:

```sh
swift run RendererDemo
```
