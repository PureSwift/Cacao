//
//  WindowHost.swift
//  CacaoSDL
//
//  Created by Alsey Coleman Miller on 11/13/26.
//

import Foundation
#if canImport(CoreGraphics)
import CoreGraphics
#endif
import Cacao
import CacaoCompositor
import CSDL3

/// One window: its view graph, compositor and input.
@MainActor
final class WindowHost {

    let window: OpaquePointer

    let renderer: OpaquePointer

    let id: SDL_WindowID

    let graph: ViewGraph

    let compositor: Compositor

    private let backend: SDLBackend

    private let scrollController = ScrollController()

    /// Whether the next frame must be drawn.
    private var needsRender = true

    /// Whether the next frame must lay out again.
    private var needsLayout = true

    /// Whether to draw frame times and compositor counts.
    var showsStatistics = ProcessInfo.processInfo.environment["CACAO_SHOW_STATISTICS"] == "1"

    private var frameTimes: [Double] = []

    private var lastFrameTime: Double?

    private static let resizable: SDL_WindowFlags = 0x0000_0000_0000_0020

    private static let highPixelDensity: SDL_WindowFlags = 0x0000_0000_0000_2000

    init?(description: WindowDescription, textEngine: SilicaTextEngine) {
        let size = description.defaultSize ?? CGSize(width: 800, height: 600)
        guard let window = SDL_CreateWindow(
            description.title,
            Int32(size.width),
            Int32(size.height),
            Self.resizable | Self.highPixelDensity
        ) else {
            return nil
        }
        guard let renderer = SDL_CreateRenderer(window, nil) else {
            SDL_DestroyWindow(window)
            return nil
        }
        SDL_SetRenderVSync(renderer, 1)
        self.window = window
        self.renderer = renderer
        self.id = SDL_GetWindowID(window)
        self.backend = SDLBackend(renderer: renderer)
        self.compositor = Compositor(backend: backend, textEngine: textEngine)
        var environment = EnvironmentValues()
        environment.displayScale = CGFloat(SDL_GetWindowPixelDensity(window))
        environment.colorScheme = SDL_GetSystemTheme() == SDL_SYSTEM_THEME_DARK ? .dark : .light
        self.graph = ViewGraph(rootView: description.rootView, environment: environment, textEngine: textEngine)
        updateBackground()
        graph.onNeedsDisplay = { [weak self] in
            self?.needsRender = true
        }
    }

    func close() {
        backend.destroyAllTextures()
        SDL_DestroyRenderer(renderer)
        SDL_DestroyWindow(window)
    }

    /// The window's size in points.
    var size: CGSize {
        var width: Int32 = 0
        var height: Int32 = 0
        SDL_GetWindowSize(window, &width, &height)
        return CGSize(width: CGFloat(width), height: CGFloat(height))
    }

    var scale: CGFloat {
        CGFloat(SDL_GetWindowPixelDensity(window))
    }

    /// Whether the window needs frames even without events.
    var isAnimating: Bool {
        scrollController.isAnimating
    }

    private func updateBackground() {
        compositor.backgroundColor = graph.environment.colorScheme == .dark
            ? Color.Resolved(red: 0, green: 0, blue: 0)
            : Color.Resolved(red: 1, green: 1, blue: 1)
    }

    // MARK: Events

    func handle(_ event: SDL_Event, now: Double) {
        switch SDL_EventType(event.type) {
        case SDL_EVENT_WINDOW_RESIZED, SDL_EVENT_WINDOW_PIXEL_SIZE_CHANGED, SDL_EVENT_WINDOW_DISPLAY_SCALE_CHANGED:
            if graph.environment.displayScale != scale {
                graph.environment.displayScale = scale
            }
            needsLayout = true
            needsRender = true
        case SDL_EVENT_WINDOW_EXPOSED:
            needsRender = true
        case SDL_EVENT_MOUSE_BUTTON_DOWN where event.button.button == UInt8(SDL_BUTTON_LEFT):
            graph.pointer(.began, at: CGPoint(x: CGFloat(event.button.x), y: CGFloat(event.button.y)))
        case SDL_EVENT_MOUSE_BUTTON_UP where event.button.button == UInt8(SDL_BUTTON_LEFT):
            graph.pointer(.ended, at: CGPoint(x: CGFloat(event.button.x), y: CGFloat(event.button.y)))
        case SDL_EVENT_MOUSE_MOTION where event.motion.state & 0x1 != 0:
            graph.pointer(.moved, at: CGPoint(x: CGFloat(event.motion.x), y: CGFloat(event.motion.y)))
        case SDL_EVENT_MOUSE_WHEEL:
            var x = event.wheel.x
            var y = event.wheel.y
            if event.wheel.direction == SDL_MOUSEWHEEL_FLIPPED {
                x = -x
                y = -y
            }
            scrollController.wheel(
                x: x,
                y: y,
                at: CGPoint(x: CGFloat(event.wheel.mouse_x), y: CGFloat(event.wheel.mouse_y)),
                graph: graph,
                now: now
            )
        case SDL_EVENT_KEY_DOWN where event.key.key == SDLK_F12:
            showsStatistics.toggle()
            needsRender = true
        default:
            break
        }
    }

