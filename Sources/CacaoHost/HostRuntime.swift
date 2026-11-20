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
import CSDL3

/// The SDL3 host: windows, the main loop and frame clock, and input.
///
/// A client opens windows, each showing a `HostScene`, and runs the loop.
/// The host knows nothing of what the scenes are made with.
@MainActor
public enum HostRuntime {

    /// The version of the SDL library loaded at run time, as `major.minor.micro`.
    public nonisolated static var sdlVersion: String {
        let version = Int(SDL_GetVersion())
        return "\(version / 1_000_000).\(version / 1_000 % 1_000).\(version % 1_000)"
    }

    /// Seconds since SDL started, from its high resolution clock.
    public static var now: Double {
        Double(SDL_GetTicksNS()) / 1_000_000_000
    }

    /// Whether the system shows light or dark windows.
    public static var systemAppearance: HostAppearance {
        SDL_GetSystemTheme() == SDL_SYSTEM_THEME_DARK ? .dark : .light
    }

    // MARK: Options

    /// The SDL renderer windows draw with, such as `opengles2`, or `nil`
    /// for SDL's choice. Defaults to the `CACAO_RENDERER` environment
    /// variable.
    public static var rendererName: String? = ProcessInfo.processInfo.environment["CACAO_RENDERER"]

    // MARK: Video

    /// Initializes SDL's video subsystem, runs `body`, then shuts SDL down.
    public static func withVideo<T>(_ body: () throws -> T) throws -> T {
        guard SDL_Init(SDL_InitFlags(0x0000_0020)) else {
            throw HostError(message: String(cString: SDL_GetError()))
        }
        defer { SDL_Quit() }
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

    /// Opens a window showing the scene `makeScene` returns for it.
    @discardableResult
    public static func openWindow(
        title: String,
        size: CGSize,
        makeScene: (HostWindow) -> any HostScene
    ) -> HostWindow? {
        guard let textEngine, let window = HostWindow(title: title, size: size, textEngine: textEngine) else {
            return nil
        }
        window.scene = makeScene(window)
        windows.append(window)
        return window
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
        var event = SDL_Event()
        event.type = wakeEvent
        _ = SDL_PushEvent(&event)
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
        SDL_SetHint("SDL_MAC_SCROLL_MOMENTUM", "1")
        do {
            try withVideo {
                textEngine = SilicaTextEngine()
                wakeEvent = SDL_RegisterEvents(1)
                defer {
                    wakeEvent = 0
                    wakeHooks = []
                    textEngine = nil
                }
                setup()
                guard !windows.isEmpty || runsWithoutWindows() else {
                    print("Cacao: no windows to show: \(String(cString: SDL_GetError()))")
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

    /// Waits for events while idle, and runs a frame per display refresh
    /// while anything animates; frames wait for vsync when presented.
    private static func runLoop() {
        var event = SDL_Event()
        while !windows.isEmpty || runsWithoutWindows() {
            let animating = windows.contains { $0.isAnimating }
            // Idle: sleep until an event, waking periodically to run main
            // actor work (tasks, timers) scheduled outside of SDL.
            if animating ? SDL_PollEvent(&event) : SDL_WaitEventTimeout(&event, 16) {
                repeat {
                    if !handle(event) {
                        return
                    }
                } while SDL_PollEvent(&event)
            }
            #if os(Linux)
            WaylandGestures.dispatch()
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
    private static func handle(_ event: SDL_Event) -> Bool {
        let now = now
        switch SDL_EventType(event.type) {
        case SDL_EVENT_QUIT:
            return false
        case SDL_EVENT_WINDOW_CLOSE_REQUESTED:
            if let window = windows.first(where: { $0.id == event.window.windowID }) {
                close(window)
            }
            return !windows.isEmpty || runsWithoutWindows()
        case SDL_EVENT_SYSTEM_THEME_CHANGED:
            let appearance = systemAppearance
            windows.forEach { $0.scene?.handle(.appearanceChanged(appearance), time: now) }
        default:
            if let windowID = windowID(of: event), let window = windows.first(where: { $0.id == windowID }) {
                window.handle(event, now: now)
            }
        }
        return true
    }

    private static func windowID(of event: SDL_Event) -> SDL_WindowID? {
        switch SDL_EventType(event.type) {
        case SDL_EVENT_MOUSE_BUTTON_DOWN, SDL_EVENT_MOUSE_BUTTON_UP:
            event.button.windowID
        case SDL_EVENT_MOUSE_MOTION:
            event.motion.windowID
        case SDL_EVENT_MOUSE_WHEEL:
            event.wheel.windowID
        case SDL_EVENT_PINCH_BEGIN, SDL_EVENT_PINCH_UPDATE, SDL_EVENT_PINCH_END:
            event.pinch.windowID
        case SDL_EVENT_KEY_DOWN, SDL_EVENT_KEY_UP:
            event.key.windowID
        case SDL_EVENT_TEXT_INPUT:
            event.text.windowID
        case SDL_EVENT_DROP_BEGIN, SDL_EVENT_DROP_POSITION, SDL_EVENT_DROP_FILE, SDL_EVENT_DROP_TEXT, SDL_EVENT_DROP_COMPLETE:
            event.drop.windowID
        case SDL_EVENT_FINGER_DOWN, SDL_EVENT_FINGER_MOTION, SDL_EVENT_FINGER_UP, SDL_EVENT_FINGER_CANCELED:
            event.tfinger.windowID
        default:
            event.type >= SDL_EVENT_WINDOW_FIRST.rawValue && event.type <= SDL_EVENT_WINDOW_LAST.rawValue
                ? event.window.windowID : nil
        }
    }

    /// Runs work scheduled on the main actor, such as tasks and timers.
    private static func drainMainQueue() {
        _ = RunLoop.main.run(mode: .default, before: Date())
    }

    // MARK: Clipboard

    /// The text on the system's clipboard.
    public static var clipboardText: String? {
        get {
            guard SDL_HasClipboardText(), let text = SDL_GetClipboardText() else { return nil }
            defer { SDL_free(text) }
            return String(cString: text)
        }
        set {
            _ = SDL_SetClipboardText(newValue ?? "")
        }
    }

    /// Opens a URL with the system's handler for it.
    public static func open(_ url: URL) {
        _ = SDL_OpenURL(url.absoluteString)
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
