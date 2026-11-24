//
//  WaylandLayerShellTests.swift
//  Cacao
//
//  Gives a surface the layer role against a test compositor, and checks
//  what it asked for and the sizes and close it heard of.
//

#if os(Linux)
import Foundation
import Testing
import CacaoWayland
import CacaoWaylandTestServer

/// The sizes the layer surface was configured with, and whether it closed.
nonisolated(unsafe) private var configures: [(width: UInt32, height: UInt32)] = []
nonisolated(unsafe) private var closes = 0

private let recordConfigure: CacaoLayerConfigureCallback = { _, width, height in
    configures.append((width, height))
}

private let recordClose: CacaoLayerClosedCallback = { _ in
    closes += 1
}

@Suite(.serialized) struct WaylandLayerShellTests {

    init() throws {
        // Wayland sockets live in the runtime directory.
        if ProcessInfo.processInfo.environment["XDG_RUNTIME_DIR"] == nil {
            let directory = FileManager.default.temporaryDirectory.appendingPathComponent("cacao-xdg-\(getpid())")
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true, attributes: [.posixPermissions: 0o700])
            setenv("XDG_RUNTIME_DIR", directory.path, 1)
        }
        configures = []
        closes = 0
    }

    /// A bar along the top of the screen, as a menu bar asks for it.
    private func topBar() -> CacaoLayerSurfaceOptions {
        CacaoLayerSurfaceOptions(
            layer: CacaoLayerTop,
            anchors: CacaoLayerAnchorTop.rawValue | CacaoLayerAnchorLeft.rawValue | CacaoLayerAnchorRight.rawValue,
            exclusive_zone: 28,
            margin_top: 0,
            margin_right: 4,
            margin_bottom: 0,
            margin_left: 4,
            width: 0,
            height: 28,
            keyboard_interactivity: CacaoLayerKeyboardInteractivityOnDemand,
            name_space: nil
        )
    }

    @Test func surfacesAskForTheirPlaceAndAreConfigured() throws {
        let socket = "cacao-layer-test-\(getpid())"
        let server = try #require(cacao_test_server_start_with_layer_shell(socket, 1))
        defer { cacao_test_server_stop(server) }
        let display = try #require(cacao_test_client_connect(socket))
        defer { cacao_test_client_disconnect(display) }
        let wlSurface = try #require(cacao_test_client_create_surface(display))

        let shell = try #require(cacao_wayland_layer_shell_create(display))
        defer { cacao_wayland_layer_shell_destroy(shell) }
        var options = topBar()
        let surface = try "menubar".withCString { name in
            options.name_space = name
            return try #require(cacao_wayland_layer_surface_create(shell, wlSurface, &options, recordConfigure, recordClose, nil))
        }

        // The first size arrived before the surface was returned: the
        // screen's width, and the height asked for.
        #expect(configures.map(\.width) == [1280])
        #expect(configures.map(\.height) == [28])
        cacao_test_client_roundtrip(display)
        var state = cacao_test_server_layer_state(server)
        #expect(state.exists == 1)
        #expect(state.layer == CacaoLayerTop.rawValue)
        #expect(state.anchors == 1 | 4 | 8)
        #expect(state.exclusive_zone == 28)
        #expect([state.margin_top, state.margin_right, state.margin_bottom, state.margin_left] == [0, 4, 0, 4])
        #expect(state.width == 0)
        #expect(state.height == 28)
        #expect(state.keyboard_interactivity == 2)
        let name = withUnsafeBytes(of: state.name_space) { String(decoding: $0.prefix { $0 != 0 }, as: UTF8.self) }
        #expect(name == "menubar")
        #expect(state.acked_serial == state.configured_serial)

        // A later size, as when the screen changes, is acknowledged and
        // reported when the queue is dispatched.
        cacao_test_server_configure_layer(server, 1024, 32)
        for _ in 0..<100 where configures.count < 2 {
            cacao_test_client_roundtrip(display)
            cacao_wayland_layer_shell_dispatch(shell)
        }
        #expect(configures.last.map { [$0.width, $0.height] } == [1024, 32])
        cacao_test_client_roundtrip(display)
        state = cacao_test_server_layer_state(server)
        #expect(state.acked_serial == state.configured_serial)

        cacao_test_server_close_layer(server)
        for _ in 0..<100 where closes == 0 {
            cacao_test_client_roundtrip(display)
            cacao_wayland_layer_shell_dispatch(shell)
        }
        #expect(closes == 1)

        cacao_wayland_layer_surface_destroy(surface)
        cacao_test_client_roundtrip(display)
        #expect(cacao_test_server_layer_state(server).exists == 0)
    }

    @Test func compositorsWithoutLayerShellBindNothing() throws {
        let socket = "cacao-layer-none-\(getpid())"
        let server = try #require(cacao_test_server_start_with_layer_shell(socket, 0))
        defer { cacao_test_server_stop(server) }
        let display = try #require(cacao_test_client_connect(socket))
        defer { cacao_test_client_disconnect(display) }
        #expect(cacao_wayland_layer_shell_create(display) == nil)
        #expect(cacao_wayland_layer_shell_create(nil) == nil)
    }
}
#endif
