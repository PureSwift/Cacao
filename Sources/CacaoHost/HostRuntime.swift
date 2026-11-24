//
//  HostRuntime.swift
//  CacaoHost
//
//  Created by Alsey Coleman Miller on 11/19/26.
//

import Foundation
#if canImport(CoreGraphics)
import CoreGraphics
#endif
import CacaoRender
import CacaoCompositor
import SDL3Swift

/// The SDL3 host: windows, the main loop and frame clock, and input.
///
/// A client opens windows, each showing a `HostScene`, and runs the loop.
/// The host knows nothing of what the scenes are made with.
@MainActor
public enum HostRuntime {

    /// The version of the SDL library loaded at run time, as `major.minor.micro`.
    public nonisolated static var sdlVersion: String {
        SDL.version.description
    }

    /// Seconds since SDL started, from its high resolution clock.
    public static var now: Double {
        Double(SDL.ticks) / 1_000_000_000
    }

    /// Whether the system shows light or dark windows: on Linux what the
    /// desktop's settings portal says, else what SDL reports, or what the
    /// desktop's settings say when SDL can't tell.
    public static var systemAppearance: HostAppearance {
        DesktopAppearance.current
    }

    /// The color the system tints controls with, if it says: on Linux the
    /// settings portal's accent color.
    public static var systemAccentColor: ResolvedColor? {
        DesktopAppearance.accentColor
    }

    /// Whether the system asks for higher contrast: on Linux the settings
    /// portal's contrast.
    public static var prefersIncreasedContrast: Bool {
        DesktopAppearance.prefersIncreasedContrast
    }

    /// The window buttons the system asks title bars drawn by apps to show,
    /// in the format of GNOME's `button-layout` setting, such as
    /// `close,minimize,maximize:`: on Linux what the settings portal says.
    /// `nil` when the system doesn't say.
    public static var windowButtonLayout: String? {
        DesktopAppearance.windowButtonLayout
    }

    /// Tells every window's scene the system's appearance changed.
    static func systemAppearanceChanged() {
        let appearance = systemAppearance
        let now = now
        windows.forEach { $0.scene?.handle(.appearanceChanged(appearance), time: now) }
    }

    // MARK: Options

    /// The SDL renderer windows draw with, such as `opengles2`, or `nil`
    /// for SDL's choice. Defaults to the `CACAO_RENDERER` environment
    /// variable.
    public static var rendererName: String? = ProcessInfo.processInfo.environment["CACAO_RENDERER"]

    /// The app's identifier, such as `com.example.Notes`: the Wayland
    /// `app_id` and X11 window class of the windows opened after it's set,
    /// which docks match to desktop entries. Defaults to the main bundle's
    /// identifier; with none, SDL uses the executable's name.
    public static var appIdentifier: String? = Bundle.main.bundleIdentifier

    /// The identifier SDL was last given.
    private static var appliedAppIdentifier: String?

    /// Gives SDL the app's identifier, for windows about to be made.
    static func applyAppIdentifier() {
        guard appIdentifier != appliedAppIdentifier else { return }
        do {
            try SDL.setAppMetadataProperty("SDL.app.metadata.identifier", appIdentifier)
            appliedAppIdentifier = appIdentifier
        } catch {
            print("Cacao: the app identifier wasn't set: \(error)")
        }
    }

    // MARK: Video

    /// Initializes SDL's video subsystem, runs `body`, then shuts SDL down.
    public static func withVideo<T>(_ body: () throws -> T) throws -> T {
        do {
            try SDL.initialize(subSystems: [.video])
        } catch {
            throw HostError(message: error.errorMessage)
        }
        defer { SDL.quit() }
        return try body()
    }

    /// The text engine windows measure and draw with, while the host runs.
    package private(set) static var textEngine: SilicaTextEngine?

    // MARK: Windows

    /// The open windows.
    public private(set) static var windows: [HostWindow] = []

