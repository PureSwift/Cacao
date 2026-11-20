//
//  WaylandGestures.swift
//  CacaoHost
//
//  Created by Alsey Coleman Miller on 11/15/26.
//

#if os(Linux)
import CacaoRender
import Foundation
import CSDL3
import CacaoWayland

/// Touchpad pinches from the Wayland compositor, for their rotations: SDL
/// reports a pinch's scale but not how it turns.
@MainActor
enum WaylandGestures {

    private static var gestures: OpaquePointer?

    /// Listens on SDL's Wayland connection, if SDL uses Wayland and the
    /// compositor offers pointer gestures.
    static func start() {
        guard gestures == nil,
              let driver = SDL_GetCurrentVideoDriver(), String(cString: driver) == "wayland",
              let display = SDL_GetPointerProperty(SDL_GetGlobalProperties(), SDL_PROP_GLOBAL_VIDEO_WAYLAND_WL_DISPLAY_POINTER, nil) else {
            return
        }
        gestures = cacao_wayland_gestures_create(display, pinchCallback, nil)
        if ProcessInfo.processInfo.environment["CACAO_LOG_INPUT"] != nil {
            print("Cacao: Wayland pointer gestures \(gestures == nil ? "unavailable" : "bound")")
        }
    }

    /// Delivers the pinch events SDL read from the connection.
    static func dispatch() {
        cacao_wayland_gestures_dispatch(gestures)
    }

    static func stop() {
        cacao_wayland_gestures_destroy(gestures)
        gestures = nil
    }

    /// A pinch over the surface at an address.
    fileprivate static func pinch(_ phase: CacaoPinchPhase, surface: UInt, rotation: Double) {
        guard let window = HostRuntime.windows.first(where: { UInt(bitPattern: $0.waylandSurface) == surface }) else { return }
        let phase: HostPhase = switch phase {
        case CacaoPinchPhaseBegan: .began
        case CacaoPinchPhaseChanged: .moved
        case CacaoPinchPhaseEnded: .ended
        default: .cancelled
        }
        window.systemRotation(phase, clockwiseDegrees: rotation)
    }
}

/// Called on the main thread, as the host dispatches the queue.
private let pinchCallback: CacaoPinchCallback = { _, phase, surface, rotation, _ in
    let address = UInt(bitPattern: surface)
    MainActor.assumeIsolated {
        WaylandGestures.pinch(phase, surface: address, rotation: rotation)
    }
}
#endif
