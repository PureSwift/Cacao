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
import CacaoSDLRenderer
import SDL3Swift
internal import CSDL3
#if os(macOS)
import AppKit
#endif
#if os(iOS)
import UIKit
#endif

/// One window: its SDL window and renderer, its compositor, and the scene
/// it shows and sends input to.
@MainActor
public final class HostWindow {

    /// SDL's window.
    public let window: SDLWindow

    /// SDL's renderer for the window.
    public let renderer: SDLRenderer

    /// The `SDL_Window`, for what SDL3Swift doesn't wrap.
    public var sdlWindow: OpaquePointer { window.unsafePointer }

    /// The `SDL_Renderer`, for what SDL3Swift doesn't wrap.
    public var sdlRenderer: OpaquePointer { renderer.unsafePointer }

    /// The `SDL_WindowID`.
    public let id: UInt32

    /// What the window shows.
    public internal(set) var scene: (any HostScene)?

    /// Who draws the window's title bar and borders.
    public let decorations: HostWindowDecorations

    /// Font measurement for this window's scene, available inside `makeScene`.
    /// Uses the same engine as the window's compositor, including popups and snapshots.
    public let textMeasurement: any TextMeasurementService

    package let compositor: Compositor

    private let backend: SDLBackend

    /// Whether the window has keyboard focus, itself or through one of its
    /// popups.
    public var isKey: Bool {
        window.hasKeyboardFocus || HostRuntime.popups.contains { $0.parentWindow === self && $0.isKey }
    }

    // MARK: Popups

    /// The window a popup belongs to; `nil` for a window.
    public private(set) weak var parentWindow: HostWindow?

    /// Where the popup was asked to go; `nil` for a window.
    public private(set) var popupPlacement: HostPopupPlacement?

    /// Whether this is a popup: a menu or popover of another window.
    public var isPopup: Bool {
        popupPlacement != nil
    }

    /// Where the system put the popup in its parent: the rectangle inside
    /// its margins, which it may have moved or made shorter to keep it on
    /// the screen.
    public var popupFrame: CGRect? {
        #if os(Linux)
        if let waylandPopup, waylandPopup.frame.width > 0 {
            return waylandPopup.frame
        }
        #endif
        return popupPlacement?.frame
    }

    /// Called when the system dismisses the popup, as when the user clicks
    /// outside the app. Close it then.
    public var onPopupDismissed: (() -> Void)?

    #if os(Linux)
    /// The window's surface as a popup, if it's one on Wayland.
    private(set) var waylandPopup: WaylandPopup?

    /// The window's surface in a layer, for its popups.
    var waylandLayerSurface: WaylandLayerSurface? {
        layerSurface
    }
    #endif

    /// Where the mouse is, for pinches.
    private var mouseLocation = CGPoint(x: 0, y: 0)

    /// A pinch's total scale since it began.
    private var pinchScale = 1.0

    /// Where each finger on a touch screen is.
    private var fingers: [UInt64: CGPoint] = [:]

    /// Where a pinch is: between the fingers on a touch screen, or at the
    /// mouse for a trackpad's.
    private var pinchLocation: CGPoint {
        guard fingers.count >= 2 else { return mouseLocation }
        let sum = fingers.values.reduce(CGPoint(x: 0, y: 0)) { CGPoint(x: $0.x + $1.x, y: $0.y + $1.y) }
        return CGPoint(x: sum.x / CGFloat(fingers.count), y: sum.y / CGFloat(fingers.count))
    }

    /// The rotation so far of a trackpad pinch the system reports, in
    /// radians, clockwise.
    private var systemRotationAngle = 0.0

    /// Whether the next frame must be drawn.
    private var needsRender = true

    /// Whether to draw frame times and compositor counts.
    public var showsStatistics = ProcessInfo.processInfo.environment["CACAO_SHOW_STATISTICS"] == "1"

    /// When each frame of the last second was drawn, for the frame rate.
    private var frameTimes: [Double] = []

    /// What the scene last asked of the window.
    private var shown = HostWindowState()

