//
//  DesktopAppearance.swift
//  CacaoHost
//
//  Created by Alsey Coleman Miller on 11/21/26.
//

import Foundation
import SDL3Swift

/// Whether the desktop shows light or dark windows.
///
/// SDL says, where it can: on Linux it asks the freedesktop settings portal
/// over D-Bus, and hears when the setting changes. It says nothing when it
/// has no D-Bus library to load or no portal answers, so then the desktop
/// is asked the way a shell would: the portal's
/// `org.freedesktop.appearance` `color-scheme` through `gdbus`, else GNOME's
/// `org.gnome.desktop.interface` `color-scheme` through `gsettings`, else
/// light. `CACAO_APPEARANCE=dark` or `light` overrides them all.
package enum DesktopAppearance {

    /// The appearance windows show now.
    @MainActor
    static var current: HostAppearance {
        if let override {
            return override
        }
        switch SDL.systemTheme {
        case .dark:
            return .dark
        case .light:
            return .light
        case .unknown:
            return asked ?? .light
        }
    }

    /// The appearance `CACAO_APPEARANCE` asks for.
    private static let override = ProcessInfo.processInfo.environment["CACAO_APPEARANCE"]
        .flatMap(appearance(named:))

    /// What the desktop answered, asked once: commands are too slow to run
    /// each time, and nothing tells of a change.
    @MainActor
    private static let asked: HostAppearance? = {
        #if os(Linux)
        // Only a desktop has a setting; drivers that draw offscreen keep
        // what they draw the same wherever they run.
        guard let driver = SDL.currentVideoDriver, driver == "wayland" || driver == "x11" else {
            return nil
        }
        let portal = output(of: [
            "gdbus", "call", "--session", "--timeout", "2",
            "--dest", "org.freedesktop.portal.Desktop",
            "--object-path", "/org/freedesktop/portal/desktop",
            "--method", "org.freedesktop.portal.Settings.ReadOne",
            "org.freedesktop.appearance", "color-scheme"
        ])
        if let appearance = appearance(portalReply: portal) {
            return appearance
        }
        return appearance(gnomeSetting: output(of: [
            "gsettings", "get", "org.gnome.desktop.interface", "color-scheme"
        ]))
        #else
        return nil
        #endif
    }()

    // MARK: Reading answers

    /// The appearance a name like `dark` or `Light` asks for.
    package static func appearance(named name: String) -> HostAppearance? {
        switch name.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() {
        case "dark": .dark
        case "light": .light
        default: nil
        }
    }

    /// The appearance in the portal's reply to reading `color-scheme`, like
    /// `(<uint32 1>,)`: 1 prefers dark, 2 light, and 0 has no preference.
    package static func appearance(portalReply reply: String) -> HostAppearance? {
        if reply.contains("uint32 1") {
            return .dark
        }
        if reply.contains("uint32 2") {
            return .light
        }
        return nil
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
