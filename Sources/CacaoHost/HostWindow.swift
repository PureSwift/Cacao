//
//  HostWindow.swift
//  CacaoHost
//
//  Created by Alsey Coleman Miller on 11/13/26.
//

import Foundation
#if canImport(CoreGraphics)
import CoreGraphics
#endif
import CacaoRender
import CacaoCompositor
import CSDL3
#if os(macOS)
import AppKit
#endif

/// One window: its SDL window and renderer, its compositor, and the scene
/// it shows and sends input to.
@MainActor
public final class HostWindow {

    /// The `SDL_Window`.
    public let sdlWindow: OpaquePointer

    /// The `SDL_Renderer`.
    public let sdlRenderer: OpaquePointer

    /// The `SDL_WindowID`.
    public let id: UInt32

    /// What the window shows.
    public internal(set) var scene: (any HostScene)?

    package let compositor: Compositor

    private let backend: SDLBackend

    /// Whether the window has keyboard focus.
    public var isKey: Bool {
        SDL_GetKeyboardFocus() == sdlWindow
    }

    /// Where the mouse is, for pinches.
    private var mouseLocation = CGPoint(x: 0, y: 0)

    /// A pinch's total scale since it began.
    private var pinchScale = 1.0

    /// The rotation so far of a trackpad pinch the system reports, in
    /// radians, clockwise.
    private var systemRotationAngle = 0.0

    /// Whether the next frame must be drawn.
    private var needsRender = true

    /// Whether to draw frame times and compositor counts.
    public var showsStatistics = ProcessInfo.processInfo.environment["CACAO_SHOW_STATISTICS"] == "1"

    private var frameTimes: [Double] = []

    private var lastFrameTime: Double?

    private static let resizable: SDL_WindowFlags = 0x0000_0000_0000_0020

    private static let highPixelDensity: SDL_WindowFlags = 0x0000_0000_0000_2000

    /// What the scene last asked of the window.
    private var shown = HostWindowState()

    private var shownCursor: HostCursor?

    private var isTextInputActive = false

    init?(title: String, size: CGSize, textEngine: SilicaTextEngine) {
        guard let window = SDL_CreateWindow(
            title,
            Int32(size.width),
            Int32(size.height),
            Self.resizable | Self.highPixelDensity
        ) else {
            return nil
        }
        guard let renderer = SDL_CreateRenderer(window, HostRuntime.rendererName) else {
            SDL_DestroyWindow(window)
            return nil
        }
        SDL_SetRenderVSync(renderer, 1)
        self.sdlWindow = window
        self.sdlRenderer = renderer
        self.id = SDL_GetWindowID(window)
        self.backend = SDLBackend(renderer: renderer)
        self.compositor = Compositor(backend: backend, textEngine: textEngine)
        #if os(macOS)
        installRotationMonitor()
        #endif
    }

    /// Brings the window to the front.
    public func raise() {
        SDL_RaiseWindow(sdlWindow)
    }

    /// Draws the scene again on the next frame.
    public func setNeedsDisplay() {
        needsRender = true
    }

    func close() {
        scene?.detach()
        scene = nil
        #if os(macOS)
        if let rotationMonitor {
            NSEvent.removeMonitor(rotationMonitor)
        }
        #endif
        backend.destroyAllTextures()
        SDL_DestroyRenderer(sdlRenderer)
        SDL_DestroyWindow(sdlWindow)
    }

    /// The window's size in points.
    public var size: CGSize {
        var width: Int32 = 0
        var height: Int32 = 0
        SDL_GetWindowSize(sdlWindow, &width, &height)
        return CGSize(width: CGFloat(width), height: CGFloat(height))
    }

    /// Pixels per point.
    public var scale: CGFloat {
        CGFloat(SDL_GetWindowPixelDensity(sdlWindow))
    }

    /// Whether the window needs frames even without events.
    var isAnimating: Bool {
        scene?.isAnimating ?? false
    }

