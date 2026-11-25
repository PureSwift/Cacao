//
//  StatusItemHost.swift
//  CacaoSDL
//
//  Created by Alsey Coleman Miller on 11/13/26.
//

import CacaoRender
import Foundation
#if canImport(CoreGraphics)
import CoreGraphics
#endif
import Cacao
import CacaoCompositor
import CacaoHost
import SDL3Swift

/// A menu bar extra shown as an SDL tray icon: the menu bar's status area
/// on macOS, the system tray elsewhere. Its menu holds the buttons of the
/// extra's content, from a graph of the content outside any window.
@MainActor
final class StatusItemHost {

    /// The tray icon, until the item closes.
    private var tray: SDLTray?

    private let graph: ViewGraph

    /// The items the menu shows, to rebuild it only when they change.
    private var shown: [String] = []

    init?(description: StatusItemDescription, textEngine: SilicaTextEngine) {
        let icon = Self.iconSurface(description, textEngine: textEngine)
        guard let tray = try? SDLTray(icon: icon, tooltip: description.title) else {
            return nil
        }
        self.tray = tray
        var environment = EnvironmentValues()
        environment.openURL = OpenURLAction { url in
            HostRuntime.open(url)
        }
        environment.openWindow = OpenWindowAction { id, value in
            SDLHost.windowRequests.append(.open(id: id, value: value))
        }
        environment.dismissWindow = DismissWindowAction { id in
            if let id { SDLHost.windowRequests.append(.closeScene(id)) }
        }
        self.graph = ViewGraph(rootView: description.content, environment: environment, textEngine: textEngine)
        update()
    }

    /// Updates the content and rebuilds the menu if its items changed.
    func update() {
        graph.update()
        graph.layout(in: CGSize(width: 320, height: 2000))
        let items = graph.menuItems()
        let signature = items.map { "\($0.kind)|\($0.title)|\($0.isEnabled)" }
        guard signature != shown, let menu = try? tray?.menu() else { return }
        shown = signature
        menu.removeAll()
        for item in items {
            switch item.kind {
            case .separator:
                _ = try? menu.insert(nil)
            case .button:
                let action = item.action
                // SDL calls a tray entry's action on the main thread.
                _ = try? menu.insert(item.title, isEnabled: item.isEnabled) {
                    MainActor.assumeIsolated { action() }
                }
            }
        }
    }

    func close() {
        // The tray icon goes with its last reference.
        tray = nil
    }

    /// The extra's symbol, or else its title, drawn for the tray.
    private static func iconSurface(_ description: StatusItemDescription, textEngine: SilicaTextEngine) -> SDLSurface? {
        let view: AnyView = description.systemImage.map { name in
            AnyView(Image(systemName: name).font(.system(size: 16)).foregroundStyle(Color.black))
        } ?? AnyView(Text(description.title).font(.system(size: 13)).foregroundStyle(Color.black).fixedSize())
        let graph = ViewGraph(rootView: view, textEngine: textEngine)
        graph.layout(in: CGSize(width: 200, height: 22))
        guard let item = graph.displayList().items.first(where: { if case .content = $0.value { true } else { false } }),
              case let .content(content) = item.value else {
            return nil
        }
        let scale: CGFloat = 2
        // Bytes in R, G, B, A order, as the rasterizer draws them.
        guard let image = Rasterizer.rasterize(content, size: item.frame.size, scale: scale, textEngine: textEngine),
              let surface = try? SDLSurface(format: .rgba32, size: (width: image.width, height: image.height)) else {
            return nil
        }
        let pitch = surface.pitch
        _ = try? surface.withUnsafeMutableBytes { pixels in
            image.data.withUnsafeBytes { (bytes: UnsafeRawBufferPointer) in
                guard let base = bytes.baseAddress else { return }
                for row in 0..<image.height {
                    memcpy(pixels.advanced(by: row * pitch), base.advanced(by: row * image.bytesPerRow), image.width * 4)
                }
            }
        }
        return surface
    }
}
