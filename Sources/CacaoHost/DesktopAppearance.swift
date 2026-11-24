//
//  DesktopAppearance.swift
//  CacaoHost
//
//  Created by Alsey Coleman Miller on 11/21/26.
//

import Foundation
import CacaoRender
import SDL3Swift
#if os(Linux)
internal import CacaoDBus
#endif

/// Whether the desktop shows light or dark windows, and the accent color
/// and contrast it asks for.
///
/// On Linux the freedesktop settings portal says, over D-Bus: its
/// `org.freedesktop.appearance` `color-scheme`, `accent-color` and
/// `contrast`, followed as they change. Where no portal answers, SDL says
/// what it can, else GNOME's `org.gnome.desktop.interface` `color-scheme`
/// is asked through `gsettings`, else windows are light. Elsewhere SDL
/// says. `CACAO_APPEARANCE=dark` or `light` overrides them all.
package enum DesktopAppearance {

    /// The appearance windows show now.
    @MainActor
    static var current: HostAppearance {
        if let override {
            return override
        }
        #if os(Linux)
        if let colorScheme = portal?.colorScheme {
            // No preference is the desktop's default, which is light.
            return colorScheme == .dark ? .dark : .light
        }
        #endif
        switch SDL.systemTheme {
        case .dark:
            return .dark
        case .light:
            return .light
        case .unknown:
            return asked ?? .light
        }
    }

    /// The color the desktop tints controls with, if it says.
    @MainActor
    static var accentColor: ResolvedColor? {
        #if os(Linux)
        guard let accent = portal?.accentColor else {
            return nil
        }
        return ResolvedColor(red: Float(accent.red), green: Float(accent.green), blue: Float(accent.blue))
        #else
        return nil
        #endif
    }

    /// Whether the desktop asks for higher contrast.
    @MainActor
    static var prefersIncreasedContrast: Bool {
        #if os(Linux)
        return portal?.contrast == .high
        #else
        return false
        #endif
    }

    /// Starts asking the desktop, so its answer is ready, or nearly, when
    /// the first window asks: once SDL's video has started.
    @MainActor
    static func start() {
        #if os(Linux)
        followPortal()
        #endif
    }

    /// The appearance `CACAO_APPEARANCE` asks for.
    private static let override = ProcessInfo.processInfo.environment["CACAO_APPEARANCE"]
        .flatMap(appearance(named:))

    /// Whether a desktop is drawn on, so has settings to read: drivers that
    /// draw offscreen keep what they draw the same wherever they run.
    @MainActor
    private static var isOnDesktop: Bool {
        guard let driver = SDL.currentVideoDriver else {
            return false
        }
        return driver == "wayland" || driver == "x11"
    }

    /// What GNOME's setting said, asked once: a command is too slow to run
    /// each time, and nothing tells of a change.
    @MainActor
    private static let asked: HostAppearance? = {
        #if os(Linux)
        guard isOnDesktop else {
            return nil
        }
        return appearance(gnomeSetting: output(of: [
            "gsettings", "get", "org.gnome.desktop.interface", "color-scheme"
        ]))
        #else
        return nil
        #endif
    }()

    // MARK: Settings portal

    #if os(Linux)
    /// What the settings portal serves, kept current: `nil` with no session
    /// bus, and nothing set with no portal on it.
    @MainActor
    private static var portal: PortalAppearance? {
        followPortal()
        if let firstAnswer {
            self.firstAnswer = nil
            if let answer = firstAnswer.wait(seconds: portalWait) {
                portalObserver = answer.observer
                portalAppearance = answer.appearance
            }
        }
        return portalAppearance
    }

    @MainActor
    private static var portalAppearance: PortalAppearance?

    @MainActor
    private static var portalObserver: PortalAppearanceObserver?

    @MainActor
    private static var didFollowPortal = false

    /// The portal's first answer, until it's waited for.
    @MainActor
    private static var firstAnswer: FirstAnswer?

    /// How long the first window waits for the portal's first answer, so
    /// its first frame shows the right appearance. An answer that comes
    /// later is shown as a change; until then SDL's answer, or GNOME's
    /// setting, is shown.
    ///
    /// Short, because the app can't show anything while it waits. The
    /// answer is asked for while the app sets up, so a quick bus answers
    /// in time.
    private static let portalWait: Double = 0.2

    /// Starts reading the portal and following its changes, once SDL draws
    /// on a desktop.
    @MainActor
    private static func followPortal() {
        guard !didFollowPortal, SDL.currentVideoDriver != nil else {
            return
        }
        didFollowPortal = true
        guard isOnDesktop else {
            return
        }
        let firstAnswer = FirstAnswer()
        self.firstAnswer = firstAnswer
        Task.detached {
            let started = await PortalAppearanceObserver.start { appearance in
                Task { @MainActor in
                    portalChanged(appearance)
                }
                HostRuntime.wake()
            }
            if !firstAnswer.offer(started) {
                Task { @MainActor in
                    portalObserver = started?.observer
                    if let appearance = started?.appearance {
                        portalChanged(appearance)
                    }
                }
                HostRuntime.wake()
            }
        }
    }

    /// Shows a change the portal told of in every window.
    @MainActor
    private static func portalChanged(_ appearance: PortalAppearance) {
        guard appearance != portalAppearance else {
            return
        }
        portalAppearance = appearance
        HostRuntime.systemAppearanceChanged()
    }

    /// The portal's first answer, handed from the task that asks to the
    /// main thread waiting for it, unless it stopped waiting.
    private final class FirstAnswer: @unchecked Sendable {

        typealias Answer = (observer: PortalAppearanceObserver, appearance: PortalAppearance)

        private let lock = NSLock()

        private let answered = DispatchSemaphore(value: 0)

        private var answer: Answer?

        private var isWaiting = true

        /// Hands over the answer. Returns false if the waiter stopped
        /// waiting.
        func offer(_ answer: Answer?) -> Bool {
            lock.lock()
            defer { lock.unlock() }
            guard isWaiting else {
                return false
            }
            self.answer = answer
            answered.signal()
            return true
        }

        /// Waits for the answer, for at most `seconds`.
        func wait(seconds: Double) -> Answer? {
            _ = answered.wait(timeout: .now() + seconds)
            lock.lock()
            defer { lock.unlock() }
            isWaiting = false
            return answer
        }
    }
    #endif

    // MARK: Reading answers

    /// The appearance a name like `dark` or `Light` asks for.
    package static func appearance(named name: String) -> HostAppearance? {
        switch name.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() {
        case "dark": .dark
        case "light": .light
        default: nil
        }
    }

    /// The appearance in GNOME's `color-scheme` setting, like `'prefer-dark'`.
    package static func appearance(gnomeSetting setting: String) -> HostAppearance? {
        if setting.contains("prefer-dark") {
            return .dark
        }
        if setting.contains("prefer-light") || setting.contains("default") {
            return .light
        }
        return nil
    }

    // MARK: Commands

    #if os(Linux)
    /// What a command printed, or nothing when it can't run.
    private static func output(of command: [String]) -> String {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        process.arguments = command
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = FileHandle.nullDevice
        process.standardInput = FileHandle.nullDevice
        do {
            try process.run()
        } catch {
            return ""
        }
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()
        return String(decoding: data, as: UTF8.self)
    }
    #endif
}
