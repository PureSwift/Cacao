//
//  CacaoSDL.swift
//  CacaoSDL
//
//  Created by Alsey Coleman Miller on 11/13/26.
//

@_exported import Cacao
import CacaoCompositor
import CSDL3
import Foundation
#if canImport(CoreGraphics)
import CoreGraphics
#endif

extension App {

    /// Runs the app: opens a window for each of its scenes and runs the
    /// main loop until the last window closes.
    @MainActor
    public static func main() {
        SDLHost.run(Self())
    }
}

/// The SDL3 host: windows, the main loop and frame clock, and input.
@MainActor
public enum SDLHost {

    /// The version of the SDL library loaded at run time, as `major.minor.micro`.
    public nonisolated static var sdlVersion: String {
        let version = Int(SDL_GetVersion())
        return "\(version / 1_000_000).\(version / 1_000 % 1_000).\(version % 1_000)"
    }

    /// Seconds since SDL started, from its high resolution clock.
    static var now: Double {
        Double(SDL_GetTicksNS()) / 1_000_000_000
    }

    /// Initializes SDL's video subsystem, runs `body`, then shuts SDL down.
    public static func withVideo<T>(_ body: () throws -> T) throws -> T {
        guard SDL_Init(SDL_InitFlags(0x0000_0020)) else {
            throw SDLHostError(message: String(cString: SDL_GetError()))
        }
        defer { SDL_Quit() }
        return try body()
    }

    /// Runs an app until its windows close.
    public static func run<A: App>(_ app: A) {
        // Deliver macOS's own trackpad momentum as wheel events.
        SDL_SetHint("SDL_MAC_SCROLL_MOMENTUM", "1")
        do {
            try withVideo {
                let textEngine = SilicaTextEngine()
                var windows = app.body.windowDescriptions().compactMap {
                    WindowHost(description: $0, textEngine: textEngine)
                }
                guard !windows.isEmpty else {
                    print("Cacao: no windows to show: \(String(cString: SDL_GetError()))")
                    return
                }
                runLoop(&windows)
                windows.forEach { $0.close() }
            }
        } catch {
            print("Cacao: \(error)")
        }
    }

    /// Waits for events while idle, and runs a frame per display refresh
    /// while anything animates; frames wait for vsync when presented.
    private static func runLoop(_ windows: inout [WindowHost]) {
        var event = SDL_Event()
        while !windows.isEmpty {
            let animating = windows.contains { $0.isAnimating }
            // Idle: sleep until an event, waking periodically to run main
            // actor work (tasks, timers) scheduled outside of SDL.
            if animating ? SDL_PollEvent(&event) : SDL_WaitEventTimeout(&event, 16) {
                repeat {
                    if !handle(event, windows: &windows) {
                        return
                    }
                } while SDL_PollEvent(&event)
            }
            drainMainQueue()
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
    private static func handle(_ event: SDL_Event, windows: inout [WindowHost]) -> Bool {
        let now = now
        switch SDL_EventType(event.type) {
        case SDL_EVENT_QUIT:
            return false
        case SDL_EVENT_WINDOW_CLOSE_REQUESTED:
            if let index = windows.firstIndex(where: { $0.id == event.window.windowID }) {
                windows[index].close()
                windows.remove(at: index)
            }
            return !windows.isEmpty
        case SDL_EVENT_SYSTEM_THEME_CHANGED:
            windows.forEach { $0.systemThemeChanged() }
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
        case SDL_EVENT_KEY_DOWN, SDL_EVENT_KEY_UP:
            event.key.windowID
        default:
            event.type >= SDL_EVENT_WINDOW_FIRST.rawValue && event.type <= SDL_EVENT_WINDOW_LAST.rawValue
                ? event.window.windowID : nil
        }
    }

    /// Runs work scheduled on the main actor, such as tasks and timers.
    private static func drainMainQueue() {
        _ = RunLoop.main.run(mode: .default, before: Date())
    }
}

/// An error starting SDL.
public struct SDLHostError: Error, CustomStringConvertible {

    public let message: String

    public var description: String {
        "SDL: \(message)"
    }
}