    private var shownCursor: HostCursor?

    private var isTextInputActive = false

    #if os(Linux)
    /// The window's surface in a layer of the screen, if it's in one.
    private var layerSurface: WaylandLayerSurface?

    /// The window's tie to the app's menu, through the compositor.
    private var windowMenu: WaylandWindowMenu?
    #endif

    /// Whether the window is tied to the app's menu: windows among the
    /// others are, and those in layers or never shown aren't.
    private let showsAppMenu: Bool

    /// Whether the window is in a layer of the screen, such as a panel or
    /// dock, rather than among the windows.
    public var isInLayer: Bool {
        #if os(Linux)
        layerSurface != nil
        #else
        false
        #endif
    }

    /// Whether the system took a window in a layer away, as when its screen
    /// went away.
    var isLayerClosed: Bool {
        #if os(Linux)
        layerSurface?.isClosed ?? false
        #else
        false
        #endif
    }

    init?(
        title: String,
        size: CGSize,
        textEngine: SilicaTextEngine,
        isHidden: Bool = false,
        layer: HostLayerSurface? = nil,
        decorations: HostWindowDecorations = .system
    ) {
        var driver = SDLRenderer.Driver.default
        if let name = HostRuntime.rendererName {
            guard let named = SDLRenderer.Driver(name: name) else {
                print("Cacao: SDL has no \(name) renderer")
                return nil
            }
            driver = named
        }
        HostRuntime.applyAppIdentifier()
        var made: SDLWindow?
        #if os(Linux)
        // A window in a layer, where the compositor has a layer shell; an
        // ordinary window otherwise.
        var surface: WaylandLayerSurface?
        if let layer, !isHidden, let layered = WaylandLayerShell.makeWindow(title: title, size: size, options: layer) {
            made = layered.window
            surface = layered.surface
        }
        #endif
        var isInLayer = false
        #if os(Linux)
        isInLayer = surface != nil
        #endif
        if made == nil {
            var options: BitMaskOptionSet<SDLWindow.Option> = isHidden ? [.hidden, .highPixelDensity] : [.resizable, .highPixelDensity]
            if decorations == .none, !isHidden {
                options.insert(.borderless)
            }
            made = try? SDLWindow(
                title: title,
                width: Int(size.width),
                height: Int(size.height),
                options: options
            )
        }
        guard let window = made, let renderer = try? SDLRenderer(window: window, driver: driver) else {
            #if os(Linux)
            surface?.destroy()
            #endif
            return nil
        }
        #if os(Linux)
        self.layerSurface = surface
        #endif
        try? renderer.setVSync(.every(1))
        // A window in a layer has no decorations, and isn't moved.
        self.decorations = isInLayer ? .system : decorations
        self.window = window
        self.renderer = renderer
        self.id = UInt32(window.id)
        self.backend = SDLBackend(renderer: renderer)
        self.textMeasurement = textEngine
        self.compositor = Compositor(backend: backend, textEngine: textEngine)
        self.showsAppMenu = !isInLayer && !isHidden
        #if os(macOS)
        installRotationMonitor()
        #endif
        // Scenes say where windows move from, decorated or not.
        if !isInLayer, !isHidden {
            installHitTest()
        }
        applyMenuAddress()
    }