    /// The window with keyboard focus.
    public static var keyWindow: HostWindow? {
        windows.first(where: \.isKey)
    }

    /// Opens a window showing the scene `makeScene` returns for it: among
    /// the other windows, or in a layer of the screen if `layer` is given
    /// and the system has layers. With `decorations` of `.none`, the
    /// window has no title bar or borders of its own: the scene draws
    /// them, and says where the window moves from.
    @discardableResult
    public static func openWindow(
        title: String,
        size: CGSize,
        layer: HostLayerSurface? = nil,
        decorations: HostWindowDecorations = .system,
        makeScene: (HostWindow) -> any HostScene
    ) -> HostWindow? {
        guard let textEngine,
              let window = HostWindow(title: title, size: size, textEngine: textEngine, layer: layer, decorations: decorations) else {
            return nil
        }
        window.scene = makeScene(window)
        windows.append(window)
        return window
    }

    /// Draws a scene in a window that never shows, and saves the drawing
    /// as a PNG. Returns whether it was saved.
    public static func snapshot(
        size: CGSize,
        to path: String,
        makeScene: (HostWindow) -> any HostScene
    ) -> Bool {
        guard let textEngine,
              let window = HostWindow(title: "", size: size, textEngine: textEngine, isHidden: true) else {
            return false
        }
        window.scene = makeScene(window)
        defer { window.close() }
        return window.snapshot(to: path, now: now)
    }

    /// Closes a window.
    public static func close(_ window: HostWindow) {
        guard let index = windows.firstIndex(where: { $0 === window }) else { return }
        windows.remove(at: index)
        window.close()
    }

    // MARK: Loop

    /// Whether the loop keeps running with no windows open, as for an app
    /// that lives in the menu bar.
    public static var runsWithoutWindows: @MainActor () -> Bool = { false }

    private static var wakeHooks: [@MainActor () -> Void] = []

    /// Adds work to run each time the loop wakes, after events and before
    /// frames: where clients pump their own queues and run loops.
    public static func addWakeHook(_ hook: @escaping @MainActor () -> Void) {
        wakeHooks.append(hook)
    }

    nonisolated(unsafe) private static var wakeEvent: UInt32 = 0

    /// Wakes the loop from any thread, so wake hooks run without waiting
    /// for input.
    public nonisolated static func wake() {
        guard wakeEvent != 0 else { return }
        SDL.pushUserEvent(type: wakeEvent)
    }

    /// Runs an app's entry point as the platform needs it run. On iOS the
    /// system's app launch comes first, which SDL does, calling `body` once
    /// the app is up; everywhere else `body` just runs.
    public static func runApp(_ body: @escaping @MainActor () -> Void) {
        #if os(iOS) || os(tvOS) || os(visionOS)
        appMain = body
        _ = SDL_RunApp(CommandLine.argc, CommandLine.unsafeArgv, { _, _ in
            MainActor.assumeIsolated {
                HostRuntime.appMain?()
            }
            return 0
        }, nil)
        #else
        body()
        #endif
    }

    #if os(iOS) || os(tvOS) || os(visionOS)
    /// The app's entry point, for SDL to call after launch.
    private static var appMain: (@MainActor () -> Void)?
    #endif

    /// Starts SDL, runs `setup` (which opens the first windows), then runs
    /// the loop until the last window closes.
    public static func run(_ setup: () -> Void) {
        // Deliver macOS's own trackpad momentum as wheel events.
        _ = SDL.setHint("SDL_MAC_SCROLL_MOMENTUM", "1")
        do {
            try withVideo {
                // Asked while the app sets up, for the first window.
                DesktopAppearance.start()
                textEngine = SilicaTextEngine()
                wakeEvent = SDL.registerEvents() ?? 0
                defer {
                    wakeEvent = 0
                    wakeHooks = []
                    textEngine = nil
                    appliedAppIdentifier = nil
                }
                #if os(Linux)
                // Bound when a window first asks, and let go of after the
                // windows close.
                defer {
                    WaylandLayerShell.stop()
                    WaylandAppMenu.stop()
                }
                #endif
                setup()
                guard !windows.isEmpty || runsWithoutWindows() else {
                    print("Cacao: no windows to show: \(SDLError.current()?.errorMessage ?? "none were opened")")
                    return
                }
                #if os(Linux)
                WaylandGestures.start()
                defer { WaylandGestures.stop() }
                #endif
                runLoop()
                let remaining = windows
                windows = []
                remaining.forEach { $0.close() }
            }
        } catch {
            print("Cacao: \(error)")
        }
    }

