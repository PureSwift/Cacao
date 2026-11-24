//
//  WaylandLayerShell.swift
//  CacaoHost
//
//  Created by Alsey Coleman Miller on 11/23/26.
//

#if os(Linux)
import Foundation
#if canImport(CoreGraphics)
import CoreGraphics
#endif
import CacaoRender
import SDL3Swift
internal import CacaoWayland

/// The compositor's layer shell, for windows placed in a layer of the
/// screen: bound on SDL's Wayland connection when a window first asks.
@MainActor
enum WaylandLayerShell {

    private static var shell: OpaquePointer?

    /// Whether the compositor was asked, so a missing shell is asked once.
    private static var didBind = false

    /// The shell, if SDL uses Wayland and the compositor offers one.
    static var current: OpaquePointer? {
        if !didBind {
            didBind = true
            if SDL.currentVideoDriver == "wayland",
               let display = SDL.globalProperties.pointer("SDL.video.wayland.wl_display") {
                shell = cacao_wayland_layer_shell_create(display)
                if shell == nil {
                    print("Cacao: the compositor has no layer shell, so windows for layers open as windows")
                }
            }
        }
        return shell
    }

    /// Delivers the configure and close events SDL read from the connection.
    static func dispatch() {
        cacao_wayland_layer_shell_dispatch(shell)
    }

    /// After the windows are closed.
    static func stop() {
        cacao_wayland_layer_shell_destroy(shell)
        shell = nil
        didBind = false
    }

    /// Makes an SDL window whose Wayland surface has the layer role, sized
    /// as the compositor says. Returns nil without a layer shell.
    static func makeWindow(title: String, size: CGSize, options: HostLayerSurface) -> (window: SDLWindow, surface: WaylandLayerSurface)? {
        guard let shell = current else { return nil }
        let window: SDLWindow
        do {
            window = try SDLWindow { properties throws(SDLError) in
                try properties.setString("SDL.window.create.title", title)
                try properties.setNumber("SDL.window.create.width", Int64(max(size.width, 1)))
                try properties.setNumber("SDL.window.create.height", Int64(max(size.height, 1)))
                try properties.setBoolean("SDL.window.create.high_pixel_density", true)
                // A surface with no role, which this gives the layer role.
                try properties.setBoolean("SDL.window.create.wayland.surface_role_custom", true)
                // Made for the renderer from the start: SDL recreates a
                // window to suit a renderer, which would lose the role.
                if let api = renderingAPI {
                    try properties.setBoolean(api, true)
                }
            }
        } catch {
            print("Cacao: layer window not created: \(error)")
            return nil
        }
        guard let wlSurface = window.properties.pointer("SDL.window.wayland.surface"),
              let surface = WaylandLayerSurface(shell: shell, window: window, wlSurface: wlSurface, options: options, size: size) else {
            print("Cacao: the compositor closed the layer surface before showing it")
            return nil
        }
        return (window, surface)
    }

    /// The window flag the renderer needs.
    private static var renderingAPI: String? {
        switch HostRuntime.rendererName {
        case "vulkan", "gpu": "SDL.window.create.vulkan"
        case "software": nil
        default: "SDL.window.create.opengl"
        }
    }
}

/// A window's surface in a layer of the screen. SDL doesn't hear of its
/// size changes, so they're applied to the SDL window here.
@MainActor
final class WaylandLayerSurface {

    private var surface: OpaquePointer?

    /// The layer surface, for its popups.
    var pointer: OpaquePointer? { surface }

    private let window: SDLWindow

    /// Whether the compositor took the surface away.
    private(set) var isClosed = false

    /// The surface's name, kept for the C string SDL reads.
    private let namespace: String

    init?(shell: OpaquePointer, window: SDLWindow, wlSurface: UnsafeMutableRawPointer, options: HostLayerSurface, size: CGSize) {
        self.window = window
        self.namespace = options.namespace
        let requested = options.requestedSize(for: size)
        let margins = options.margins
        let context = Unmanaged.passUnretained(self).toOpaque()
        surface = namespace.withCString { name in
            var parameters = CacaoLayerSurfaceOptions(
                layer: options.layer.cValue,
                anchors: options.edges.rawValue,
                exclusive_zone: Int32(options.exclusiveZone.rounded()),
                margin_top: Int32(margins.top.rounded()),
                margin_right: Int32(margins.right.rounded()),
                margin_bottom: Int32(margins.bottom.rounded()),
                margin_left: Int32(margins.left.rounded()),
                width: UInt32(max(requested.width, 0).rounded()),
                height: UInt32(max(requested.height, 0).rounded()),
                keyboard_interactivity: options.keyboardInteractivity.cValue,
                name_space: name
            )
            return cacao_wayland_layer_surface_create(shell, wlSurface, &parameters, configureCallback, closedCallback, context)
        }
        guard surface != nil else { return nil }
    }

    /// Removes the layer role, before SDL destroys the surface.
    func destroy() {
        cacao_wayland_layer_surface_destroy(surface)
        surface = nil
    }

    fileprivate func configure(width: UInt32, height: UInt32) {
        // 0 leaves an axis to the client: the window keeps its size.
        let current = window.size
        let size = (
            width: width > 0 ? Int(width) : current.width,
            height: height > 0 ? Int(height) : current.height
        )
        if size != current {
            window.size = size
        }
    }

    fileprivate func close() {
        isClosed = true
    }
}

/// Called on the main thread, as the host dispatches the queue (or creates
/// the surface).
private let configureCallback: CacaoLayerConfigureCallback = { context, width, height in
    guard let context else { return }
    let address = UInt(bitPattern: context)
    MainActor.assumeIsolated {
        let surface = Unmanaged<WaylandLayerSurface>.fromOpaque(UnsafeRawPointer(bitPattern: address)!).takeUnretainedValue()
        surface.configure(width: width, height: height)
    }
}

private let closedCallback: CacaoLayerClosedCallback = { context in
    guard let context else { return }
    let address = UInt(bitPattern: context)
    MainActor.assumeIsolated {
        Unmanaged<WaylandLayerSurface>.fromOpaque(UnsafeRawPointer(bitPattern: address)!).takeUnretainedValue().close()
    }
}

private extension HostLayerSurface.Layer {

    var cValue: CacaoLayer {
        switch self {
        case .background: CacaoLayerBackground
        case .bottom: CacaoLayerBottom
        case .top: CacaoLayerTop
        case .overlay: CacaoLayerOverlay
        }
    }
}

private extension HostLayerSurface.KeyboardInteractivity {

    var cValue: CacaoLayerKeyboardInteractivity {
        switch self {
        case .none: CacaoLayerKeyboardInteractivityNone
        case .exclusive: CacaoLayerKeyboardInteractivityExclusive
        case .onDemand: CacaoLayerKeyboardInteractivityOnDemand
        }
    }
}
#endif