    /// A popup of a window: on Wayland a surface with the popup role, else
    /// an SDL popup menu window. Returns nil where the window can't have
    /// popups of its own.
    init?(popupOf parent: HostWindow, placement: HostPopupPlacement, textEngine: SilicaTextEngine) {
        var driver = SDLRenderer.Driver.default
        if let name = HostRuntime.rendererName {
            guard let named = SDLRenderer.Driver(name: name) else { return nil }
            driver = named
        }
        let size = placement.surfaceSize
        var made: SDLWindow?
        #if os(Linux)
        var popup: WaylandPopup?
        if SDL.currentVideoDriver == "wayland" {
            guard let created = WaylandPopups.makeWindow(parent: parent, placement: placement) else { return nil }
            made = created.window
            popup = created.popup
        }
        #endif
        if made == nil {
            // SDL's popup menu, placed in the parent, without flipping.
            let frame = placement.frame
            made = try? SDLWindow { properties throws(SDLError) in
                try properties.setPointer("SDL.window.create.parent", UnsafeMutableRawPointer(parent.sdlWindow))
                try properties.setBoolean(placement.grabsInput ? "SDL.window.create.menu" : "SDL.window.create.tooltip", true)
                try properties.setNumber("SDL.window.create.x", Int64((frame.minX - placement.margins.left).rounded()))
                try properties.setNumber("SDL.window.create.y", Int64((frame.minY - placement.margins.top).rounded()))
                try properties.setNumber("SDL.window.create.width", Int64(max(size.width.rounded(.up), 1)))
                try properties.setNumber("SDL.window.create.height", Int64(max(size.height.rounded(.up), 1)))
                try properties.setBoolean("SDL.window.create.high_pixel_density", true)
                try properties.setBoolean("SDL.window.create.transparent", true)
                // Made for the renderer from the start: SDL would otherwise
                // hide it and make it again.
                if let api = HostWindow.renderingAPI {
                    try properties.setBoolean(api, true)
                }
            }
        }
        guard let window = made, let renderer = try? SDLRenderer(window: window, driver: driver) else {
            #if os(Linux)
            popup?.destroy()
            #endif
            return nil
        }
        #if os(Linux)
        self.waylandPopup = popup
        #endif
        try? renderer.setVSync(.every(1))
        self.decorations = .system
        self.window = window
        self.renderer = renderer
        self.id = UInt32(window.id)
        self.backend = SDLBackend(renderer: renderer)
        self.textMeasurement = textEngine
        self.compositor = Compositor(backend: backend, textEngine: textEngine)
        self.showsAppMenu = false
        self.parentWindow = parent
        self.popupPlacement = placement
        // Transparent around the popup, for its shadow.
        compositor.backgroundColor = ResolvedColor(red: 0, green: 0, blue: 0, opacity: 0)
        #if os(Linux)
        popup?.onDone = { [weak self] in
            self?.onPopupDismissed?()
        }
        #endif
    }

    /// The window flag the renderer needs, for windows made for it from
    /// the start.
    static var renderingAPI: String? {
        switch HostRuntime.rendererName {
        case "vulkan", "gpu":
            return "SDL.window.create.vulkan"
        case "software":
            return nil
        case "metal":
            return "SDL.window.create.metal"
        case nil:
            #if os(macOS) || os(iOS)
            return "SDL.window.create.metal"
            #else
            return "SDL.window.create.opengl"
            #endif
        default:
            return "SDL.window.create.opengl"
        }
    }

    /// Moves the popup next to a new anchor, or gives it a new size.
    public func movePopup(to placement: HostPopupPlacement) {
        guard popupPlacement != nil, placement != popupPlacement else { return }
        popupPlacement = placement
        let size = placement.surfaceSize
        #if os(Linux)
        if let waylandPopup {
            // The compositor places it, and gives it its size.
            if !waylandPopup.move(to: placement) {
                window.size = (Int(size.width.rounded(.up)), Int(size.height.rounded(.up)))
            }
            return
        }
        #endif
        window.size = (Int(size.width.rounded(.up)), Int(size.height.rounded(.up)))
        let frame = placement.frame
        try? window.setPosition(
            x: Int32((frame.minX - placement.margins.left).rounded()),
            y: Int32((frame.minY - placement.margins.top).rounded())
        )
    }

    /// Ties the window to the app's menu at `HostRuntime.menuAddress`, or
    /// unties it when there's none.
    func applyMenuAddress() {
        #if os(Linux)
        guard showsAppMenu else { return }
        guard let address = HostRuntime.menuAddress else {
            windowMenu?.destroy()
            windowMenu = nil
            return
        }
        if let windowMenu {
            windowMenu.setAddress(address)
        } else if let surface = waylandSurface {
            windowMenu = WaylandWindowMenu(surface: surface, address: address)
        }
        #endif
    }

