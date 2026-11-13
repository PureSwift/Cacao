import Foundation
#if canImport(CoreGraphics)
import CoreGraphics
#endif
import Testing
@testable import Cacao
@testable import CacaoCompositor

/// A backend that records what the compositor asks of it.
@MainActor
final class RecordingBackend: CompositorBackend {

    enum Command: Equatable {
        case fill(CGRect)
        case draw(TextureID, CGRect)
        case clip(CGRect?)
    }

    var commands: [Command] = []

    var liveTextures: Set<TextureID> = []

    private var next = 0

    func makeTexture(width: Int, height: Int, bytesPerRow: Int, pixels: Data) -> TextureID? {
        next += 1
        let texture = TextureID(rawValue: next)
        liveTextures.insert(texture)
        return texture
    }

    func destroyTexture(_ texture: TextureID) {
        liveTextures.remove(texture)
    }

    func beginFrame(width: Int, height: Int, clearColor: Color.Resolved) {
        commands.removeAll()
    }

    func fill(_ rect: CGRect, color: Color.Resolved) {
        commands.append(.fill(rect))
    }

    func draw(_ texture: TextureID, in rect: CGRect, opacity: Double, smooth: Bool) {
        commands.append(.draw(texture, rect))
    }

    func setClip(_ rect: CGRect?) {
        commands.append(.clip(rect))
    }

    func endFrame() { }
}

@MainActor
@Suite struct CompositorTests {

    struct Rows: View {
        var body: some View {
            ScrollView {
                VStack(spacing: 0) {
                    ForEach(0..<200) { index in
                        Text("Row \(index)")
                            .frame(maxWidth: .infinity, minHeight: 40)
                    }
                }
            }
        }
    }

    private func make<V: View>(_ view: V, size: CGSize = CGSize(width: 300, height: 400)) -> (ViewGraph, Compositor, RecordingBackend) {
        let engine = SilicaTextEngine()
        let backend = RecordingBackend()
        let compositor = Compositor(backend: backend, textEngine: engine)
        let graph = ViewGraph(rootView: view, textEngine: engine)
        graph.layout(in: size)
        return (graph, compositor, backend)
    }

    @Test func onlyVisibleContentIsRasterized() {
        let (graph, compositor, _) = make(Rows())
        compositor.render(graph.displayList(), size: graph.size, scale: 2)
        // 400 points of 40 point rows: 10 rows visible, of 200.
        #expect(compositor.lastFrame.rasterizations == 10)
    }

    @Test func redrawingUnchangedContentRasterizesNothing() {
        let (graph, compositor, _) = make(Rows())
        compositor.render(graph.displayList(), size: graph.size, scale: 2)
        compositor.render(graph.displayList(), size: graph.size, scale: 2)
        #expect(compositor.lastFrame.rasterizations == 0)
        #expect(compositor.lastFrame.uploads == 0)
    }

    /// Scrolling within content that was drawn before reuses its textures:
    /// no layout, no evaluation, no rasterization and no uploads.
    @Test func scrollingRasterizesNothingAlreadyDrawn() throws {
        let (graph, compositor, _) = make(Rows())
        let point = CGPoint(x: 150, y: 200)
        compositor.render(graph.displayList(), size: graph.size, scale: 2)
        // Expose rows 10 to 19 once.
        graph.scroll(by: CGSize(width: 0, height: 400), at: point)
        compositor.render(graph.displayList(), size: graph.size, scale: 2)
        #expect(compositor.lastFrame.rasterizations == 10)
        let statistics = graph.statistics
        // Then scroll around within rows 0 to 19, a point at a time.
        for step in 0..<400 {
            graph.scroll(by: CGSize(width: 0, height: step < 200 ? -2 : 2), at: point)
            compositor.render(graph.displayList(), size: graph.size, scale: 2)
            #expect(compositor.lastFrame.rasterizations == 0)
            #expect(compositor.lastFrame.uploads == 0)
        }
        #expect(graph.statistics == statistics)
    }

    @Test func scrolledContentIsClippedAndMoved() throws {
        let (graph, compositor, backend) = make(
            ScrollView {
                VStack(spacing: 0) {
                    Color.red.frame(width: 100, height: 100)
                    Color.blue.frame(width: 100, height: 100)
                }
            }
            .frame(width: 100, height: 100),
            size: CGSize(width: 100, height: 100)
        )
        graph.scroll(by: CGSize(width: 0, height: 30), at: CGPoint(x: 50, y: 50))
        compositor.render(graph.displayList(), size: graph.size, scale: 1)
        #expect(backend.commands.first == .clip(rect(0, 0, 100, 100)))
        #expect(backend.commands.contains(.fill(rect(0, -30, 100, 100))))
        #expect(backend.commands.contains(.fill(rect(0, 70, 100, 100))))
    }

    @Test func changedContentIsRasterizedAgain() {
        struct Counter: View {
            let count: Int
            var body: some View {
                VStack {
                    Text("Title")
                    Text("Count \(count)")
                }
            }
        }
        let (graph, compositor, backend) = make(Counter(count: 0))
        compositor.render(graph.displayList(), size: graph.size, scale: 1)
        #expect(compositor.lastFrame.rasterizations == 2)
        graph.setRootView(Counter(count: 1))
        graph.layout(in: graph.size)
        compositor.render(graph.displayList(), size: graph.size, scale: 1)
        // Only the text that changed is drawn again.
        #expect(compositor.lastFrame.rasterizations == 1)
        #expect(backend.liveTextures.count == 2)
    }

    @Test func removedContentReleasesTextures() {
        struct Toggle: View {
            let show: Bool
            var body: some View {
                VStack {
                    Text("Always")
                    if show { Text("Sometimes") }
                }
            }
        }
        let (graph, compositor, backend) = make(Toggle(show: true))
        compositor.render(graph.displayList(), size: graph.size, scale: 1)
        #expect(backend.liveTextures.count == 2)
        graph.setRootView(Toggle(show: false))
        graph.layout(in: graph.size)
        compositor.render(graph.displayList(), size: graph.size, scale: 1)
        #expect(backend.liveTextures.count == 1)
    }

    @Test func strokedShapesDrawOutsideTheirFrame() {
        let (graph, compositor, backend) = make(
            Circle().stroke(.red, lineWidth: 4).frame(width: 50, height: 50),
            size: CGSize(width: 100, height: 100)
        )
        compositor.render(graph.displayList(), size: graph.size, scale: 1)
        let draws = backend.commands.compactMap { command -> CGRect? in
            if case let .draw(_, rect) = command { return rect }
            return nil
        }
        // Half the line width plus a pixel, doubled for a mitered join.
        #expect(draws == [rect(20, 20, 60, 60)])
    }
}

func rect(_ x: CGFloat, _ y: CGFloat, _ width: CGFloat, _ height: CGFloat) -> CGRect {
    CGRect(x: x, y: y, width: width, height: height)
}