    func systemThemeChanged() {
        let colorScheme: ColorScheme = SDL_GetSystemTheme() == SDL_SYSTEM_THEME_DARK ? .dark : .light
        if graph.environment.colorScheme != colorScheme {
            graph.environment.colorScheme = colorScheme
            updateBackground()
        }
    }

    // MARK: Frames

    /// Steps animations, updates, lays out and draws if anything changed.
    func frame(now: Double) {
        scrollController.step(now: now)
        if graph.needsUpdate {
            graph.update()
            needsLayout = true
        }
        let size = size
        if needsLayout || graph.size != size {
            graph.layout(in: size)
            needsLayout = false
            needsRender = true
        }
        if graph.needsDisplay {
            needsRender = true
        }
        guard needsRender || showsStatistics && isAnimating else {
            lastFrameTime = nil
            return
        }
        needsRender = false
        let start = SDLHost.now
        compositor.render(graph.displayList(), size: size, scale: scale)
        if showsStatistics {
            drawStatistics(renderTime: SDLHost.now - start, now: now)
        }
        if let path = screenshotPath {
            screenshotPath = nil
            saveScreenshot(to: path)
        }
        SDL_RenderPresent(renderer)
    }

    /// Where to save the first frame as a PNG, then quit; from the
    /// `CACAO_SCREENSHOT` environment variable.
    private var screenshotPath = ProcessInfo.processInfo.environment["CACAO_SCREENSHOT"]

    /// Whether a screenshot was saved, after which the app quits.
    private(set) var didSaveScreenshot = false

    private func saveScreenshot(to path: String) {
        defer { didSaveScreenshot = true }
        guard let surface = SDL_RenderReadPixels(renderer, nil),
              let rgba = SDL_ConvertSurface(surface, SDL_PIXELFORMAT_ABGR8888) else {
            print("Cacao: screenshot failed: \(String(cString: SDL_GetError()))")
            return
        }
        defer {
            SDL_DestroySurface(rgba)
            SDL_DestroySurface(surface)
        }
        let width = Int(rgba.pointee.w)
        let height = Int(rgba.pointee.h)
        let pitch = Int(rgba.pointee.pitch)
        let pixels = Data(bytes: rgba.pointee.pixels, count: pitch * height)
        guard let png = Rasterizer.encodePNG(width: width, height: height, bytesPerRow: pitch, pixels: pixels) else {
            print("Cacao: screenshot encoding failed")
            return
        }
        do {
            try png.write(to: URL(fileURLWithPath: path))
            print("Cacao: saved screenshot to \(path)")
        } catch {
            print("Cacao: screenshot not saved: \(error)")
        }
    }

    private func drawStatistics(renderTime: Double, now: Double) {
        if let lastFrameTime {
            frameTimes.append(now - lastFrameTime)
            if frameTimes.count > 60 { frameTimes.removeFirst() }
        }
        lastFrameTime = now
        let average = frameTimes.isEmpty ? 0 : frameTimes.reduce(0, +) / Double(frameTimes.count)
        let fps = average > 0 ? 1 / average : 0
        let frame = compositor.lastFrame
        let text = String(
            format: "%.0f fps  render %.1f ms  raster %d  upload %d  draws %d  textures %d  resolves %d",
            fps, renderTime * 1000, frame.rasterizations, frame.uploads, frame.draws, frame.textures,
            graph.statistics.resolves
        )
        let scale = Float(self.scale)
        SDL_SetRenderClipRect(renderer, nil)
        SDL_SetRenderDrawColorFloat(renderer, 0, 0, 0, 0.7)
        var background = SDL_FRect(x: 0, y: 0, w: Float(text.count * 8 + 8) * scale, h: 16 * scale)
        SDL_RenderFillRect(renderer, &background)
        SDL_SetRenderScale(renderer, scale, scale)
        SDL_SetRenderDrawColorFloat(renderer, 1, 1, 1, 1)
        SDL_RenderDebugText(renderer, 4, 4, text)
        SDL_SetRenderScale(renderer, 1, 1)
    }
}
