import CacaoRender
import Testing
@testable import AVKit
@testable import Cacao

/// The view that shows a player's surface.
@MainActor
@Suite(.serialized) struct VideoPlayerTests {

    /// The frames of the items that show `surface`, at any depth.
    private func frames(of surface: ExternalSurface, in list: DisplayList) -> [CGRect] {
        list.items.flatMap { item -> [CGRect] in
            switch item.value {
            case .content(.external(let content)):
                return content.surface === surface ? [item.frame] : []
            case .content:
                return []
            case .effect(_, let nested):
                return frames(of: surface, in: nested)
            }
        }
    }

    @Test func thePicturesAreFittedToTheView() async throws {
        let movie = try Movie()
        let player = AVPlayer(url: movie.url)
        #expect(await eventually { player.currentItem?.status == .readyToPlay })

        let graph = ViewGraph(rootView: VideoPlayer(player: player), textEngine: FixedTextEngine())
        graph.layout(in: CGSize(width: 400, height: 400))
        // 64 by 32, as wide as the view.
        #expect(frames(of: player.surface, in: graph.displayList()).map(\.size) == [CGSize(width: 400, height: 200)])
    }

    @Test func theViewShowsThePicturesOnceTheirSizeIsKnown() async throws {
        let movie = try Movie()
        let player = AVPlayer()
        let graph = ViewGraph(rootView: VideoPlayer(player: player) { Text("Overlay") }, textEngine: FixedTextEngine())
        graph.layout(in: CGSize(width: 300, height: 300))
        #expect(frames(of: player.surface, in: graph.displayList()).isEmpty)

        player.replaceCurrentItem(with: AVPlayerItem(url: movie.url))
        #expect(await eventually {
            if graph.needsUpdate { graph.update() }
            graph.layout(in: CGSize(width: 300, height: 300))
            return frames(of: player.surface, in: graph.displayList()).map(\.size) == [CGSize(width: 300, height: 150)]
        })
    }

    @Test func noPlayerShowsNothing() {
        let graph = ViewGraph(rootView: VideoPlayer(player: nil), textEngine: FixedTextEngine())
        graph.layout(in: CGSize(width: 100, height: 100))
        #expect(!graph.displayList().items.isEmpty)
    }

    @Test func timesAreWrittenAsMinutesAndSeconds() {
        #expect(VideoPlayerTime.text(0) == "0:00")
        #expect(VideoPlayerTime.text(59.9) == "0:59")
        #expect(VideoPlayerTime.text(75) == "1:15")
        #expect(VideoPlayerTime.text(3725) == "1:02:05")
        #expect(VideoPlayerTime.text(.nan) == "0:00")
    }

    @Test func theModelReadsThePlayer() async throws {
        let movie = try Movie()
        let player = AVPlayer(url: movie.url)
        let model = PlayerModel(player: player)
        let changes = Shared(0)
        let subscription = model.objectWillChange.subscribe { changes.update { $0 += 1 } }
        #expect(await eventually { model.duration != nil })
        #expect(model.aspectRatio == 2)
        #expect(!model.isPlaying)
        model.seek(to: 0.5)
        #expect(await eventually { model.time == 0.5 })
        model.togglePlaying()
        #expect(model.isPlaying)
        model.togglePlaying()
        #expect(!model.isPlaying)
        #expect(changes.value >= 3)
        _ = subscription
    }
}