    /// The window's Wayland surface, when SDL uses Wayland.
    var waylandSurface: UnsafeMutableRawPointer? {
        SDL_GetPointerProperty(SDL_GetWindowProperties(sdlWindow), SDL_PROP_WINDOW_WAYLAND_SURFACE_POINTER, nil)
    }

    /// Delivers a change to a trackpad rotation from the system, which
    /// reports each change; scenes see the total, in radians.
    func systemRotation(_ phase: HostPhase, clockwiseDegrees delta: Double, at location: CGPoint? = nil) {
        if phase == .began {
            systemRotationAngle = 0
        }
        systemRotationAngle += delta * .pi / 180
        scene?.handle(.rotate(phase, angle: systemRotationAngle, at: location ?? mouseLocation), time: HostRuntime.now)
        needsRender = true
    }

    // MARK: Events

    /// Files and text dropped from the system so far, in one drop.
    private var droppedItems: [Any] = []

    func handle(_ event: SDL_Event, now: Double) {
        guard let scene else { return }
        switch SDL_EventType(event.type) {
        case SDL_EVENT_WINDOW_RESIZED, SDL_EVENT_WINDOW_PIXEL_SIZE_CHANGED, SDL_EVENT_WINDOW_DISPLAY_SCALE_CHANGED:
            scene.handle(.geometryChanged, time: now)
            needsRender = true
        case SDL_EVENT_WINDOW_EXPOSED:
            needsRender = true
        case SDL_EVENT_MOUSE_BUTTON_DOWN where event.button.button == UInt8(SDL_BUTTON_LEFT):
            scene.handle(.pointer(.began, at: CGPoint(x: CGFloat(event.button.x), y: CGFloat(event.button.y))), time: now)
        case SDL_EVENT_MOUSE_BUTTON_DOWN where event.button.button == UInt8(SDL_BUTTON_RIGHT):
            scene.handle(.secondaryClick(at: CGPoint(x: CGFloat(event.button.x), y: CGFloat(event.button.y))), time: now)
        case SDL_EVENT_MOUSE_BUTTON_UP where event.button.button == UInt8(SDL_BUTTON_LEFT):
            scene.handle(.pointer(.ended, at: CGPoint(x: CGFloat(event.button.x), y: CGFloat(event.button.y))), time: now)
        case SDL_EVENT_MOUSE_MOTION:
            mouseLocation = CGPoint(x: CGFloat(event.motion.x), y: CGFloat(event.motion.y))
            if event.motion.state & 0x1 != 0 {
                scene.handle(.pointer(.moved, at: mouseLocation), time: now)
            } else {
                scene.handle(.hover(at: mouseLocation), time: now)
            }
        case SDL_EVENT_WINDOW_MOUSE_LEAVE:
            scene.handle(.hover(at: nil), time: now)
        case SDL_EVENT_PINCH_BEGIN:
            // SDL reports each change; scenes see the total.
            pinchScale = 1
            scene.handle(.magnify(.began, scale: pinchScale, at: mouseLocation), time: now)
        case SDL_EVENT_PINCH_UPDATE:
            pinchScale *= Double(event.pinch.scale)
            scene.handle(.magnify(.moved, scale: pinchScale, at: mouseLocation), time: now)
        case SDL_EVENT_PINCH_END:
            scene.handle(.magnify(.ended, scale: pinchScale, at: mouseLocation), time: now)
        case SDL_EVENT_FINGER_DOWN, SDL_EVENT_FINGER_MOTION, SDL_EVENT_FINGER_UP, SDL_EVENT_FINGER_CANCELED:
            // Touch screens only: trackpads' gestures come from the system.
            guard SDL_GetTouchDeviceType(event.tfinger.touchID) == SDL_TOUCH_DEVICE_DIRECT else { break }
            let size = size
            let location = CGPoint(x: CGFloat(event.tfinger.x) * size.width, y: CGFloat(event.tfinger.y) * size.height)
            let phase: HostPhase = switch SDL_EventType(event.type) {
            case SDL_EVENT_FINGER_DOWN: .began
            case SDL_EVENT_FINGER_MOTION: .moved
            case SDL_EVENT_FINGER_UP: .ended
            default: .cancelled
            }
            scene.handle(.touch(phase, finger: UInt64(event.tfinger.fingerID), at: location), time: now)
        case SDL_EVENT_MOUSE_WHEEL:
            var x = event.wheel.x
            var y = event.wheel.y
            if event.wheel.direction == SDL_MOUSEWHEEL_FLIPPED {
                x = -x
                y = -y
            }
            scene.handle(
                .scroll(x: x, y: y, at: CGPoint(x: CGFloat(event.wheel.mouse_x), y: CGFloat(event.wheel.mouse_y))),
                time: now
            )
        case SDL_EVENT_KEY_DOWN where event.key.key == SDLK_F12:
            showsStatistics.toggle()
            needsRender = true
        case SDL_EVENT_KEY_DOWN:
            if let key = Self.key(event.key.key, modifiers: event.key.mod) {
                scene.handle(.keyDown(key, modifiers: Self.modifiers(event.key.mod)), time: now)
            }
        case SDL_EVENT_DROP_BEGIN:
            droppedItems = []
        case SDL_EVENT_DROP_POSITION:
            scene.handle(.drop(.moved, items: droppedItems, at: CGPoint(x: CGFloat(event.drop.x), y: CGFloat(event.drop.y))), time: now)
        case SDL_EVENT_DROP_FILE:
            if let data = event.drop.data {
                droppedItems.append(URL(fileURLWithPath: String(cString: data)))
            }
        case SDL_EVENT_DROP_TEXT:
            if let data = event.drop.data {
                droppedItems.append(String(cString: data))
            }
        case SDL_EVENT_DROP_COMPLETE:
            scene.handle(.drop(.dropped, items: droppedItems, at: CGPoint(x: CGFloat(event.drop.x), y: CGFloat(event.drop.y))), time: now)
            droppedItems = []
            needsRender = true
        case SDL_EVENT_TEXT_INPUT:
            if let text = event.text.text {
                scene.handle(.text(String(cString: text)), time: now)
            }
        default:
            break
        }
    }

