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
#if os(macOS)
import AppKit
#endif

/// One window: its view graph, compositor and input.
@MainActor
final class WindowHost {

    let window: OpaquePointer

    let renderer: OpaquePointer

    let id: SDL_WindowID

    let graph: ViewGraph

    /// Whether the window has keyboard focus.
    var isKey: Bool {
        SDL_GetKeyboardFocus() == window
    }

    let compositor: Compositor

    private let backend: SDLBackend

    private let scrollController = ScrollController()

    /// Where the mouse is, for pinches.
    private var mouseLocation = CGPoint(x: 0, y: 0)

    /// The color scheme the views last preferred.
    private var lastPreferredColorScheme: ColorScheme?

    /// A pinch's total scale since it began.
    private var pinchScale = 1.0

    /// The rotation so far of a trackpad pinch the system reports, in
    /// radians, clockwise.
    private var systemRotationAngle = 0.0

    /// Delivers a change to a trackpad rotation from the system, which
    /// reports each change; gestures see the total, in radians.
    func systemRotation(_ phase: PointerPhase, clockwiseDegrees delta: Double, at location: CGPoint? = nil) {
        if phase == .began {
            systemRotationAngle = 0
        }
        systemRotationAngle += delta * .pi / 180
        graph.rotate(phase, angle: systemRotationAngle, at: location ?? mouseLocation, time: SDLHost.now)
        needsRender = true
    }

    /// The window's Wayland surface, when SDL uses Wayland.
    var waylandSurface: UnsafeMutableRawPointer? {
        SDL_GetPointerProperty(SDL_GetWindowProperties(window), SDL_PROP_WINDOW_WAYLAND_SURFACE_POINTER, nil)
    }

    /// Two-finger rotations on touch screens.
    private var touchRotation = TouchRotationTracker()

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

    /// The scene the window shows, if it has an identifier.
    let sceneID: String?

    /// The title the window's content asked for, last shown.
    private var shownTitle: String?

    /// The pointer style last shown.
    private var shownPointerStyle: PointerStyle?

    init?(description: WindowDescription, value: AnyHashable? = nil, textEngine: SilicaTextEngine) {
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
        self.sceneID = description.id
        self.backend = SDLBackend(renderer: renderer)
        self.compositor = Compositor(backend: backend, textEngine: textEngine)
        var environment = EnvironmentValues()
        environment.openURL = OpenURLAction { url in
            _ = SDL_OpenURL(url.absoluteString)
        }
        environment.displayScale = CGFloat(SDL_GetWindowPixelDensity(window))
        environment.colorScheme = SDL_GetSystemTheme() == SDL_SYSTEM_THEME_DARK ? .dark : .light
        let windowID = self.id
        environment.openWindow = OpenWindowAction { id, value in
            SDLHost.windowRequests.append(.open(id: id, value: value))
        }
        environment.dismissWindow = DismissWindowAction { id in
            SDLHost.windowRequests.append(id.map { .closeScene($0) } ?? .close(windowID))
        }
        let rootView = description.makeRootView?(value) ?? description.rootView
        self.graph = ViewGraph(rootView: rootView, environment: environment, textEngine: textEngine)
        updateBackground()
        graph.onNeedsDisplay = { [weak self] in
            self?.needsRender = true
        }
        graph.clipboard = Clipboard(
            read: {
                guard SDL_HasClipboardText(), let text = SDL_GetClipboardText() else { return nil }
                defer { SDL_free(text) }
                return String(cString: text)
            },
            write: { _ = SDL_SetClipboardText($0) }
        )
        graph.fileDialogs = SDLFileDialogs.dialogs(for: window)
        #if os(macOS)
        installRotationMonitor()
        graph.share = { [weak self] request in
            self?.showSharePicker(request) ?? false
        }
        #endif
    }

    /// Brings the window to the front.
    func raise() {
        SDL_RaiseWindow(window)
    }

    func close() {
        #if os(macOS)
        if let rotationMonitor {
            NSEvent.removeMonitor(rotationMonitor)
        }
        #endif
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
        scrollController.isAnimating || graph.hasActiveAnimations
    }

