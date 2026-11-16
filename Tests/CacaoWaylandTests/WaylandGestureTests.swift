//
//  WaylandGestureTests.swift
//  Cacao
//
//  Binds Cacao's Wayland pinch gestures against a test compositor, and
//  checks the rotations they report.
//

#if os(Linux)
import Foundation
import Testing
import CacaoWayland
import CacaoWaylandTestServer

/// The pinch events received, as phase, surface address and rotation.
nonisolated(unsafe) private var received: [(phase: CacaoPinchPhase, surface: UInt, rotation: Double)] = []

private let record: CacaoPinchCallback = { _, phase, surface, rotation, _ in
    received.append((phase, UInt(bitPattern: surface), rotation))
}

@Suite(.serialized) struct WaylandGestureTests {

    init() throws {
        // Wayland sockets live in the runtime directory.
        if ProcessInfo.processInfo.environment["XDG_RUNTIME_DIR"] == nil {
            let directory = FileManager.default.temporaryDirectory.appendingPathComponent("cacao-xdg-\(getpid())")
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true, attributes: [.posixPermissions: 0o700])
            setenv("XDG_RUNTIME_DIR", directory.path, 1)
        }
        received = []
    }

    @Test func pinchesReportTheirRotation() throws {
        let socket = "cacao-test-\(getpid())"
        let server = try #require(cacao_test_server_start(socket))
        defer { cacao_test_server_stop(server) }
        let display = try #require(cacao_test_client_connect(socket))
        defer { cacao_test_client_disconnect(display) }
        let surface = try #require(cacao_test_client_create_surface(display))

        let gestures = try #require(cacao_wayland_gestures_create(display, record, nil))
        defer { cacao_wayland_gestures_destroy(gestures) }
        cacao_test_client_roundtrip(display)

        let rotations = [5.0, -2.5, 10.0]
        cacao_test_server_pinch(server, rotations, Int32(rotations.count))
        // Reading the connection queues the gesture events; dispatching
        // calls back.
        for _ in 0..<100 where !received.contains(where: { $0.phase == CacaoPinchPhaseEnded }) {
            cacao_test_client_roundtrip(display)
            cacao_wayland_gestures_dispatch(gestures)
        }
        #expect(received.map(\.phase) == [CacaoPinchPhaseBegan, CacaoPinchPhaseChanged, CacaoPinchPhaseChanged, CacaoPinchPhaseChanged, CacaoPinchPhaseEnded])
        #expect(received.map(\.rotation) == [0, 5, -2.5, 10, 0])
        #expect(received.allSatisfy { $0.surface == UInt(bitPattern: surface) })
    }

    @Test func compositorsWithoutGesturesBindNothing() {
        #expect(cacao_wayland_gestures_create(nil, record, nil) == nil)
    }
}
#endif
