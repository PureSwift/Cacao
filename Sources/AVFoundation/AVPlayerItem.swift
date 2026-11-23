//
//  AVPlayerItem.swift
//  AVFoundation
//
//  Created by Alsey Coleman Miller on 11/23/26.
//

import CoreMedia
import Foundation

/// An asset as a player plays it: whether it's ready, how long it lasts,
/// how large its pictures are, and where playback is.
///
/// An item is opened by the player it's given to, on the player's thread,
/// so its values are unknown until its `status` is `.readyToPlay`. They
/// may be read from any thread. There is no key-value observing here: a
/// player's periodic time observer, or the notifications below, tell when
/// they change.
public class AVPlayerItem: NSObject, @unchecked Sendable {

    public enum Status: Int, Hashable, Sendable {
        /// Not opened yet.
        case unknown = 0
        case readyToPlay = 1
        /// Couldn't be opened or decoded; see `error`.
        case failed = 2
    }

    /// Posted, with the item as its object, when the item has played to
    /// its end, from the player's thread.
    public static let didPlayToEndTimeNotification = Notification.Name("AVPlayerItemDidPlayToEndTimeNotification")

    /// Posted, with the item as its object, when the item stopped before
    /// its end because it couldn't be read or decoded.
    public static let failedToPlayToEndTimeNotification = Notification.Name("AVPlayerItemFailedToPlayToEndTimeNotification")

    public let asset: AVAsset

    /// What the player found, and where it is.
    package struct State {
        package var status = Status.unknown
        package var duration = CMTime.indefinite
        package var presentationSize = CGSize.zero
        package var error: Error?
        package var currentTime = CMTime.zero
    }

    private let lock = NSLock()

    private var state = State()

    /// The player that has it: an item plays in one player only.
    private var owner: ObjectIdentifier?

    public init(asset: AVAsset) {
        self.asset = asset
    }

    public convenience init(url: URL) {
        self.init(asset: AVURLAsset(url: url))
    }

    public var status: Status {
        read { $0.status }
    }

    /// How long the item lasts; indefinite before it's ready, and for a
    /// stream that doesn't say.
    public var duration: CMTime {
        read { $0.duration }
    }

    /// The size its pictures are shown at, in pixels, with square pixels;
    /// zero before it's ready, and without video.
    public var presentationSize: CGSize {
        read { $0.presentationSize }
    }

    /// Why it failed.
    public var error: Error? {
        read { $0.error }
    }

    /// Where playback is.
    public func currentTime() -> CMTime {
        read { $0.currentTime }
    }

    private func read<Value>(_ body: (State) -> Value) -> Value {
        lock.lock()
        defer { lock.unlock() }
        return body(state)
    }

    /// The player's: what it found, or where it is.
    package func update(_ body: (inout State) -> Void) {
        lock.lock()
        defer { lock.unlock() }
        body(&state)
    }

    /// The player's: takes the item, unless another player has it.
    package func claim(by player: ObjectIdentifier) -> Bool {
        lock.lock()
        defer { lock.unlock() }
        guard owner == nil || owner == player else { return false }
        owner = player
        return true
    }
}

extension Notification.Name {

    public static let AVPlayerItemDidPlayToEndTime = AVPlayerItem.didPlayToEndTimeNotification

    public static let AVPlayerItemFailedToPlayToEndTime = AVPlayerItem.failedToPlayToEndTimeNotification
}