    // MARK: Keyboard

    private static func modifiers(_ mod: SDL_Keymod) -> HostKeyModifiers {
        var modifiers: HostKeyModifiers = []
        if mod & 0x0003 != 0 { modifiers.insert(.shift) }
        if mod & 0x00C0 != 0 { modifiers.insert(.control) }
        if mod & 0x0300 != 0 { modifiers.insert(.option) }
        if mod & 0x0C00 != 0 { modifiers.insert(.command) }
        return modifiers
    }

    /// The key for an SDL key code. Characters only count with the control
    /// or command key held; typing arrives as text input.
    private static func key(_ key: SDL_Keycode, modifiers mod: SDL_Keymod) -> HostKey? {
        switch key {
        case SDLK_LEFT: return .left
        case SDLK_RIGHT: return .right
        case SDLK_UP: return .up
        case SDLK_DOWN: return .down
        case SDLK_HOME: return .home
        case SDLK_END: return .end
        case SDLK_PAGEUP: return .pageUp
        case SDLK_PAGEDOWN: return .pageDown
        case SDLK_BACKSPACE: return .backspace
        case SDLK_DELETE: return .delete
        case SDLK_RETURN, SDLK_KP_ENTER: return .returnKey
        case SDLK_ESCAPE: return .escape
        case SDLK_TAB: return .tab
        default:
            guard mod & 0x0CC0 != 0, key < 0x80, let scalar = Unicode.Scalar(key) else {
                return nil
            }
            return .character(Character(scalar))
        }
    }

    // MARK: Window state

