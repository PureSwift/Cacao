// The part of DarwinHost the renderer uses: its logger.
#if canImport(os)
import os

public enum AppHost {
    public static let logger = Logger(subsystem: "DarwinUIOnCacao", category: "renderer")
}
#else
/// A logger that takes OSLog-style interpolations, for Linux.
public struct HostLogger: Sendable {

    public struct Message: ExpressibleByStringInterpolation, Sendable {
        public struct StringInterpolation: StringInterpolationProtocol {
            var output = ""
            public init(literalCapacity: Int, interpolationCount: Int) { }
            public mutating func appendLiteral(_ literal: String) { output += literal }
            public mutating func appendInterpolation<T>(_ value: T, privacy: Privacy = .auto) { output += "\(value)" }
        }
        let text: String
        public init(stringLiteral value: String) { text = value }
        public init(stringInterpolation: StringInterpolation) { text = stringInterpolation.output }
    }

    public enum Privacy: Sendable { case auto, `public`, `private` }

    public func notice(_ message: Message) { print("notice: \(message.text)") }
    public func error(_ message: Message) { print("error: \(message.text)") }
    public func debug(_ message: Message) { }
}

public enum AppHost {
    public static let logger = HostLogger()
}
#endif

import Foundation

/// The app's bundle, whose resources images load from.
public enum DarwinBundle {
    public static var bundle: Bundle { .main }
}
