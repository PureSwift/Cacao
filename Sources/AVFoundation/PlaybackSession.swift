//
//  PlaybackSession.swift
//  AVFoundation
//
//  Created by Alsey Coleman Miller on 11/23/26.
//

import CacaoRender
import CoreMedia
import Foundation
import MediaCore
import MediaPlayback
import MediaSDL
import PixelBuffers
import VideoCodec

/// One item playing in a player: a thread that opens the item, decodes it,
/// keeps its pictures in step with its sound, and publishes each picture,
/// converted to BGRA, to the player's surface.
///
/// The player tells it what to do from any thread; everything of
/// PureSwift/Media's is made and used on the session's thread only.
internal final class PlaybackSession: @unchecked Sendable {

    typealias SeekHandler = @Sendable (Bool) -> Void

    let item: AVPlayerItem

    private let surface: ExternalSurface

    /// The player, told what happens.
    private weak var owner: AVPlayer?

    private let condition = NSCondition()

    // Guarded by the condition.
    private var isCancelled = false
    private var wantsPlay: Bool
    private var seeks: [(time: CMTime, handler: SeekHandler?)] = []

    /// How long the thread sleeps between looks at the clock while playing.
    private static let tick: TimeInterval = 0.004

    init(item: AVPlayerItem, surface: ExternalSurface, owner: AVPlayer, wantsPlay: Bool) {
        self.item = item
        self.surface = surface
        self.owner = owner
        self.wantsPlay = wantsPlay
    }

    func start() {
        let thread = Thread { [self] in run() }
        thread.name = "AVPlayer"
        thread.start()
    }

    // MARK: The player's

    /// Whether it's playing, or will once it's ready: not after its end,
    /// or once it failed.
    var isPlayRequested: Bool {
        condition.lock()
        defer { condition.unlock() }
        return wantsPlay
    }

    func setPlaying(_ playing: Bool) {
        condition.lock()
        if !isCancelled {
            wantsPlay = playing
            condition.signal()
        }
        condition.unlock()
    }

    func seek(to time: CMTime, handler: SeekHandler?) {
        condition.lock()
        let cancelled = isCancelled
        if !cancelled {
            seeks.append((time, handler))
            condition.signal()
        }
        condition.unlock()
        if cancelled { handler?(false) }
    }

    /// Stops the thread, and the sound with it.
    func cancel() {
        condition.lock()
        isCancelled = true
        condition.signal()
        condition.unlock()
    }

    // MARK: The thread's

    /// A player for the media, with sound through SDL where there's a
    /// device for it, and silent where there isn't.
    private static func open(_ url: URL) throws -> Player {
        let location = url.isFileURL ? url.path : url.absoluteString
        if let output = try? SDLAudioOutput(), let player = try? Player(url: location, audioOutput: output) {
            return player
        }
        return try Player(url: location)
    }

    private func run() {
        let player: Player
        do {
            player = try PlaybackSession.open(item.asset.location)
        } catch {
            fail(error)
            return
        }
        let converter = try? PixelConverter(to: .bgra8)
        var size = CGSize.zero
        if case .video(let format)? = player.videoTrack?.format {
            let (horizontal, vertical) = format.pixelAspectRatio
            let widen = horizontal > 0 && vertical > 0 ? CGFloat(horizontal) / CGFloat(vertical) : 1
            size = CGSize(width: (CGFloat(format.width) * widen).rounded(), height: CGFloat(format.height))
        }
        item.update { state in
            state.status = .readyToPlay
            state.duration = player.duration.isNumeric ? player.duration : .indefinite
            state.presentationSize = size
        }
        owner?.sessionChanged(self)

        var shown: PixelBuffer?
        var isPlaying = false
        // The first pass shows the first picture, paused.
        var isSettled = false
        while true {
            condition.lock()
            while !isCancelled, seeks.isEmpty, !wantsPlay, !isPlaying, isSettled {
                condition.wait()
            }
            if !isCancelled, seeks.isEmpty, wantsPlay, isPlaying {
                _ = condition.wait(until: Date(timeIntervalSinceNow: PlaybackSession.tick))
            }
            let cancelled = isCancelled
            let pending = seeks
            seeks = []
            let wants = wantsPlay
            condition.unlock()
            guard !cancelled else {
                pending.forEach { $0.handler?(false) }
                break
            }

            // Only the last of several seeks is made.
            pending.dropLast().forEach { $0.handler?(false) }
            if let seek = pending.last {
                player.seek(to: seek.time)
            }
            let changed = wants != isPlaying
            if changed {
                wants ? player.play() : player.pause()
                isPlaying = wants
            }
            do {
                try player.update()
            } catch {
                pending.last?.handler?(false)
                fail(error)
                NotificationCenter.default.post(name: AVPlayerItem.failedToPlayToEndTimeNotification, object: item)
                break
            }
            if let picture = player.picture?.image as? PixelBuffer, picture !== shown {
                publish(picture, with: converter)
                shown = picture
            }
            let now = player.currentTime
            item.update { $0.currentTime = now }
            pending.last?.handler?(true)

            let ended = isPlaying && player.state == .ended
            if ended {
                isPlaying = false
                condition.lock()
                wantsPlay = false
                condition.unlock()
            }
            owner?.sessionMoved(self, to: now, isJump: changed || ended || !pending.isEmpty)
            if ended {
                NotificationCenter.default.post(name: AVPlayerItem.didPlayToEndTimeNotification, object: item)
            }
            isSettled = true
        }
        player.pause()
    }

    private func publish(_ picture: PixelBuffer, with converter: PixelConverter?) {
        guard let converter, let converted = try? converter.convert(picture) else { return }
        converted.withPlane(0) { pixels in
            surface.publish(
                pixels: pixels,
                width: converted.width,
                height: converted.height,
                bytesPerRow: converted.planes[0].bytesPerRow,
                format: .bgra,
                rowOrder: .topFirst,
                isOpaque: true
            )
        }
    }

    /// The item can't be played, or can't go on.
    private func fail(_ error: Error) {
        item.update { state in
            state.status = .failed
            state.error = error
        }
        condition.lock()
        isCancelled = true
        wantsPlay = false
        let pending = seeks
        seeks = []
        condition.unlock()
        pending.forEach { $0.handler?(false) }
        owner?.sessionChanged(self)
    }
}
