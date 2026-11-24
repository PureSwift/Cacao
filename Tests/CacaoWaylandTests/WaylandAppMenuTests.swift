//
//  WaylandAppMenuTests.swift
//  Cacao
//
//  Ties a surface to a menu's D-Bus address against a test compositor, and
//  checks the address it heard.
//

#if os(Linux)
import Foundation
import Testing
import CacaoWayland
import CacaoWaylandTestServer

@Suite(.serialized) struct WaylandAppMenuTests {

    init() throws {
        // Wayland sockets live in the runtime directory.
        if ProcessInfo.processInfo.environment["XDG_RUNTIME_DIR"] == nil {
            let directory = FileManager.default.temporaryDirectory.appendingPathComponent("cacao-xdg-\(getpid())")
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true, attributes: [.posixPermissions: 0o700])
            setenv("XDG_RUNTIME_DIR", directory.path, 1)
        }
    }

    private func address(of state: CacaoTestAppMenuState) -> (service: String, path: String) {
        var state = state
        let service = withUnsafeBytes(of: &state.service_name) { String(cString: $0.bindMemory(to: CChar.self).baseAddress!) }
        let path = withUnsafeBytes(of: &state.object_path) { String(cString: $0.bindMemory(to: CChar.self).baseAddress!) }
        return (service, path)
    }

    @Test func surfacesAreTiedToTheirMenus() throws {
        let socket = "cacao-appmenu-test-\(getpid())"
        let server = try #require(cacao_test_server_start_with_features(socket, CacaoTestServerFeatureAppMenu.rawValue))
        defer { cacao_test_server_stop(server) }
        let display = try #require(cacao_test_client_connect(socket))
        defer { cacao_test_client_disconnect(display) }
        let surface = try #require(cacao_test_client_create_surface(display))

        let manager = try #require(cacao_wayland_appmenu_manager_create(display))
        defer { cacao_wayland_appmenu_manager_destroy(manager) }
        let menu = try #require(cacao_wayland_appmenu_create(manager, surface, ":1.42", "/MenuBar"))
        cacao_test_client_roundtrip(display)
        var state = cacao_test_server_appmenu_state(server)
        #expect(state.exists == 1)
        #expect(state.is_for_surface == 1)
        #expect(state.addresses_set == 1)
        #expect(address(of: state).service == ":1.42")
        #expect(address(of: state).path == "/MenuBar")

        // Moved, as when the app gets its well-known name.
        cacao_wayland_appmenu_set_address(menu, "org.example.Notes", "/MenuBar/1")
        cacao_test_client_roundtrip(display)
        state = cacao_test_server_appmenu_state(server)
        #expect(state.addresses_set == 2)
        #expect(address(of: state).service == "org.example.Notes")
        #expect(address(of: state).path == "/MenuBar/1")

        // Untied.
        cacao_wayland_appmenu_destroy(menu)
        cacao_test_client_roundtrip(display)
        #expect(cacao_test_server_appmenu_state(server).exists == 0)
    }

    @Test func withoutTheProtocolThereIsNoManager() throws {
        let socket = "cacao-appmenu-none-\(getpid())"
        let server = try #require(cacao_test_server_start(socket))
        defer { cacao_test_server_stop(server) }
        let display = try #require(cacao_test_client_connect(socket))
        defer { cacao_test_client_disconnect(display) }
        #expect(cacao_wayland_appmenu_manager_create(display) == nil)
    }
}
#endif
