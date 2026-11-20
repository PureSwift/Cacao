//
//  CacaoSDL.swift
//  CacaoSDL
//
//  Created by Alsey Coleman Miller on 11/13/26.
//

import CacaoRender
@_exported import Cacao
import CacaoHost
import CacaoCompositor
import Foundation
#if canImport(CoreGraphics)
import CoreGraphics
#endif

extension App {

    /// Runs the app: opens a window for each of its scenes and runs the
    /// main loop until the last window closes.
    @MainActor
    public static func main() {
        HostRuntime.runApp {
            SDLHost.run(Self())
        }
    }
}

/// Runs SwiftUI apps on the SDL3 host: a window for each scene, each
/// showing a view graph.
@MainActor
public enum SDLHost {

    /// The version of the SDL library loaded at run time, as `major.minor.micro`.
    public nonisolated static var sdlVersion: String {
        HostRuntime.sdlVersion
    }

    /// Initializes SDL's video subsystem, runs `body`, then shuts SDL down.
    public static func withVideo<T>(_ body: () throws -> T) throws -> T {
        try HostRuntime.withVideo(body)
    }

    /// Runs an app until its windows close.
    public static func run<A: App>(_ app: A) {
        HostRuntime.run {
            guard let textEngine = HostRuntime.textEngine else { return }
            // The first scene's window opens at launch; the others open
            // with `openWindow`.
            descriptions = app.body.windowDescriptions()
            statusItems = app.body.statusItemDescriptions().compactMap {
                StatusItemHost(description: $0, textEngine: textEngine)
            }
            for description in descriptions.filter(\.opensAtLaunch).prefix(1) {
                open(description)
            }
            HostRuntime.runsWithoutWindows = { !statusItems.isEmpty }
            HostRuntime.addWakeHook {
                handleWindowRequests()
                for item in statusItems {
                    item.update()
                }
            }
            #if os(macOS)
            let launchGraph = scenes.first?.graph
            MainMenu.install {
                (HostRuntime.keyWindow?.scene as? WindowScene)?.graph ?? scenes.first?.graph ?? launchGraph
            }
            #endif
        }
        statusItems.forEach { $0.close() }
        statusItems = []
        descriptions = []
        windowRequests = []
    }

    /// The SwiftUI scenes of the open windows.
    private static var scenes: [WindowScene] {
        HostRuntime.windows.compactMap { $0.scene as? WindowScene }
    }

    @discardableResult
    private static func open(_ description: WindowDescription, value: AnyHashable? = nil) -> HostWindow? {
        guard let textEngine = HostRuntime.textEngine else { return nil }
        return HostRuntime.openWindow(
            title: description.title,
            size: description.defaultSize ?? CGSize(width: 800, height: 600)
        ) { window in
            WindowScene(description: description, value: value, window: window, textEngine: textEngine)
        }
    }

    /// A request from views to open or close windows.
    enum WindowRequest {
        case open(id: String?, value: AnyHashable?)
        case close(HostWindow)
        case closeScene(String)
    }

    /// Requests from `openWindow` and `dismissWindow`, handled each time
    /// the loop wakes.
    static var windowRequests: [WindowRequest] = []

    /// The app's scenes' windows.
    private static var descriptions: [WindowDescription] = []

    /// The app's menu bar extras.
    private static var statusItems: [StatusItemHost] = []

    private static func handleWindowRequests() {
        let requests = windowRequests
        windowRequests.removeAll()
        for request in requests {
            switch request {
            case let .open(id, value):
                let description = descriptions.first { candidate in
                    if let id { return candidate.id == id }
                    return value != nil && candidate.makeRootView != nil
                }
                guard let description else { continue }
                // A unique window shows again instead of opening twice.
                if description.isUnique,
                   let existing = scenes.first(where: { $0.sceneID == description.id && $0.sceneID != nil }) {
                    existing.window?.raise()
                    continue
                }
                open(description, value: value)
            case let .close(window):
                HostRuntime.close(window)
            case let .closeScene(sceneID):
                for scene in scenes where scene.sceneID == sceneID {
                    if let window = scene.window {
                        HostRuntime.close(window)
                    }
                }
            }
        }
    }
}

/// An error starting SDL.
public typealias SDLHostError = HostError