    private func updateBackground() {
        compositor.backgroundColor = graph.environment.colorScheme == .dark
            ? Color.Resolved(red: 0, green: 0, blue: 0)
            : Color.Resolved(red: 1, green: 1, blue: 1)
    }

    // MARK: Events

    /// Files and text dropped from the system so far, in one drop.
    private var droppedItems: [Any] = []

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
            graph.pointer(.began, at: CGPoint(x: CGFloat(event.button.x), y: CGFloat(event.button.y)), time: now)
        case SDL_EVENT_MOUSE_BUTTON_DOWN where event.button.button == UInt8(SDL_BUTTON_RIGHT):
            graph.secondaryClick(at: CGPoint(x: CGFloat(event.button.x), y: CGFloat(event.button.y)))
        case SDL_EVENT_MOUSE_BUTTON_UP where event.button.button == UInt8(SDL_BUTTON_LEFT):
            graph.pointer(.ended, at: CGPoint(x: CGFloat(event.button.x), y: CGFloat(event.button.y)), time: now)
        case SDL_EVENT_MOUSE_MOTION:
            mouseLocation = CGPoint(x: CGFloat(event.motion.x), y: CGFloat(event.motion.y))
            if event.motion.state & 0x1 != 0 {
                graph.pointer(.moved, at: mouseLocation, time: now)
            } else {
                graph.hover(at: mouseLocation)
            }
        case SDL_EVENT_WINDOW_MOUSE_LEAVE:
            graph.hover(at: nil)
        case SDL_EVENT_PINCH_BEGIN:
            // SDL reports each change; gestures see the total.
            pinchScale = 1
            graph.magnify(.began, scale: pinchScale, at: mouseLocation, time: now)
        case SDL_EVENT_PINCH_UPDATE:
            pinchScale *= Double(event.pinch.scale)
            graph.magnify(.moved, scale: pinchScale, at: mouseLocation, time: now)
        case SDL_EVENT_PINCH_END:
            graph.magnify(.ended, scale: pinchScale, at: mouseLocation, time: now)
        case SDL_EVENT_FINGER_DOWN, SDL_EVENT_FINGER_MOTION, SDL_EVENT_FINGER_UP, SDL_EVENT_FINGER_CANCELED:
            // Touch screens only: trackpads' rotations come from the system.
            guard SDL_GetTouchDeviceType(event.tfinger.touchID) == SDL_TOUCH_DEVICE_DIRECT else { break }
            let size = size
            let location = CGPoint(x: CGFloat(event.tfinger.x) * size.width, y: CGFloat(event.tfinger.y) * size.height)
            let finger = UInt64(event.tfinger.fingerID)
            let update: TouchRotationTracker.Update? = switch SDL_EventType(event.type) {
            case SDL_EVENT_FINGER_DOWN: touchRotation.fingerDown(finger, at: location)
            case SDL_EVENT_FINGER_MOTION: touchRotation.fingerMoved(finger, to: location)
            default: touchRotation.fingerUp(finger, cancelled: event.type == SDL_EVENT_FINGER_CANCELED.rawValue)
            }
            if let update {
                graph.rotate(update.phase, angle: update.angle, at: update.location, time: now)
            }
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
        case SDL_EVENT_KEY_DOWN:
            if let key = Self.keyCode(event.key.key, modifiers: event.key.mod) {
                graph.keyDown(key, modifiers: Self.modifiers(event.key.mod))
            }
        case SDL_EVENT_DROP_BEGIN:
            droppedItems = []
        case SDL_EVENT_DROP_POSITION:
            graph.systemDrop(.moved, items: droppedItems, at: CGPoint(x: CGFloat(event.drop.x), y: CGFloat(event.drop.y)))
        case SDL_EVENT_DROP_FILE:
            if let data = event.drop.data {
                droppedItems.append(URL(fileURLWithPath: String(cString: data)))
            }
        case SDL_EVENT_DROP_TEXT:
            if let data = event.drop.data {
                droppedItems.append(String(cString: data))
            }
        case SDL_EVENT_DROP_COMPLETE:
            graph.systemDrop(.dropped, items: droppedItems, at: CGPoint(x: CGFloat(event.drop.x), y: CGFloat(event.drop.y)))
            droppedItems = []
            needsRender = true
        case SDL_EVENT_TEXT_INPUT:
            if let text = event.text.text {
                graph.insertText(String(cString: text))
            }
        default:
            break
        }
    }

    // MARK: Keyboard

    private static func modifiers(_ mod: SDL_Keymod) -> KeyModifiers {
        var modifiers: KeyModifiers = []
        if mod & 0x0003 != 0 { modifiers.insert(.shift) }
        if mod & 0x00C0 != 0 { modifiers.insert(.control) }
        if mod & 0x0300 != 0 { modifiers.insert(.option) }
        if mod & 0x0C00 != 0 { modifiers.insert(.command) }
        return modifiers
    }

    /// The key for an SDL key code. Characters only count with the control
    /// or command key held; typing arrives as text input.
    private static func keyCode(_ key: SDL_Keycode, modifiers mod: SDL_Keymod) -> KeyCode? {
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

    /// Starts or stops text input (and an input method) as focus moves in
    /// and out of text fields.
    private func updateTextInput() {
        let wantsText = graph.acceptsTextInput
        if wantsText != isTextInputActive {
            isTextInputActive = wantsText
            if wantsText {
                SDL_StartTextInput(window)
            } else {
                SDL_StopTextInput(window)
            }
        }
        if wantsText, let frame = graph.focusedFrame {
            var area = SDL_Rect(
                x: Int32(frame.minX), y: Int32(frame.minY),
                w: Int32(frame.width), h: Int32(frame.height)
            )
            SDL_SetTextInputArea(window, &area, 0)
        }
    }

    private var isTextInputActive = false

    func systemThemeChanged() {
        let system: ColorScheme = SDL_GetSystemTheme() == SDL_SYSTEM_THEME_DARK ? .dark : .light
        // Views may prefer a scheme over the system's.
        let colorScheme = graph.preferredColorScheme ?? system
        if graph.environment.colorScheme != colorScheme {
            graph.environment.colorScheme = colorScheme
            updateBackground()
        }
    }

    // MARK: Accessibility

    #if os(macOS)
    /// Watches for trackpad rotations, which SDL doesn't report.
    private var rotationMonitor: Any?

    /// Delivers the window's trackpad rotations to its gestures. AppKit
    /// reports each change, counterclockwise in degrees.
    private func installRotationMonitor() {
        rotationMonitor = NSEvent.addLocalMonitorForEvents(matching: .rotate) { [weak self] event in
            MainActor.assumeIsolated {
                guard let self, let view = self.contentView, event.window === view.window else { return }
                let point = view.convert(event.locationInWindow, from: nil)
                let location = CGPoint(x: point.x, y: view.isFlipped ? point.y : view.bounds.height - point.y)
                let phase: PointerPhase? = switch event.phase {
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

    /// The share picker shown, kept while it's open.
    private var sharePicker: NSSharingServicePicker?

    /// The window's AppKit content view.
    private var contentView: NSView? {
        let properties = SDL_GetWindowProperties(window)
        guard let pointer = SDL_GetPointerProperty(properties, SDL_PROP_WINDOW_COCOA_WINDOW_POINTER, nil) else { return nil }
        return Unmanaged<NSWindow>.fromOpaque(pointer).takeUnretainedValue().contentView
    }

    /// Shows the system's share picker below a share link.
    private func showSharePicker(_ request: ShareRequest) -> Bool {
        guard let view = contentView, !request.items.isEmpty else { return false }
        let anchor = request.anchor
        let rect = view.isFlipped
            ? anchor
            : CGRect(x: anchor.minX, y: view.bounds.height - anchor.maxY, width: anchor.width, height: anchor.height)
        let picker = NSSharingServicePicker(items: request.items)
        sharePicker = picker
        picker.show(relativeTo: rect, of: view, preferredEdge: .minY)
        return true
    }

    /// The window's elements for VoiceOver, made when first needed.
    private var accessibility: AccessibilityBridge?

    private var lastAccessibilityUpdate: Double = -1

    /// Shows the accessibility tree to macOS, at most four times a second.
    private func updateAccessibility(now: Double) {
        guard now - lastAccessibilityUpdate >= 0.25 else { return }
        lastAccessibilityUpdate = now
        if accessibility == nil {
            guard let view = contentView else { return }
            let graph = self.graph
            accessibility = AccessibilityBridge(view: view) { [weak self] name, frame in
                let performed = graph.performAccessibilityAction(name, at: frame)
                self?.needsRender = true
                return performed
            }
        }
        accessibility?.update(graph.accessibilityTree())
    }
    #endif

    // MARK: Frames

    /// Steps animations, updates, lays out and draws if anything changed.
    func frame(now: Double) {
        scrollController.step(now: now)
        // Moves animations to this frame; animatable views re-resolve.
        graph.advanceAnimations(to: now)
        if graph.needsUpdate {
            graph.update()
            needsLayout = true
            if graph.preferredColorScheme != lastPreferredColorScheme {
                lastPreferredColorScheme = graph.preferredColorScheme
                systemThemeChanged()
            }
        }
        if graph.windowTitle != shownTitle, let title = graph.windowTitle {
            shownTitle = title
            SDL_SetWindowTitle(window, title)
        }
        if graph.pointerStyle != shownPointerStyle {
            shownPointerStyle = graph.pointerStyle
            SDL_SetCursor(SystemCursors.cursor(for: graph.pointerStyle?.kind ?? .default))
        }
        updateTextInput()
        let size = size
        updateSafeArea(size: size)
        if needsLayout || graph.size != size {
            graph.layout(in: size)
            needsLayout = false
            needsRender = true
        }
        // Layout can invalidate views, as when lazy stacks need rows that
        // came into view: settle them before drawing.
        var passes = 0
        while graph.needsUpdate, passes < 4 {
            graph.layout(in: size)
            passes += 1
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
        #if os(macOS)
        updateAccessibility(now: start)
        #endif
        if showsStatistics {
            drawStatistics(renderTime: SDLHost.now - start, now: now)
        }
        if let path = screenshotPath {
            screenshotPath = nil
            saveScreenshot(to: path)
        }
        SDL_RenderPresent(renderer)
    }

    /// Keeps content out of the parts of the window the system covers.
    private func updateSafeArea(size: CGSize) {
        var rect = SDL_Rect()
        guard SDL_GetWindowSafeArea(window, &rect), rect.w > 0, rect.h > 0 else { return }
        let insets = EdgeInsets(
            top: CGFloat(rect.y),
            leading: CGFloat(rect.x),
            bottom: max(size.height - CGFloat(rect.y + rect.h), 0),
            trailing: max(size.width - CGFloat(rect.x + rect.w), 0)
        )
        if insets != graph.safeAreaInsets {
            graph.safeAreaInsets = insets
            needsLayout = true
        }
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

/// The system's pointers, made when first shown.
@MainActor
enum SystemCursors {

    private static var cursors: [PointerStyle.Kind: OpaquePointer] = [:]

    static func cursor(for kind: PointerStyle.Kind) -> OpaquePointer? {
        if let cursor = cursors[kind] {
            return cursor
        }
        let id: SDL_SystemCursor = switch kind {
        case .default, .zoomIn, .zoomOut: SDL_SYSTEM_CURSOR_DEFAULT
        case .text: SDL_SYSTEM_CURSOR_TEXT
        case .link, .grab: SDL_SYSTEM_CURSOR_POINTER
        case .grabbing, .move: SDL_SYSTEM_CURSOR_MOVE
        case .crosshair: SDL_SYSTEM_CURSOR_CROSSHAIR
        case .columnResize: SDL_SYSTEM_CURSOR_EW_RESIZE
        case .rowResize: SDL_SYSTEM_CURSOR_NS_RESIZE
        case .diagonalResize: SDL_SYSTEM_CURSOR_NWSE_RESIZE
        case .antidiagonalResize: SDL_SYSTEM_CURSOR_NESW_RESIZE
        }
        let cursor = SDL_CreateSystemCursor(id)
        cursors[kind] = cursor
        return cursor
    }
}