    /// Shows what the scene asks of the window: its title and pointer, and
    /// text input (with an input method) as focus moves in and out of text.
    private func apply(_ state: HostWindowState) {
        if state.title != shown.title, let title = state.title {
            SDL_SetWindowTitle(sdlWindow, title)
        }
        if state.cursor != shownCursor {
            shownCursor = state.cursor
            SDL_SetCursor(SystemCursors.cursor(for: state.cursor))
        }
        if state.acceptsTextInput != isTextInputActive {
            isTextInputActive = state.acceptsTextInput
            if state.acceptsTextInput {
                SDL_StartTextInput(sdlWindow)
            } else {
                SDL_StopTextInput(sdlWindow)
            }
        }
        if state.acceptsTextInput, let frame = state.textInputArea {
            var area = SDL_Rect(
                x: Int32(frame.minX), y: Int32(frame.minY),
                w: Int32(frame.width), h: Int32(frame.height)
            )
            SDL_SetTextInputArea(sdlWindow, &area, 0)
        }
        compositor.backgroundColor = state.backgroundColor
        shown = state
    }

    #if os(macOS)
    /// Watches for trackpad rotations, which SDL doesn't report.
    private var rotationMonitor: Any?

    /// Delivers the window's trackpad rotations to its scene. AppKit
    /// reports each change, counterclockwise in degrees.
    private func installRotationMonitor() {
        rotationMonitor = NSEvent.addLocalMonitorForEvents(matching: .rotate) { [weak self] event in
            MainActor.assumeIsolated {
                guard let self, let view = self.contentView, event.window === view.window else { return }
                let point = view.convert(event.locationInWindow, from: nil)
                let location = CGPoint(x: point.x, y: view.isFlipped ? point.y : view.bounds.height - point.y)
                let phase: HostPhase? = switch event.phase {
                case .began: .began
                case .changed: .moved
                case .ended: .ended
                case .cancelled: .cancelled
                default: nil
                }
                if let phase {
                    self.systemRotation(phase, clockwiseDegrees: phase == .moved ? -Double(event.rotation) : 0, at: location)
                }
            }
            return event
        }
    }

    /// The window's AppKit content view.
    public var contentView: NSView? {
        let properties = SDL_GetWindowProperties(sdlWindow)
        guard let pointer = SDL_GetPointerProperty(properties, SDL_PROP_WINDOW_COCOA_WINDOW_POINTER, nil) else { return nil }
        return Unmanaged<NSWindow>.fromOpaque(pointer).takeUnretainedValue().contentView
    }
    #endif

    // MARK: Frames

    /// Updates the scene, and draws it if anything changed.
    func frame(now: Double) {
        guard let scene else { return }
        let size = size
        let scale = scale
        if scene.update(HostFrame(time: now, size: size, scale: scale, safeArea: safeArea(size: size))) {
            needsRender = true
        }
        apply(scene.windowState)
        // A delayed screenshot is of the first frame after the delay, drawn
        // even if nothing changed by then.
        if screenshotPath != nil, now >= screenshotTime {
            needsRender = true
        }
        guard needsRender || showsStatistics && isAnimating else {
            lastFrameTime = nil
            return
        }
        needsRender = false
        let start = HostRuntime.now
        compositor.render(scene.displayList(), size: size, scale: scale)
        scene.didRender(time: start)
        if showsStatistics {
            drawStatistics(renderTime: HostRuntime.now - start, now: now, scene: scene)
        }
        if let path = screenshotPath, now >= screenshotTime {
            screenshotPath = nil
            saveScreenshot(to: path)
        }
        SDL_RenderPresent(sdlRenderer)
    }

