//
//  WaylandPopupTests.swift
//  Cacao
//
//  Gives surfaces the popup role against a test compositor, as popups of a
//  layer surface, and checks where they asked to go, the grab they took,
//  and the placements and dismissal they heard of.
//

#if os(Linux)
import Foundation
import Testing
import CacaoWayland
import CacaoWaylandTestServer

/// The placements the popup was configured with, and whether it was
/// dismissed.
nonisolated(unsafe) private var placements: [(x: Int32, y: Int32, width: Int32, height: Int32)] = []
nonisolated(unsafe) private var dismissals = 0

private let recordPlacement: CacaoPopupConfigureCallback = { _, x, y, width, height in
    placements.append((x, y, width, height))
}

private let recordDismissal: CacaoPopupDoneCallback = { _ in
    dismissals += 1
}

@Suite(.serialized) struct WaylandPopupTests {

    init() throws {
        // Wayland sockets live in the runtime directory.
        if ProcessInfo.processInfo.environment["XDG_RUNTIME_DIR"] == nil {
            let directory = FileManager.default.temporaryDirectory.appendingPathComponent("cacao-xdg-\(getpid())")
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true, attributes: [.posixPermissions: 0o700])
            setenv("XDG_RUNTIME_DIR", directory.path, 1)
        }
        placements = []
        dismissals = 0
    }

    /// A menu below a title in a 28-point bar: anchored to the title's
    /// bottom left, extending down and right, flipping up and sliding
    /// sideways at the screen's edges.
    private func menuBelowTitle(height: Int32 = 120) -> CacaoPopupPositioner {
        CacaoPopupPositioner(
            anchor_x: 40, anchor_y: 3, anchor_width: 50, anchor_height: 22,
            width: 200, height: height,
            anchor: 6, gravity: 8, constraint_adjustment: 1 | 8 | 32,
            offset_x: 0, offset_y: 4
        )
    }

    /// A bar along the top of the screen, as the desktop's menu bar is.
    private func makeBar(shell: OpaquePointer, display: UnsafeMutableRawPointer) throws -> OpaquePointer {
        let wlSurface = try #require(cacao_test_client_create_surface(display))
        var options = CacaoLayerSurfaceOptions(
            layer: CacaoLayerTop,
            anchors: CacaoLayerAnchorTop.rawValue | CacaoLayerAnchorLeft.rawValue | CacaoLayerAnchorRight.rawValue,
            exclusive_zone: 28, margin_top: 0, margin_right: 0, margin_bottom: 0, margin_left: 0,
            width: 0, height: 28, keyboard_interactivity: CacaoLayerKeyboardInteractivityNone, name_space: nil
        )
        return try #require(cacao_wayland_layer_surface_create(shell, wlSurface, &options, nil, nil, nil))
    }

    @Test func layerSurfacePopupsAskForTheirPlaceAndAreConfigured() throws {
        let socket = "cacao-popup-test-\(getpid())"
        let server = try #require(cacao_test_server_start_with_features(socket, CacaoTestServerFeatureLayerShell.rawValue | CacaoTestServerFeatureXdgShell.rawValue))
        defer { cacao_test_server_stop(server) }
        let display = try #require(cacao_test_client_connect(socket))
        defer { cacao_test_client_disconnect(display) }
        let shell = try #require(cacao_wayland_layer_shell_create(display))
        defer { cacao_wayland_layer_shell_destroy(shell) }
        let bar = try makeBar(shell: shell, display: display)
        defer { cacao_wayland_layer_surface_destroy(bar) }

        let popups = try #require(cacao_wayland_popups_create(display))
        defer { cacao_wayland_popups_destroy(popups) }
        let wlSurface = try #require(cacao_test_client_create_surface(display))
        var parent = CacaoPopupParent(xdg_surface: nil, layer_surface: bar, popup: nil)
        var positioner = menuBelowTitle()
        // A shadow's margins around the menu.
        var geometry = CacaoPopupGeometry(x: 16, y: 12, width: 200, height: 120)
        let popup = try #require(cacao_wayland_popup_create(
            popups, wlSurface, &parent, &positioner, &geometry, true, recordPlacement, recordDismissal, nil
        ))
        // Its acknowledgment reaches the server.
        cacao_test_client_roundtrip(display)

        // The layer surface took it, as it had no xdg parent.
        var state = cacao_test_server_popup_state(server)
        #expect(state.exists == 1)
        #expect(state.has_layer_parent == 1)
        #expect(state.has_xdg_parent == 0)
        #expect(state.positioner.anchor_x == 40)
        #expect(state.positioner.anchor_y == 3)
        #expect(state.positioner.anchor_width == 50)
        #expect(state.positioner.anchor_height == 22)
        #expect(state.positioner.width == 200)
        #expect(state.positioner.height == 120)
        #expect(state.positioner.anchor == 6)
        #expect(state.positioner.gravity == 8)
        #expect(state.positioner.constraint_adjustment == 1 | 8 | 32)
        #expect(state.positioner.offset_y == 4)
        #expect(state.positioner.reactive == 1)
        #expect(state.geometry_x == 16)
        #expect(state.geometry_y == 12)
        #expect(state.geometry_width == 200)
        #expect(state.geometry_height == 120)
        // No input yet, so no grab.
        #expect(state.grabbed == 0)

        // Placed before it was returned, below the title, past the bar's
        // bottom edge; and acknowledged.
        #expect(placements.count == 1)
        #expect(placements.first?.x == 40)
        #expect(placements.first?.y == 29)
        #expect(placements.first?.height == 120)
        #expect(state.configured == 1)
        #expect(state.acked_serial == state.configured_serial)

        // A new size: placed again.
        var taller = menuBelowTitle(height: 300)
        var tallerGeometry = CacaoPopupGeometry(x: 16, y: 12, width: 200, height: 300)
        #expect(cacao_wayland_popup_reposition(popup, &taller, &tallerGeometry))
        for _ in 0..<20 where placements.count < 2 {
            cacao_test_client_roundtrip(display)
            cacao_wayland_popups_dispatch(popups)
        }
        state = cacao_test_server_popup_state(server)
        #expect(state.repositions == 1)
        #expect(state.geometry_height == 300)
        #expect(placements.last?.height == 300)

        cacao_wayland_popup_destroy(popup)
        cacao_test_client_roundtrip(display)
        #expect(cacao_test_server_popup_state(server).exists == 0)
    }

    @Test func popupsGrabTheLastPressAndHearOfDismissal() throws {
        let socket = "cacao-popup-grab-\(getpid())"
        let server = try #require(cacao_test_server_start_with_features(socket, CacaoTestServerFeatureLayerShell.rawValue | CacaoTestServerFeatureXdgShell.rawValue))
        defer { cacao_test_server_stop(server) }
        let display = try #require(cacao_test_client_connect(socket))
        defer { cacao_test_client_disconnect(display) }
        let shell = try #require(cacao_wayland_layer_shell_create(display))
        defer { cacao_wayland_layer_shell_destroy(shell) }
        let bar = try makeBar(shell: shell, display: display)
        defer { cacao_wayland_layer_surface_destroy(bar) }
        let popups = try #require(cacao_wayland_popups_create(display))
        defer { cacao_wayland_popups_destroy(popups) }

        // A click on the bar's title.
        cacao_test_server_press_button(server)
        for _ in 0..<20 where cacao_wayland_popups_input_serial(popups) == 0 {
            cacao_test_client_roundtrip(display)
            cacao_wayland_popups_dispatch(popups)
        }
        let serial = cacao_wayland_popups_input_serial(popups)
        #expect(serial != 0)
        #expect(serial == cacao_test_server_last_press_serial(server))

        let wlSurface = try #require(cacao_test_client_create_surface(display))
        var parent = CacaoPopupParent(xdg_surface: nil, layer_surface: bar, popup: nil)
        var positioner = menuBelowTitle()
        var geometry = CacaoPopupGeometry(x: 0, y: 0, width: 200, height: 120)
        let popup = try #require(cacao_wayland_popup_create(
            popups, wlSurface, &parent, &positioner, &geometry, true, recordPlacement, recordDismissal, nil
        ))
        defer { cacao_wayland_popup_destroy(popup) }
        let state = cacao_test_server_popup_state(server)
        #expect(state.grabbed == 1)
        #expect(state.grab_serial == serial)

        // A click elsewhere: the compositor dismisses it.
        cacao_test_server_dismiss_popup(server)
        for _ in 0..<20 where dismissals == 0 {
            cacao_test_client_roundtrip(display)
            cacao_wayland_popups_dispatch(popups)
        }
        #expect(dismissals == 1)
    }

    @Test func popupsNeedAShellAndAParent() throws {
        let socket = "cacao-popup-none-\(getpid())"
        let server = try #require(cacao_test_server_start_with_features(socket, 0))
        defer { cacao_test_server_stop(server) }
        let display = try #require(cacao_test_client_connect(socket))
        defer { cacao_test_client_disconnect(display) }
        #expect(cacao_wayland_popups_create(display) == nil)
        #expect(cacao_wayland_popups_create(nil) == nil)
    }
}
#endif
