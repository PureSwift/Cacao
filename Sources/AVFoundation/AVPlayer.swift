//
//  AVPlayer.swift
//  AVFoundation
//
//  Created by Alsey Coleman Miller on 11/23/26.
//

import CacaoRender
import CoreMedia
import Foundation

/// Plays an item: its pictures to a surface a `VideoPlayer` shows, in step
/// with its sound, which goes to SDL's default playback device.
///
/// The item is opened, read and decoded on a thread of the player's, so
/// nothing here waits for it, and all of it may be called from any thread.
/// There is no key-value observing: a periodic time observer tells where
/// playback is, and the item's notifications when it ends.
///
/// Unlike Apple's, an item plays at its own rate only, and `play` at its
/// end starts it again from the beginning.
public class AVPlayer: NSObject, @unchecked Sendable {

    public enum Status: Int, Hashable, Sendable {
        case unknown = 0
        case readyToPlay = 1
        case failed = 2
    }

    public enum TimeControlStatus: Int, Hashable, Sendable {
        case paused = 0
        /// Asked to play, with an item that isn't ready yet.
        case waitingToPlayAtSpecifiedRate = 1
        case playing = 2
    }

    public enum ActionAtItemEnd: Int, Hashable, Sendable {
        /// For a queue of items, which this player doesn't have: as `pause`.
        case advance = 0
        case pause = 1
        /// As `pause`: an item that has ended has nothing more to play.
        case none = 2
    }

    /// Where the item's pictures are published, for a view to show.
    package let surface = ExternalSurface()

    private let lock = NSLock()

    // Guarded by the lock.
    private var session: PlaybackSession?
    /// Whether to play, while there's no item to.
    private var wantsPlay = false
    private var endAction = ActionAtItemEnd.pause
    private var timeObservers: [TimeObserver] = []
    private var changeHandlers: [ObjectIdentifier: @Sendable () -> Void] = [:]

    /// Creates a player with no item.
    public override init() {
        super.init()
    }

    /// Creates a player for the media at `url`.
    public convenience init(url: URL) {
        self.init(playerItem: AVPlayerItem(url: url))
    }

    public init(playerItem item: AVPlayerItem?) {
        super.init()
        replaceCurrentItem(with: item)
    }

    deinit {
        session?.cancel()
    }

    // MARK: Item

    public var currentItem: AVPlayerItem? {
        locked { session?.item }
    }

    /// Plays `item` in place of the current one, or nothing. An item plays
    /// in one player only.
    public func replaceCurrentItem(with item: AVPlayerItem?) {
        if let item {
            precondition(item.claim(by: ObjectIdentifier(self)), "An AVPlayerItem cannot be associated with more than one instance of AVPlayer")
        }
        let (old, new): (PlaybackSession?, PlaybackSession?) = locked {
            guard session?.item !== item else { return (nil, nil) }
            let old = session
            let playing = old?.isPlayRequested ?? wantsPlay
            wantsPlay = playing
            session = item.map { PlaybackSession(item: $0, surface: surface, owner: self, wantsPlay: playing) }
            for index in timeObservers.indices { timeObservers[index].last = nil }
            return (old, session)
        }
        old?.cancel()
        if old != nil, new == nil {
            // Nothing to show: a clear pixel.
            withUnsafeBytes(of: UInt32(0)) { surface.publish(pixels: $0, width: 1, height: 1) }
        }
        new?.start()
        if old != nil || new != nil { notifyChange() }
    }

    /// Always ready: whether there's something to play is the item's
    /// `status`.
    public var status: Status { .readyToPlay }

    public var error: Error? { nil }

    // MARK: Playing

    public func play() {
        setPlaying(true)
    }

    public func pause() {
        setPlaying(false)
    }

    /// 1 while playing, or asked to, and 0 while paused. Any rate above
    /// zero plays at the item's own.
    public var rate: Float {
        get { isPlayRequested ? 1 : 0 }
        set { setPlaying(newValue > 0) }
    }

    public var timeControlStatus: TimeControlStatus {
        let (item, playing) = locked { (session?.item, session?.isPlayRequested ?? wantsPlay) }
        guard playing else { return .paused }
        return item?.status == .readyToPlay ? .playing : .waitingToPlayAtSpecifiedRate
    }

    /// What happens when the item ends: it pauses, whichever is set.
    public var actionAtItemEnd: ActionAtItemEnd {
        get { locked { endAction } }
        set { locked { endAction = newValue } }
    }

    private var isPlayRequested: Bool {
        locked { session?.isPlayRequested ?? wantsPlay }
    }

    private func setPlaying(_ playing: Bool) {
        let session: PlaybackSession? = locked {
            wantsPlay = playing
            return self.session
        }
        session?.setPlaying(playing)
        notifyChange()
    }

    // MARK: Time