    /// Brings the window to the front.
    public func raise() {
        window.raise()
    }

    /// Draws the scene again on the next frame.
    public func setNeedsDisplay() {
        needsRender = true
    }

    func close() {
        removeHitTest()
        scene?.detach()
        scene = nil
        #if os(macOS)
        if let rotationMonitor {
            NSEvent.removeMonitor(rotationMonitor)
        }
        #endif
        #if os(Linux)
        // The layer and popup roles and the menu go before SDL destroys the
        // surface.
        layerSurface?.destroy()
        waylandPopup?.destroy()
        waylandPopup = nil
        windowMenu?.destroy()
        windowMenu = nil
        #endif
        // The renderer and the window are destroyed with this object, which
        // the host has let go of.
        backend.destroyAllTextures()
        try? window.hide()
    }

    /// The window's size in points.
    public var size: CGSize {
        let size = window.size
        return CGSize(width: CGFloat(size.width), height: CGFloat(size.height))
    }

    /// Pixels per point.
    public var scale: CGFloat {
        CGFloat(window.pixelDensity)
    }

    /// The size of the screen the window is on, in points, less what the
    /// system keeps for itself where it says.
    public var screenSize: CGSize? {
        let display = SDL_GetDisplayForWindow(sdlWindow)
        var rect = SDL_Rect()
        guard display != 0, SDL_GetDisplayUsableBounds(display, &rect), rect.w > 0, rect.h > 0 else { return nil }
        return CGSize(width: CGFloat(rect.w), height: CGFloat(rect.h))
    }

    /// Whether the window needs frames even without events.
    var isAnimating: Bool {
        scene?.isAnimating ?? false
    }