    /// The parts of the window the system covers.
    private func safeArea(size: CGSize) -> HostInsets {
        var rect = SDL_Rect()
        guard SDL_GetWindowSafeArea(sdlWindow, &rect), rect.w > 0, rect.h > 0 else { return HostInsets() }
        return HostInsets(
            top: CGFloat(rect.y),
            left: CGFloat(rect.x),
            bottom: max(size.height - CGFloat(rect.y + rect.h), 0),
            right: max(size.width - CGFloat(rect.x + rect.w), 0)
        )
    }

    /// Where to save the first frame as a PNG, then quit; from the
    /// `CACAO_SCREENSHOT` environment variable.
    private var screenshotPath = ProcessInfo.processInfo.environment["CACAO_SCREENSHOT"]

    /// When the screenshot is taken: a frame drawn
    /// `CACAO_SCREENSHOT_DELAY` seconds after the window opened, for content
    /// that arrives after the first frame.
    private let screenshotTime = HostRuntime.now
        + (ProcessInfo.processInfo.environment["CACAO_SCREENSHOT_DELAY"].flatMap(Double.init) ?? 0)

    /// Whether a screenshot was saved, after which the host quits.
    private(set) var didSaveScreenshot = false

    private func saveScreenshot(to path: String) {
        defer { didSaveScreenshot = true }
        guard let surface = SDL_RenderReadPixels(sdlRenderer, nil),
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

    private func drawStatistics(renderTime: Double, now: Double, scene: any HostScene) {
        if let lastFrameTime {
            frameTimes.append(now - lastFrameTime)
            if frameTimes.count > 60 { frameTimes.removeFirst() }
        }
        lastFrameTime = now
        let average = frameTimes.isEmpty ? 0 : frameTimes.reduce(0, +) / Double(frameTimes.count)
        let fps = average > 0 ? 1 / average : 0
        let frame = compositor.lastFrame
        var text = String(
            format: "%.0f fps  render %.1f ms  raster %d  upload %d  draws %d  textures %d",
            fps, renderTime * 1000, frame.rasterizations, frame.uploads, frame.draws, frame.textures
        )
        let extra = scene.statistics
        if !extra.isEmpty {
            text += "  " + extra
        }
        let scale = Float(self.scale)
        SDL_SetRenderClipRect(sdlRenderer, nil)
        SDL_SetRenderDrawColorFloat(sdlRenderer, 0, 0, 0, 0.7)
        var background = SDL_FRect(x: 0, y: 0, w: Float(text.count * 8 + 8) * scale, h: 16 * scale)
        SDL_RenderFillRect(sdlRenderer, &background)
        SDL_SetRenderScale(sdlRenderer, scale, scale)
        SDL_SetRenderDrawColorFloat(sdlRenderer, 1, 1, 1, 1)
        SDL_RenderDebugText(sdlRenderer, 4, 4, text)
        SDL_SetRenderScale(sdlRenderer, 1, 1)
    }
}

/// The system's pointers, made when first shown.
@MainActor
enum SystemCursors {

    private static var cursors: [HostCursor: OpaquePointer] = [:]

    static func cursor(for kind: HostCursor) -> OpaquePointer? {
        if let cursor = cursors[kind] {
            return cursor
        }
        let id: SDL_SystemCursor = switch kind {
        case .default: SDL_SYSTEM_CURSOR_DEFAULT
        case .text: SDL_SYSTEM_CURSOR_TEXT
        case .pointer: SDL_SYSTEM_CURSOR_POINTER
        case .move: SDL_SYSTEM_CURSOR_MOVE
        case .crosshair: SDL_SYSTEM_CURSOR_CROSSHAIR
        case .horizontalResize: SDL_SYSTEM_CURSOR_EW_RESIZE
        case .verticalResize: SDL_SYSTEM_CURSOR_NS_RESIZE
        case .diagonalResize: SDL_SYSTEM_CURSOR_NWSE_RESIZE
        case .antidiagonalResize: SDL_SYSTEM_CURSOR_NESW_RESIZE
        }
        let cursor = SDL_CreateSystemCursor(id)
        cursors[kind] = cursor
        return cursor
    }
}