    /// Where playback is; zero with no item.
    public func currentTime() -> CMTime {
        currentItem?.currentTime() ?? .zero
    }

    /// Moves to `time`, showing the picture then.
    public func seek(to time: CMTime) {
        seek(to: time) { _ in }
    }

    /// Moves to `time`, then calls the handler, on the player's thread,
    /// with whether it did: not when another seek came first, or with no
    /// item.
    public func seek(to time: CMTime, completionHandler: @escaping @Sendable (Bool) -> Void) {
        guard time.isNumeric, let session = locked({ self.session }) else {
            completionHandler(false)
            return
        }
        session.seek(to: time, handler: completionHandler)
    }

    /// Moves to `time`: exactly, whatever the tolerances.
    public func seek(to time: CMTime, toleranceBefore: CMTime, toleranceAfter: CMTime) {
        seek(to: time)
    }

    /// Moves to `time`: exactly, whatever the tolerances.
    public func seek(
        to time: CMTime,
        toleranceBefore: CMTime,
        toleranceAfter: CMTime,
        completionHandler: @escaping @Sendable (Bool) -> Void
    ) {
        seek(to: time, completionHandler: completionHandler)
    }

    /// Moves to `time`, and returns whether it did.
    @discardableResult
    public func seek(to time: CMTime) async -> Bool {
        await withCheckedContinuation { continuation in
            seek(to: time) { continuation.resume(returning: $0) }
        }
    }

    /// Moves to `time`, exactly, and returns whether it did.
    @discardableResult
    public func seek(to time: CMTime, toleranceBefore: CMTime, toleranceAfter: CMTime) async -> Bool {
        await seek(to: time)
    }

    // MARK: Observing time

    private struct TimeObserver {
        let token: TimeObserverToken
        let interval: CMTime
        let queue: DispatchQueue
        let block: @Sendable (CMTime) -> Void
        /// The time it was last told.
        var last: CMTime?
    }

    private final class TimeObserverToken: NSObject, @unchecked Sendable {}

    /// Calls `block` on `queue`, or the main queue, as playback passes each
    /// `interval`, and when it starts, stops or jumps. Returns what
    /// `removeTimeObserver` takes.
    public func addPeriodicTimeObserver(
        forInterval interval: CMTime,
        queue: DispatchQueue?,
        using block: @escaping @Sendable (CMTime) -> Void
    ) -> Any {
        let token = TimeObserverToken()
        locked {
            timeObservers.append(TimeObserver(token: token, interval: interval, queue: queue ?? .main, block: block))
        }
        return token
    }

    public func removeTimeObserver(_ observer: Any) {
        guard let token = observer as? TimeObserverToken else { return }
        locked { timeObservers.removeAll { $0.token === token } }
    }

    // MARK: The session's

    /// The item became ready, or failed.
    internal func sessionChanged(_ session: PlaybackSession) {
        guard locked({ self.session === session }) else { return }
        notifyChange()
    }

    /// Playback is at `time`, having started, stopped or been moved there
    /// when it's a jump.
    internal func sessionMoved(_ session: PlaybackSession, to time: CMTime, isJump: Bool) {
        let due: [TimeObserver]? = locked { () -> [TimeObserver]? in
            guard self.session === session else { return nil }
            var due: [TimeObserver] = []
            for index in timeObservers.indices {
                let observer = timeObservers[index]
                if !isJump, let last = observer.last, observer.interval.isNumeric {
                    let passed = time - last
                    guard passed >= observer.interval || passed < .zero else { continue }
                }
                timeObservers[index].last = time
                due.append(observer)
            }
            return due
        }
        guard let due else { return }
        for observer in due {
            observer.queue.async { observer.block(time) }
        }
        if isJump { notifyChange() }
    }

    // MARK: Changes

    /// Calls `handler`, on any thread, when the item, its status, or
    /// whether the player is playing changes, until the object returned
    /// goes away: what a view shows the player with, in place of key-value
    /// observing.
    package func observeChanges(_ handler: @escaping @Sendable () -> Void) -> AnyObject {
        let observation = ChangeObservation { [weak self] observation in
            guard let self else { return }
            self.locked { self.changeHandlers[ObjectIdentifier(observation)] = nil }
        }
        locked { changeHandlers[ObjectIdentifier(observation)] = handler }
        return observation
    }

    private final class ChangeObservation: @unchecked Sendable {

        private let remove: (ChangeObservation) -> Void

        init(remove: @escaping (ChangeObservation) -> Void) {
            self.remove = remove
        }

        deinit {
            remove(self)
        }
    }

    private func notifyChange() {
        let handlers = locked { Array(changeHandlers.values) }
        handlers.forEach { $0() }
    }

    private func locked<Result>(_ body: () -> Result) -> Result {
        lock.lock()
        defer { lock.unlock() }
        return body()
    }
}
