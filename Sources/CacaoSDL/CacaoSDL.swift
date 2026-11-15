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
                // The first scene's window opens at launch; the others open
                // with `openWindow`.
                descriptions = app.body.windowDescriptions()
                self.textEngine = textEngine
                statusItems = app.body.statusItemDescriptions().compactMap {
                    StatusItemHost(description: $0, textEngine: textEngine)
                }
                var windows = descriptions.filter(\.opensAtLaunch).prefix(1).compactMap {
                    WindowHost(description: $0, textEngine: textEngine)
                }
                guard !windows.isEmpty || !statusItems.isEmpty else {
                    print("Cacao: no windows to show: \(String(cString: SDL_GetError()))")
                    return
                }
                #if os(macOS)
                MainMenu.launchGraph = windows.first?.graph
                MainMenu.install { windows in
                    windows.first(where: { $0.isKey })?.graph ?? windows.first?.graph
                }
                #endif
                #if os(Linux)
                WaylandGestures.start()
                defer { WaylandGestures.stop() }
                #endif
                runLoop(&windows)
                windows.forEach { $0.close() }
                statusItems.forEach { $0.close() }
            }
        } catch {
            print("Cacao: \(error)")
        }
    }

    /// Waits for events while idle, and runs a frame per display refresh
    /// while anything animates; frames wait for vsync when presented.
    private static func runLoop(_ windows: inout [WindowHost]) {
        var event = SDL_Event()
        while !windows.isEmpty || !statusItems.isEmpty {
            #if os(macOS)
            MainMenu.windows = windows
            #endif
            #if os(Linux)
            WaylandGestures.windows = windows
            #endif
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
            #if os(Linux)
            WaylandGestures.dispatch()
            #endif
            drainMainQueue()
            handleWindowRequests(&windows)
            let now = now
            for window in windows {
                window.frame(now: now)
            }
            for item in statusItems {
                item.update()
            }
            if windows.contains(where: \.didSaveScreenshot) {
                return
            }
        }
    }

    /// A request from views to open or close windows.
    enum WindowRequest {
        case open(id: String?, value: AnyHashable?)
        case close(SDL_WindowID)
        case closeScene(String)
    }

    /// Requests from `openWindow` and `dismissWindow`, handled each loop.
    static var windowRequests: [WindowRequest] = []

    /// The app's scenes' windows.
    private static var descriptions: [WindowDescription] = []

    /// The app's menu bar extras.
    private static var statusItems: [StatusItemHost] = []

    private static var textEngine: SilicaTextEngine?

    private static func handleWindowRequests(_ windows: inout [WindowHost]) {
        let requests = windowRequests
        windowRequests.removeAll()
        for request in requests {
            switch request {
            case let .open(id, value):
                let description = descriptions.first { candidate in
                    if let id { return candidate.id == id }
                    return value != nil && candidate.makeRootView != nil
                }
                guard let description, let textEngine else { continue }
                // A unique window shows again instead of opening twice.
                if description.isUnique, let existing = windows.first(where: { $0.sceneID == description.id && $0.sceneID != nil }) {
                    existing.raise()
                    continue
                }
                if let window = WindowHost(description: description, value: value, textEngine: textEngine) {
                    windows.append(window)
                }
            case let .close(id):
                if let index = windows.firstIndex(where: { $0.id == id }) {
                    windows[index].close()
                    windows.remove(at: index)
                }
            case let .closeScene(sceneID):
                for window in windows where window.sceneID == sceneID {
                    window.close()
                }
                windows.removeAll { $0.sceneID == sceneID }
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
            // A menu bar app keeps running without windows.
            return !windows.isEmpty || !statusItems.isEmpty
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
        case SDL_EVENT_PINCH_BEGIN, SDL_EVENT_PINCH_UPDATE, SDL_EVENT_PINCH_END:
            event.pinch.windowID
        case SDL_EVENT_KEY_DOWN, SDL_EVENT_KEY_UP:
            event.key.windowID
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
}

/// An error starting SDL.
public struct SDLHostError: Error, CustomStringConvertible {

    public let message: String

    public var description: String {
        "SDL: \(message)"
    }
}
