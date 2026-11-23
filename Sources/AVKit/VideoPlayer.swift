//
//  VideoPlayer.swift
//  AVKit
//
//  Created by Alsey Coleman Miller on 11/23/26.
//

import AVFoundation
import Cacao
import CacaoRender
import Foundation

/// A view that shows a player's pictures, fitted to it over black, with
/// controls to play, pause and move through the item.
public struct VideoPlayer<VideoOverlay: View>: View {

    private let player: AVPlayer?

    private let videoOverlay: VideoOverlay

    /// Creates a view that shows `player`'s pictures, with a view over
    /// them and under the controls.
    public init(player: AVPlayer?, @ViewBuilder videoOverlay: () -> VideoOverlay) {
        self.player = player
        self.videoOverlay = videoOverlay()
    }

    public var body: some View {
        ZStack {
            Color.black
            if let player {
                // State of its own for each player.
                PlayerContent(player: player, videoOverlay: videoOverlay)
                    .id(ObjectIdentifier(player))
            }
        }
    }
}

extension VideoPlayer where VideoOverlay == EmptyView {

    /// Creates a view that shows `player`'s pictures.
    public init(player: AVPlayer?) {
        self.init(player: player) { EmptyView() }
    }
}

/// Tells the view when its player changes, in place of key-value
/// observing: what's shown is read from the player itself.
internal final class PlayerModel: ObservableObject, @unchecked Sendable {

    let player: AVPlayer

    private var timeObserver: Any?

    private var changes: AnyObject?

    init(player: AVPlayer) {
        self.player = player
        let publisher = objectWillChange
        changes = player.observeChanges { publisher.send() }
        timeObserver = player.addPeriodicTimeObserver(
            forInterval: CMTime(value: 1, timescale: 4),
            queue: nil
        ) { _ in publisher.send() }
    }

    deinit {
        if let timeObserver { player.removeTimeObserver(timeObserver) }
    }

    var isPlaying: Bool { player.timeControlStatus != .paused }

    /// Where playback is, in seconds.
    var time: Double {
        let seconds = player.currentTime().seconds
        return seconds.isFinite ? max(seconds, 0) : 0
    }

    /// How long the item lasts, in seconds, when it says.
    var duration: Double? {
        guard let duration = player.currentItem?.duration, duration.isNumeric, duration > .zero else { return nil }
        return duration.seconds
    }

    /// The pictures' width over their height, once known.
    var aspectRatio: CGFloat? {
        guard let size = player.currentItem?.presentationSize, size.width > 0, size.height > 0 else { return nil }
        return size.width / size.height
    }

    func togglePlaying() {
        isPlaying ? player.pause() : player.play()
    }

    func seek(to seconds: Double) {
        player.seek(to: CMTime(seconds: seconds, preferredTimescale: 600))
    }
}

internal struct PlayerContent<VideoOverlay: View>: View {

    let videoOverlay: VideoOverlay

    @StateObject private var model: PlayerModel

    /// Where the slider is while it's dragged, in seconds.
    @State private var scrubbed: Double?

    init(player: AVPlayer, videoOverlay: VideoOverlay) {
        self.videoOverlay = videoOverlay
        self._model = StateObject(wrappedValue: PlayerModel(player: player))
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            if let aspectRatio = model.aspectRatio {
                ExternalSurfaceView(model.player.surface)
                    .aspectRatio(aspectRatio, contentMode: .fit)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            videoOverlay
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            controls
        }
    }

    private var controls: some View {
        HStack(spacing: 12) {
            Button {
                model.togglePlaying()
            } label: {
                Image(systemName: model.isPlaying ? "pause.fill" : "play.fill")
            }
            .buttonStyle(.plain)
            Text(VideoPlayerTime.text(scrubbed ?? model.time))
                .monospacedDigit()
            if let duration = model.duration {
                Slider(
                    value: Binding(
                        get: { min(scrubbed ?? model.time, duration) },
                        set: { seconds in
                            scrubbed = seconds
                            model.seek(to: seconds)
                        }
                    ),
                    in: 0...duration,
                    onEditingChanged: { editing in
                        if !editing { scrubbed = nil }
                    }
                )
                Text(VideoPlayerTime.text(duration))
                    .monospacedDigit()
            } else {
                Spacer()
            }
        }
        .font(.caption)
        .foregroundStyle(.white)
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color.black.opacity(0.5))
    }
}

internal enum VideoPlayerTime {

    /// Seconds as minutes and seconds, with hours from an hour on.
    static func text(_ seconds: Double) -> String {
        let total = seconds.isFinite ? Int(max(seconds, 0)) : 0
        let (hours, minutes, rest) = (total / 3600, total / 60 % 60, total % 60)
        let padded = { (value: Int) in value < 10 ? "0\(value)" : "\(value)" }
        return hours > 0 ? "\(hours):\(padded(minutes)):\(padded(rest))" : "\(minutes):\(padded(rest))"
    }
}
