# Cacao

[![Swift](https://img.shields.io/badge/swift-6.4-orange.svg?style=flat)](https://swift.org)
[![Platforms](https://img.shields.io/badge/platform-linux%20%7C%20macOS-lightgrey.svg)](https://swift.org)
[![License](https://img.shields.io/badge/license-MIT-71787A.svg)](https://tldrlegal.com/license/mit-license)

The SwiftUI API, implemented in pure Swift, for Linux and macOS.

Cacao evaluates your views, lays them out with SwiftUI's layout rules, and
renders them with a GPU layer compositor: content is drawn with
[Silica](https://github.com/PureSwift/Silica) (Cairo on Linux, CoreGraphics
on macOS) only when it changes, and composited every frame by the
[SDL3](https://github.com/PureSwift/SDL) renderer (Metal, Vulkan or OpenGL),
so scrolling and animation never repaint.

> **Status:** early development (Phase 7: views, layout, controls, text input,
> lazy lists, forms, grids, navigation, tabs, presentations, animations,
> transitions, gestures, `TimelineView`, `Canvas`, geometry readers,
> `ObservableObject` and storage, accessibility, multiple windows, gradients,
> blur, shadows and color effects, phase and keyframe animators, date and
> color pickers, gauges and `@Entry`, drawn by a GPU compositor on Linux and
> macOS). See
> [API coverage](Documentation/APICoverage.md) for what's implemented. See
> [the plan](Documentation/Plan.md) for the architecture and roadmap. The
> previous UIKit implementation is preserved at the
> [`uikit-legacy`](https://github.com/PureSwift/Cacao/tree/uikit-legacy) tag.

## Modules

| Module | |
|---|---|
| `Cacao` | The SwiftUI API: views, state, environment, layout and the display list. Platform-neutral, builds headless. |
| `CacaoMacros` | The `@Entry` macro. |
| `CacaoSDL` | Windows, the main loop, input and the SDL3 GPU compositor backend. |
| `CacaoScrollPhysics` | Velocity tracking, deceleration, rubber band and spring-back. |
| `SwiftUI` (Linux only) | Re-exports Cacao, so sources that `import SwiftUI` compile unchanged. |

## Usage

```swift
import CacaoSDL // or `import SwiftUI` on Linux

@main
struct HelloApp: App {
    var body: some Scene {
        WindowGroup("Hello") {
            ContentView()
        }
    }
}

struct ContentView: View {
    @State private var count = 0

    var body: some View {
        VStack(spacing: 12) {
            Text("Count: \(count)")
                .font(.title)
            Button("Increment") { count += 1 }
                .buttonStyle(.borderedProminent)
        }
    }
}
```

Run the demo with `swift run CacaoDemo`. Press F12 (or set
`CACAO_SHOW_STATISTICS=1`) for frame times and compositor counts, and set
`CACAO_SCREENSHOT=path.png` to save the first frame and quit.

## Building

Requires Swift 6.4 or later and SDL3.

### macOS

```bash
brew install sdl3 cairo fontconfig
```

```bash
swift build
```

### Linux

Install Cairo and fontconfig, and SDL3 (3.2 or later), which isn't packaged
on Ubuntu 24.04 and earlier, so build it from source:

```bash
sudo apt-get install cmake ninja-build pkg-config fonts-dejavu-core libcairo2-dev libfontconfig-dev libfreetype-dev libx11-dev libxext-dev libxrandr-dev libxcursor-dev libxfixes-dev libxi-dev libxss-dev libxtst-dev libxkbcommon-dev libwayland-dev wayland-protocols libdecor-0-dev libdrm-dev libgbm-dev libegl-dev libgl-dev libgles-dev libvulkan-dev libdbus-1-dev libudev-dev libpulse-dev libasound2-dev
```

```bash
git clone --depth 1 --branch release-3.4.8 https://github.com/libsdl-org/SDL.git
```

```bash
cmake -S SDL -B SDL/build -G Ninja -DCMAKE_BUILD_TYPE=Release
```

```bash
cmake --build SDL/build && sudo cmake --install SDL/build
```

```bash
swift build
```

## Testing

```bash
SDL_VIDEO_DRIVER=offscreen swift test
```

## License

MIT. See [LICENSE](LICENSE).
