import AVFoundation
import CacaoRender
import Testing

/// Plays a second of gray pictures, each lighter than the last, and reads
/// what the player publishes to its surface.
@Suite(.serialized) struct AVPlayerTests {

    /// The gray of the frame on the player's surface, from its middle
    /// pixel, and the frame's size.
    private func shown(_ player: AVPlayer) -> (gray: Int, width: Int, height: Int)? {
        guard let frame = player.surface.takeFrame(), frame.width > 1 else { return nil }
        let offset = frame.height / 2 * frame.bytesPerRow + frame.width / 2 * 4
        #expect(frame.format == .bgra)
        #expect(frame.rowOrder == .topFirst)
        #expect(frame.isOpaque)
        return (Int(frame.pixels[frame.pixels.startIndex + offset + 1]), frame.width, frame.height)
    }

    private func near(_ value: Int?, _ expected: Int, within tolerance: Int = 8) -> Bool {
        value.map { abs($0 - expected) <= tolerance } ?? false
    }

    @Test func anItemIsOpenedAndItsFirstPictureShown() async throws {
        let movie = try Movie()
        let item = AVPlayerItem(url: movie.url)
        #expect(item.status == .unknown)
        #expect(item.duration.isIndefinite)
        #expect((item.asset as? AVURLAsset)?.url == movie.url)

        let player = AVPlayer(playerItem: item)
        #expect(player.currentItem === item)
        #expect(await eventually { item.status == .readyToPlay && player.surface.hasNewFrame })
        #expect(abs(item.duration.seconds - 1) < 0.05)
        #expect(item.presentationSize == CGSize(width: 64, height: 32))
        #expect(item.error == nil)
        #expect(player.status == .readyToPlay)
        #expect(player.timeControlStatus == .paused)
        #expect(player.rate == 0)
        #expect(player.currentTime() == .zero)

        let frame = shown(player)
        #expect(frame?.width == 64)
        #expect(frame?.height == 32)
        #expect(near(frame?.gray, Movie.gray(ofFrame: 0)))
    }

    @Test func itPlaysToTheEndAndTellsItsObservers() async throws {
        let movie = try Movie()
        let player = AVPlayer(url: movie.url)
        let item = try #require(player.currentItem)

        let ended = Shared(0)
        let observer = NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime, object: item, queue: nil
        ) { _ in ended.update { $0 += 1 } }
        defer { NotificationCenter.default.removeObserver(observer) }
        let times = Shared([Double]())
        let queue = DispatchQueue(label: "AVPlayerTests")
        let token = player.addPeriodicTimeObserver(forInterval: CMTime(value: 1, timescale: 10), queue: queue) { time in
            times.update { $0.append(time.seconds) }
        }

        player.play()
        #expect(player.rate == 1)
        #expect(player.timeControlStatus != .paused)
        #expect(await eventually { item.status == .readyToPlay })
        #expect(player.timeControlStatus == .playing || ended.value == 1)
        #expect(await eventually { ended.value == 1 })

        #expect(player.rate == 0)
        #expect(player.timeControlStatus == .paused)
        #expect(abs(player.currentTime().seconds - 1) < 0.1)
        #expect(near(shown(player)?.gray, Movie.gray(ofFrame: 29)))
        // A tenth of a second apart, and at the start and the end.
        queue.sync {}
        let told = times.value
        #expect(told.count >= 8 && told.count <= 16, "\(told)")
        #expect(told == told.sorted())
        #expect(told.first.map { $0 < 0.1 } ?? false)
        #expect(told.last.map { $0 > 0.9 } ?? false)

        // Nothing more once it's removed.
        player.removeTimeObserver(token)
        #expect(await player.seek(to: CMTime(value: 1, timescale: 2)))
        queue.sync {}
        #expect(times.value.count == told.count)
        #expect(ended.value == 1)
    }

    @Test func itSeeksWhilePaused() async throws {
        let movie = try Movie()
        let player = AVPlayer(url: movie.url)
        // Before the item is ready, too.
        #expect(await player.seek(to: CMTime(value: 15, timescale: 30)))
        #expect(abs(player.currentTime().seconds - 0.5) < 0.01)
        #expect(player.timeControlStatus == .paused)
        #expect(near(shown(player)?.gray, Movie.gray(ofFrame: 15)))

        #expect(await player.seek(to: CMTime(value: 5, timescale: 30), toleranceBefore: .zero, toleranceAfter: .zero))
        #expect(near(shown(player)?.gray, Movie.gray(ofFrame: 5)))
        #expect(await !player.seek(to: .invalid))
    }

    @Test func itPlaysOnFromASeekAndPauses() async throws {
        let movie = try Movie()
        let player = AVPlayer(url: movie.url)
        #expect(await player.seek(to: CMTime(value: 1, timescale: 2)))
        player.play()
        #expect(await eventually { player.currentTime().seconds > 0.6 })
        player.pause()
        #expect(player.rate == 0)
        #expect(player.timeControlStatus == .paused)
        // A seek is made in turn, so the pause before it has been by now.
        #expect(await player.seek(to: player.currentTime()))
        let paused = player.currentTime()
        try await Task.sleep(nanoseconds: 100_000_000)
        #expect(player.currentTime() == paused)
        #expect(paused.seconds < 1)
    }

    @Test func anItemThatCannotBeOpenedFails() async throws {
        let item = AVPlayerItem(url: URL(fileURLWithPath: "/nonexistent/movie.mkv"))
        let player = AVPlayer(playerItem: item)
        player.play()
        #expect(await eventually { item.status == .failed })
        #expect(item.error != nil)
        #expect(await eventually { player.timeControlStatus == .paused })
        #expect(await !player.seek(to: .zero))
        #expect(!player.surface.hasNewFrame)
    }

    @Test func anItemIsReplaced() async throws {
        let movie = try Movie()
        let player = AVPlayer()
        #expect(player.currentItem == nil)
        #expect(await !player.seek(to: .zero))
        player.play()
        #expect(player.timeControlStatus == .waitingToPlayAtSpecifiedRate)
        player.pause()

        let changes = Shared(0)
        let observation = player.observeChanges { changes.update { $0 += 1 } }
        let item = AVPlayerItem(url: movie.url)
        player.replaceCurrentItem(with: item)
        #expect(player.currentItem === item)
        #expect(await eventually { item.status == .readyToPlay && player.surface.hasNewFrame })
        #expect(shown(player)?.width == 64)
        #expect(await eventually { changes.value >= 2 })

        player.replaceCurrentItem(with: nil)
        #expect(player.currentItem == nil)
        #expect(player.currentTime() == .zero)
        // A clear pixel in place of the last picture.
        #expect(player.surface.pixelSize == CGSize(width: 1, height: 1))
        #expect(!player.surface.isOpaque)
        _ = observation
    }
}
