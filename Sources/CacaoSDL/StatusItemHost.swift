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
import CSDL3

/// A menu bar extra shown as an SDL tray icon: the menu bar's status area
/// on macOS, the system tray elsewhere. Its menu holds the buttons of the
/// extra's content, from a graph of the content outside any window.
@MainActor
final class StatusItemHost {

    private let tray: OpaquePointer

    private let graph: ViewGraph

    /// What each entry does, kept alive while the menu shows it.
    private var actions: [ActionBox] = []

    /// The items the menu shows, to rebuild it only when they change.
    private var shown: [String] = []

    final class ActionBox {
        let action: @MainActor () -> Void
        init(_ action: @escaping @MainActor () -> Void) { self.action = action }
    }

    init?(description: StatusItemDescription, textEngine: SilicaTextEngine) {
        let icon = Self.iconSurface(description, textEngine: textEngine)
        defer { if let icon { SDL_DestroySurface(icon) } }
        guard let tray = SDL_CreateTray(icon, description.title) else {
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
        _ = SDL_CreateTrayMenu(tray)
        update()
    }

    /// Updates the content and rebuilds the menu if its items changed.
    func update() {
        graph.update()
        graph.layout(in: CGSize(width: 320, height: 2000))
        let items = graph.menuItems()
        let signature = items.map { "\($0.kind)|\($0.title)|\($0.isEnabled)" }
        guard signature != shown, let menu = SDL_GetTrayMenu(tray) else { return }
        shown = signature
        var count: Int32 = 0
        if let entries = SDL_GetTrayEntries(menu, &count) {
            for index in (0..<Int(count)).reversed() {
                SDL_RemoveTrayEntry(entries[index])
            }
        }
        actions = []
        for item in items {
            switch item.kind {
            case .separator:
                _ = SDL_InsertTrayEntryAt(menu, -1, nil, SDL_TrayEntryFlags(SDL_TRAYENTRY_BUTTON))
            case .button:
                var flags = SDL_TrayEntryFlags(SDL_TRAYENTRY_BUTTON)
                if !item.isEnabled { flags |= SDL_TrayEntryFlags(SDL_TRAYENTRY_DISABLED) }
                guard let entry = SDL_InsertTrayEntryAt(menu, -1, item.title, flags) else { continue }
                let box = ActionBox(item.action)
                actions.append(box)
                SDL_SetTrayEntryCallback(entry, { userdata, _ in
                    guard let userdata else { return }
                    let box = Unmanaged<ActionBox>.fromOpaque(userdata).takeUnretainedValue()
                    MainActor.assumeIsolated { box.action() }
                }, Unmanaged.passUnretained(box).toOpaque())
            }
        }
    }

    func close() {
        SDL_DestroyTray(tray)
    }

    /// The extra's symbol, or else its title, drawn for the tray.
    private static func iconSurface(_ description: StatusItemDescription, textEngine: SilicaTextEngine) -> UnsafeMutablePointer<SDL_Surface>? {
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
        guard let image = Rasterizer.rasterize(content, size: item.frame.size, scale: scale, textEngine: textEngine),
              let surface = SDL_CreateSurface(Int32(image.width), Int32(image.height), SDL_PIXELFORMAT_ABGR8888) else {
            return nil
        }
        image.data.withUnsafeBytes { (bytes: UnsafeRawBufferPointer) in
            guard let pixels = surface.pointee.pixels, let base = bytes.baseAddress else { return }
            for row in 0..<image.height {
                memcpy(pixels.advanced(by: row * Int(surface.pointee.pitch)), base.advanced(by: row * image.bytesPerRow), image.width * 4)
            }
        }
        return surface
    }
}