    /// The window's Wayland surface, when SDL uses Wayland.
    var waylandSurface: UnsafeMutableRawPointer? {
        window.properties.pointer("SDL.window.wayland.surface")
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

    func handle(_ event: SDLEvent, now: Double) {
        guard let scene else { return }
        switch event {
        case .window(_, .resized), .window(_, .pixelSizeChanged), .window(_, .displayScaleChanged):
            scene.handle(.geometryChanged, time: now)
            needsRender = true
        case .window(_, .exposed):
            needsRender = true
        case .window(_, .focusGained), .window(_, .focusLost),
             .window(_, .maximized), .window(_, .minimized), .window(_, .restored):
            scene.handle(.windowStateChanged, time: now)
            needsRender = true
        case let .mouseButtonDown(_, which, button, _, x, y):
            guard let button = Self.button(button) else { break }
            // A drag belongs to the first button pressed.
            if pressedButton == nil {
                pressedButton = button
            }
            scene.handle(.pointer(.began, button: button, at: CGPoint(x: CGFloat(x), y: CGFloat(y)), isFromTouch: which == .touch), time: now)
        case let .mouseButtonUp(_, which, button, _, x, y):
            guard let button = Self.button(button) else { break }
            if pressedButton == button {
                pressedButton = nil
            }
            scene.handle(.pointer(.ended, button: button, at: CGPoint(x: CGFloat(x), y: CGFloat(y)), isFromTouch: which == .touch), time: now)
        case let .mouseMotion(_, which, buttons, x, y, _, _):
            mouseLocation = CGPoint(x: CGFloat(x), y: CGFloat(y))
            if let pressedButton, !buttons.isEmpty {
                scene.handle(.pointer(.moved, button: pressedButton, at: mouseLocation, isFromTouch: which == .touch), time: now)
            } else {
                pressedButton = nil
                scene.handle(.hover(at: mouseLocation), time: now)
            }
        case .window(_, .mouseLeave):
            scene.handle(.hover(at: nil), time: now)
        case let .pinch(_, phase, scale):
            // SDL reports each change; scenes see the total.
            switch phase {
            case .began:
                pinchScale = 1
                scene.handle(.magnify(.began, scale: pinchScale, at: pinchLocation), time: now)
            case .updated:
                pinchScale *= Double(scale)
                scene.handle(.magnify(.moved, scale: pinchScale, at: pinchLocation), time: now)
            case .ended:
                scene.handle(.magnify(.ended, scale: pinchScale, at: pinchLocation), time: now)
            }
        case let .fingerDown(_, touchID, fingerID, x, y):
            touch(.began, touchID: touchID, fingerID: fingerID, x: x, y: y, scene: scene, now: now)
        case let .fingerMotion(_, touchID, fingerID, x, y):
            touch(.moved, touchID: touchID, fingerID: fingerID, x: x, y: y, scene: scene, now: now)
        case let .fingerUp(_, touchID, fingerID, x, y):
            touch(.ended, touchID: touchID, fingerID: fingerID, x: x, y: y, scene: scene, now: now)
        case let .fingerCanceled(_, touchID, fingerID, x, y):
            touch(.cancelled, touchID: touchID, fingerID: fingerID, x: x, y: y, scene: scene, now: now)
        case let .mouseWheel(_, _, x, y, isFlipped, mouseX, mouseY):
            scene.handle(
                .scroll(x: isFlipped ? -x : x, y: isFlipped ? -y : y, at: CGPoint(x: CGFloat(mouseX), y: CGFloat(mouseY))),
                time: now
            )
        case let .keyDown(_, _, keycode, _, _) where keycode == .f12:
            showsStatistics.toggle()
            needsRender = true
        case let .keyDown(_, scancode, keycode, modifiers, isRepeat):
            key(isDown: true, scancode: scancode, keycode: keycode, modifiers: modifiers, isRepeat: isRepeat, scene: scene, now: now)
        case let .keyUp(_, scancode, keycode, modifiers, isRepeat):
            key(isDown: false, scancode: scancode, keycode: keycode, modifiers: modifiers, isRepeat: isRepeat, scene: scene, now: now)
        case let .drop(_, drop):
            switch drop {
            case .began:
                droppedItems = []
            case let .position(x, y):
                scene.handle(.drop(.moved, items: droppedItems, at: CGPoint(x: CGFloat(x), y: CGFloat(y))), time: now)
            case let .file(path, _, _):
                droppedItems.append(URL(fileURLWithPath: path))
            case let .text(text, _, _):
                droppedItems.append(text)
            case let .completed(x, y):
                scene.handle(.drop(.dropped, items: droppedItems, at: CGPoint(x: CGFloat(x), y: CGFloat(y))), time: now)
                droppedItems = []
                needsRender = true
            }
        case let .textInput(_, text):
            if !text.isEmpty {
                scene.handle(.text(text), time: now)
            }
        default:
            break
        }
    }

    /// A finger: on touch screens only, as trackpads' gestures come from
    /// the system. SDL places it as a fraction of the window.
    private func touch(_ phase: HostPhase, touchID: TouchID, fingerID: FingerID, x: Float, y: Float, scene: any HostScene, now: Double) {
        guard touchID.deviceType == .direct else { return }
        let size = size
        let location = CGPoint(x: CGFloat(x) * size.width, y: CGFloat(y) * size.height)
        switch phase {
        case .began, .moved: fingers[fingerID.rawValue] = location
        case .ended, .cancelled: fingers[fingerID.rawValue] = nil
        }
        scene.handle(.touch(phase, finger: fingerID.rawValue, at: location), time: now)
    }

    private func key(
        isDown: Bool, scancode: Scancode, keycode: Keycode, modifiers: KeyModifiers, isRepeat: Bool,
        scene: any HostScene, now: Double
    ) {
        scene.handle(.key(HostKeyEvent(
            isDown: isDown,
            isRepeat: isRepeat,
            usage: scancode.rawValue,
            keyCode: keycode.rawValue,
            modifiers: Self.modifiers(modifiers),
            key: Self.key(keycode, modifiers: modifiers)
        )), time: now)
    }

    /// The button a drag belongs to: the first pressed.
    private var pressedButton: HostPointerButton?

    private static func button(_ button: MouseButton) -> HostPointerButton? {
        switch button {
        case .left: .primary
        case .right: .secondary
        case .middle: .middle
        default: nil
        }
    }

    // MARK: Keyboard

    private static func modifiers(_ modifiers: KeyModifiers) -> HostKeyModifiers {
        var result: HostKeyModifiers = []
        if !modifiers.isDisjoint(with: .shift) { result.insert(.shift) }
        if !modifiers.isDisjoint(with: .control) { result.insert(.control) }
        if !modifiers.isDisjoint(with: .alt) { result.insert(.option) }
        if !modifiers.isDisjoint(with: .gui) { result.insert(.command) }
        return result
    }

    /// The key for an SDL key code. Characters only count with the control
    /// or command key held; typing arrives as text input.
    private static func key(_ key: Keycode, modifiers: KeyModifiers) -> HostKey? {
        switch key {
        case .left: return .left
        case .right: return .right
        case .up: return .up
        case .down: return .down
        case .home: return .home
        case .end: return .end
        case .pageUp: return .pageUp
        case .pageDown: return .pageDown
        case .backspace: return .backspace
        case .delete: return .delete
        case .return, .keypadEnter: return .returnKey
        case .escape: return .escape
        case .tab: return .tab
        default:
            guard !modifiers.isDisjoint(with: [.control, .gui]), key.rawValue < 0x80,
                  let scalar = Unicode.Scalar(key.rawValue) else {
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
            window.title = title
        }
        if state.cursor != shownCursor {
            shownCursor = state.cursor
            SDL.setCursor(SystemCursors.cursor(for: state.cursor))
        }
        if state.acceptsTextInput != isTextInputActive {
            isTextInputActive = state.acceptsTextInput
            if state.acceptsTextInput {
                try? window.startTextInput()
            } else {
                try? window.stopTextInput()
            }
        }
        if state.acceptsTextInput, let frame = state.textInputArea {
            try? window.setTextInputArea(SDLRect(
                x: Int32(frame.minX), y: Int32(frame.minY),
                width: Int32(frame.width), height: Int32(frame.height)
            ))
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
        guard let pointer = window.properties.pointer("SDL.window.cocoa.window") else { return nil }
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
        // A surface drawn outside the scene has a frame the scene doesn't
        // know of.
        if compositor.hasNewExternalFrames {
            needsRender = true
        }
        // A delayed screenshot is of the first frame after the delay, drawn
        // even if nothing changed by then.
        if screenshotPath != nil, now >= screenshotTime {
            needsRender = true
        }
        guard needsRender || showsStatistics && isAnimating else {
            return
        }
        needsRender = false
        let start = HostRuntime.now
        compositor.render(scene.displayList(), size: size, scale: scale)
        // Producers publish from their own threads: each frame wakes the
        // loop, which is otherwise waiting for input.
        for surface in compositor.externalSurfaces where surface.onPublish == nil {
            surface.onPublish = { HostRuntime.wake() }
        }
        scene.didRender(time: start)
        if showsStatistics {
            drawStatistics(renderTime: HostRuntime.now - start, now: now, scene: scene)
        }
        if let path = screenshotPath, now >= screenshotTime {
            screenshotPath = nil
            saveScreenshot(to: path)
        }
        renderer.present()
    }

    /// The parts of the window the system covers.
    private func safeArea(size: CGSize) -> HostInsets {
        guard let rect = try? window.safeArea(), rect.width > 0, rect.height > 0 else { return HostInsets() }
        return HostInsets(
            top: CGFloat(rect.y),
            left: CGFloat(rect.x),
            bottom: max(size.height - CGFloat(rect.y + rect.height), keyboardHeight, 0),
            right: max(size.width - CGFloat(rect.x + rect.width), 0)
        )
    }

    /// How much of the bottom of the window an on-screen keyboard covers.
    /// SDL says when one shows and hides but not how tall it is, so on iOS
    /// that comes from UIKit.
    private var keyboardHeight: CGFloat {
        #if os(iOS)
        guard let frame = ScreenKeyboard.shared.frame,
              let pointer = self.window.properties.pointer("SDL.window.uikit.window") else {
            return 0
        }
        let window = Unmanaged<UIWindow>.fromOpaque(pointer).takeUnretainedValue()
        let covered = window.convert(frame, from: nil).intersection(window.bounds)
        // A keyboard at the bottom, not one floating over the window.
        guard !covered.isNull, covered.maxY >= window.bounds.maxY - 1 else { return 0 }
        return covered.height
        #else
        return 0
        #endif
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

    /// Draws the scene as it is at a time, without showing it, and saves
    /// the drawing as a PNG. Returns whether it was saved.
    func snapshot(to path: String, now: Double) -> Bool {
        guard let scene else { return false }
        let size = size
        let scale = scale
        // A few frames, for what views learn from their first layouts.
        for pass in 0..<3 {
            _ = scene.update(HostFrame(time: now + Double(pass) / 60, size: size, scale: scale))
        }
        apply(scene.windowState)
        compositor.render(scene.displayList(), size: size, scale: scale)
        return writePNG(to: path, logs: false)
    }

    private func saveScreenshot(to path: String) {
        defer { didSaveScreenshot = true }
        writePNG(to: path, logs: true)
    }

    /// Saves what the renderer last drew as a PNG.
    @discardableResult
    private func writePNG(to path: String, logs: Bool) -> Bool {
        // Bytes in R, G, B, A order, as PNGs have them.
        let surface: SDLSurface
        do {
            surface = try renderer.readPixels().converted(to: .rgba32)
        } catch {
            print("Cacao: screenshot failed: \(error)")
            return false
        }
        let width = surface.width
        let height = surface.height
        let pitch = surface.pitch
        guard let pixels = try? surface.withUnsafeMutableBytes({ Data(bytes: $0, count: pitch * height) }) else {
            print("Cacao: screenshot failed: its pixels can't be read")
            return false
        }
        guard let png = Rasterizer.encodePNG(width: width, height: height, bytesPerRow: pitch, pixels: pixels) else {
            print("Cacao: screenshot encoding failed")
            return false
        }
        do {
            try png.write(to: URL(fileURLWithPath: path))
            if logs {
                print("Cacao: saved screenshot to \(path)")
            }
            return true
        } catch {
            print("Cacao: screenshot not saved: \(error)")
            return false
        }
    }

    private func drawStatistics(renderTime: Double, now: Double, scene: any HostScene) {
        // Frames drawn in the last second, however far apart: the loop
        // idles between frames when nothing but an external surface, or a
        // timer, changes what's shown.
        frameTimes.append(now)
        frameTimes.removeAll { now - $0 >= 1 }
        let fps = Double(frameTimes.count)
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
        try? renderer.setClipRect(nil)
        try? renderer.setDrawColorFloat(red: 0, green: 0, blue: 0, alpha: 0.7)
        try? renderer.fill(SDLFRect(x: 0, y: 0, width: Float(text.count * 8 + 8) * scale, height: 16 * scale))
        try? renderer.setScale(x: scale, y: scale)
        try? renderer.setDrawColorFloat(red: 1, green: 1, blue: 1, alpha: 1)
        try? renderer.debugText(text, x: 4, y: 4)
        try? renderer.setScale(x: 1, y: 1)
    }
}

/// The system's pointers, made when first shown.
@MainActor
enum SystemCursors {

    private static var cursors: [HostCursor: SDLCursor] = [:]

    static func cursor(for kind: HostCursor) -> SDLCursor? {
        if let cursor = cursors[kind] {
            return cursor
        }
        let system: SDLCursor.System = switch kind {
        case .default: .default
        case .text: .text
        case .pointer: .pointer
        case .move: .move
        case .crosshair: .crosshair
        case .horizontalResize: .eastWestResize
        case .verticalResize: .northSouthResize
        case .diagonalResize: .northwestSoutheastResize
        case .antidiagonalResize: .northeastSouthwestResize
        }
        let cursor = try? SDLCursor(system: system)
        cursors[kind] = cursor
        return cursor
    }
}
