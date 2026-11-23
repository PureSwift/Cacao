import Foundation
import MediaCore
import MediaFiles
import PixelBuffers
import VideoCodec

/// A second of video in a Matroska file of its own: 30 pictures a second,
/// 64 by 32, each a flat gray whose luma is eight times its number.
final class Movie {

    let url: URL

    private let directory: URL

    init() throws {
        directory = FileManager.default.temporaryDirectory.appendingPathComponent("AVFoundationTests-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        url = directory.appendingPathComponent("movie.mkv")

        let encoder = try VideoEncoder(settings: VideoEncoder.Settings(
            codec: .mpeg4Video, width: 64, height: 32, timescale: 30, keyframeInterval: 5
        ))
        var samples: [SampleBuffer] = []
        for index in 0..<30 {
            let picture = PixelBuffer(width: 64, height: 32, format: .i420)
            picture.withMutablePlane(0) { luma in
                _ = luma.initializeMemory(as: UInt8.self, repeating: UInt8(index * 8))
            }
            samples += try encoder.encode(picture, presentationTime: MediaTime(value: Int64(index), timescale: 30), keyframe: index % 5 == 0)
        }
        samples += try encoder.finish()

        let writer = try MediaWriter(url: url.path)
        let track = try writer.addTrack(.video(encoder.format), timescale: 30)
        for sample in samples { try writer.write(sample, to: track) }
        try writer.finish()
    }

    deinit {
        try? FileManager.default.removeItem(at: directory)
    }

    /// The gray a picture is shown as: its luma, from video range.
    static func gray(ofFrame index: Int) -> Int {
        min(max((index * 8 - 16) * 255 / 219, 0), 255)
    }
}

/// A value several threads share.
final class Shared<Value>: @unchecked Sendable {

    private let lock = NSLock()

    private var stored: Value

    init(_ value: Value) {
        stored = value
    }

    var value: Value {
        lock.lock()
        defer { lock.unlock() }
        return stored
    }

    func update(_ body: (inout Value) -> Void) {
        lock.lock()
        defer { lock.unlock() }
        body(&stored)
    }
}

/// Waits until `condition` holds, and returns whether it did in time.
func eventually(
    isolation: isolated (any Actor)? = #isolation,
    within seconds: Double = 10,
    _ condition: () -> Bool
) async -> Bool {
    let end = Date(timeIntervalSinceNow: seconds)
    while !condition() {
        guard Date() < end else { return false }
        try? await Task.sleep(nanoseconds: 2_000_000)
    }
    return true
}