    /// Whether the app asked to quit, which ends the loop when it next
    /// goes around.
    private static var quitRequested = false

    /// Quits the app: the loop ends, and the windows close.
    public static func quit() {
        quitRequested = true
        wake()
    }

    /// Waits for events while idle, and runs a frame per display refresh
    /// while anything animates; frames wait for vsync when presented.
    private static func runLoop() {
        quitRequested = false
        defer { quitRequested = false }
        while (!windows.isEmpty || runsWithoutWindows()) && !quitRequested {
            let animating = windows.contains { $0.isAnimating }
            // Idle: sleep until an event, waking periodically to run main
            // actor work (tasks, timers) scheduled outside of SDL.
            var next = animating ? SDL.pollEvent() : SDL.waitEvent(timeout: 16)
            while let event = next {
                if !handle(event) {
                    return
                }
                next = SDL.pollEvent()
            }
            #if os(Linux)
            WaylandGestures.dispatch()
            WaylandLayerShell.dispatch()
            // Windows in a layer the compositor took away.
            for window in windows where window.isLayerClosed {
                close(window)
            }
            #endif
            drainMainQueue()
            for hook in wakeHooks {
                hook()
            }
            let now = now
            for window in windows {
                window.frame(now: now)
            }
            if windows.contains(where: \.didSaveScreenshot) {
                return
            }
        }
    }

    /// Returns false to quit.
    private static func handle(_ event: SDLEvent) -> Bool {
        let now = now
        switch event {
        case .quit:
            return false
        case let .window(windowID, .closeRequested):
            if let window = windows.first(where: { $0.id == windowID }) {
                close(window)
            }
            return !windows.isEmpty || runsWithoutWindows()
        case .systemThemeChanged:
            systemAppearanceChanged()
        case .user:
            // A wake: the loop goes around, running its hooks.
            break
        default:
            if let windowID = event.windowID, let window = windows.first(where: { $0.id == windowID }) {
                window.handle(event, now: now)
            }
        }
        return true
    }

    /// Runs work scheduled on the main actor, such as tasks and timers.
    private static func drainMainQueue() {
        _ = RunLoop.main.run(mode: .default, before: Date())
    }

    // MARK: Clipboard

    /// The text on the system's clipboard.
    public static var clipboardText: String? {
        get {
            SDL.hasClipboardText ? SDL.clipboardText : nil
        }
        set {
            SDL.clipboardText = newValue ?? ""
        }
    }

    /// Opens a URL with the system's handler for it.
    public static func open(_ url: URL) {
        try? SDL.open(url: url.absoluteString)
    }
}

/// An error starting SDL.
public struct HostError: Error, CustomStringConvertible {

    public let message: String

    public var description: String {
        "SDL: \(message)"
    }
}

#if os(iOS) || os(tvOS) || os(visionOS)
/// `SDL_RunApp`, from SDL's main header, which SDL's own header doesn't
/// include.
@_silgen_name("SDL_RunApp")
private func SDL_RunApp(
    _ argc: Int32,
    _ argv: UnsafeMutablePointer<UnsafeMutablePointer<CChar>?>?,
    _ mainFunction: @convention(c) (Int32, UnsafeMutablePointer<UnsafeMutablePointer<CChar>?>?) -> Int32,
    _ reserved: UnsafeMutableRawPointer?
) -> Int32
#endif
