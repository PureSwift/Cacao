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

    /// The app's identifier, such as `com.example.Notes`: the Wayland
    /// `app_id` and X11 window class of its windows, which docks match to
    /// desktop entries. Defaults to the main bundle's identifier; with
    /// none, the executable's name is used. Set it in the app's `init()`
    /// to name the first window too.
    public static var appIdentifier: String? {
        get { HostRuntime.appIdentifier }
        set { HostRuntime.appIdentifier = newValue }
    }

    /// Initializes SDL's video subsystem, runs `body`, then shuts SDL down.
    public static func withVideo<T>(_ body: () throws -> T) throws -> T {
        try HostRuntime.withVideo(body)
    }

    /// Runs an app until its windows close.
    public static func run<A: App>(_ app: A) {
        HostRuntime.run {
            guard let textEngine = HostRuntime.textEngine else { return }
            // In a debug build, previews are drawn to the build folder.
            PreviewSnapshots.generate(textEngine: textEngine)
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
            size: description.defaultSize ?? CGSize(width: 800, height: 600),
            layer: description.layer.map(HostLayerSurface.init),
            decorations: description.windowStyle.drawsOwnDecorations ? .none : .system
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

extension HostLayerSurface {

    /// The host's placement for a scene's: leading and trailing are the
    /// screen's left and right.
    init(_ placement: WindowLayerPlacement) {
        var edges: Edges = []
        if placement.edges.contains(.top) { edges.insert(.top) }
        if placement.edges.contains(.bottom) { edges.insert(.bottom) }
        if placement.edges.contains(.leading) { edges.insert(.left) }
        if placement.edges.contains(.trailing) { edges.insert(.right) }
        let layer: Layer = switch placement.layer {
        case .background: .background
        case .bottom: .bottom
        case .top: .top
        case .overlay: .overlay
        }
        let keyboard: KeyboardInteractivity = switch placement.keyboardInteractivity {
        case .none: .none
        case .exclusive: .exclusive
        case .onDemand: .onDemand
        }
        self.init(
            layer: layer,
            edges: edges,
            exclusiveZone: placement.exclusiveZone,
            margins: HostInsets(
                top: placement.margins.top,
                left: placement.margins.leading,
                bottom: placement.margins.bottom,
                right: placement.margins.trailing
            ),
            keyboardInteractivity: keyboard,
            namespace: placement.namespace
        )
    }
}
