//
//  PrivateBus.swift
//  CacaoDBusTests
//

import DBus
import Foundation
#if canImport(Glibc)
import Glibc
#elseif canImport(Darwin)
import Darwin
#endif

/// A `dbus-daemon` of the tests' own on a Unix socket, so they never touch
/// the user's session bus.
///
/// - Note: Spawned with `posix_spawn`, as in PureSwift/DBus's own tests:
/// Foundation's `Process` only offers blocking ways to watch the child, and
/// blocking a cooperative thread from an async test deadlocks the run.
final class PrivateBus {

    /// Where `dbus-daemon` lives, or `nil` if it isn't installed.
    static let executablePath: String? = [
        "/usr/bin/dbus-daemon",
        "/opt/homebrew/bin/dbus-daemon",
        "/usr/local/bin/dbus-daemon",
    ].first { FileManager.default.isExecutableFile(atPath: $0) }

    static var isAvailable: Bool {
        executablePath != nil
    }

    let address: String

    private let directory: URL

    private let processID: pid_t

    /// Starts a bus and waits until it accepts connections.
    static func start() async throws -> PrivateBus {
        let bus = try PrivateBus()
        for _ in 0 ..< 50 {
            if let connection = try? await DBusConnection.connect(to: bus.address) {
                await connection.close()
                return bus
            }
            try await Task.sleep(for: .milliseconds(100))
        }
        bus.stop()
        throw PrivateBusError.notReady
    }

    private init() throws {
        guard let executable = Self.executablePath else {
            throw PrivateBusError.notInstalled
        }
        // Short, because a Unix socket path is limited to about 100 bytes.
        directory = URL(fileURLWithPath: "/tmp/cacao-bus-\(UInt32.random(in: 0 ... .max))")
        let socket = directory.appendingPathComponent("bus").path
        address = "unix:path=\(socket)"

        let configuration = """
            <!DOCTYPE busconfig PUBLIC "-//freedesktop//DTD D-Bus Bus Configuration 1.0//EN"
             "http://www.freedesktop.org/standards/dbus/1.0/busconfig.dtd">
            <busconfig>
              <type>session</type>
              <listen>\(address)</listen>
              <auth>EXTERNAL</auth>
              <policy context="default">
                <allow send_destination="*" eavesdrop="true"/>
                <allow eavesdrop="true"/>
                <allow own="*"/>
              </policy>
            </busconfig>
            """
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let configurationURL = directory.appendingPathComponent("bus.conf")
        try configuration.write(to: configurationURL, atomically: true, encoding: .utf8)

        guard let pid = Self.spawn([executable, "--config-file=\(configurationURL.path)", "--nofork", "--nopidfile"]) else {
            try? FileManager.default.removeItem(at: directory)
            throw PrivateBusError.notStarted
        }
        processID = pid
    }

    func stop() {
        // SIGKILL, because the daemon inherits the test runner's ignored
        // signals and stays alive after SIGTERM.
        kill(processID, SIGKILL)
        var status: Int32 = 0
        waitpid(processID, &status, 0)
        try? FileManager.default.removeItem(at: directory)
    }

    /// Launches a process with its output discarded.
    private static func spawn(_ arguments: [String]) -> pid_t? {
        #if canImport(Darwin)
        var fileActions: posix_spawn_file_actions_t?
        #else
        var fileActions = posix_spawn_file_actions_t()
        #endif
        posix_spawn_file_actions_init(&fileActions)
        defer { posix_spawn_file_actions_destroy(&fileActions) }
        posix_spawn_file_actions_addopen(&fileActions, 1, "/dev/null", O_WRONLY, 0)
        posix_spawn_file_actions_addopen(&fileActions, 2, "/dev/null", O_WRONLY, 0)

        var argv: [UnsafeMutablePointer<CChar>?] = arguments.map { strdup($0) }
        argv.append(nil)
        defer { argv.forEach { free($0) } }
        var envp: [UnsafeMutablePointer<CChar>?] = ProcessInfo.processInfo.environment
            .map { strdup("\($0.key)=\($0.value)") }
        envp.append(nil)
        defer { envp.forEach { free($0) } }

        var pid: pid_t = 0
        return posix_spawn(&pid, arguments[0], &fileActions, nil, argv, envp) == 0 ? pid : nil
    }
}

enum PrivateBusError: Error {
    case notInstalled
    case notStarted
    case notReady
}
