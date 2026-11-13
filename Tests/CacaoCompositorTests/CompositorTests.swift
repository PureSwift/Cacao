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
        case beginLayer(TextureID)
        case endLayer
        case drawLayer(TextureID, CGRect, Double, masked: Bool)
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

    func makeLayer(width: Int, height: Int) -> TextureID? {
        next += 1
        let texture = TextureID(rawValue: next)
        liveTextures.insert(texture)
        return texture
    }

    func destroyTexture(_ texture: TextureID) {
        liveTextures.remove(texture)
    }

    func beginLayer(_ layer: TextureID) {
        commands.append(.beginLayer(layer))
    }

    func endLayer() {
        commands.append(.endLayer)
    }

    func drawLayer(_ layer: TextureID, in rect: CGRect, opacity: Double, mask: [CGPoint]?) {
        commands.append(.drawLayer(layer, rect, opacity, masked: mask != nil))
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

@MainActor
@Suite struct CompositorEffectTests {

    private func make<V: View>(_ view: V, size: CGSize = CGSize(width: 200, height: 200)) -> (ViewGraph, Compositor, RecordingBackend) {
        let engine = SilicaTextEngine()
        let backend = RecordingBackend()
        let compositor = Compositor(backend: backend, textEngine: engine)
        let graph = ViewGraph(rootView: view, textEngine: engine)
        graph.layout(in: size)
        return (graph, compositor, backend)
    }

    private func layerDraws(_ backend: RecordingBackend) -> [(CGRect, Double, Bool)] {
        backend.commands.compactMap { command in
            if case let .drawLayer(_, rect, opacity, masked) = command { return (rect, opacity, masked) }
            return nil
        }
    }

    @Test func groupOpacityUsesALayer() {
        let (graph, compositor, backend) = make(
            ZStack {
                Color.red.frame(width: 60, height: 60)
                Color.blue.frame(width: 40, height: 40)
            }
            .opacity(0.5)
        )
        compositor.render(graph.displayList(), size: graph.size, scale: 1)
        let layers = layerDraws(backend)
        #expect(layers.count == 1)
        #expect(layers.first?.0 == rect(70, 70, 60, 60))
        #expect(layers.first?.1 == 0.5)
    }

    @Test func singleItemOpacityNeedsNoLayer() {
        let (graph, compositor, backend) = make(Color.red.frame(width: 60, height: 60).opacity(0.5))
        compositor.render(graph.displayList(), size: graph.size, scale: 1)
        #expect(layerDraws(backend).isEmpty)
    }

    @Test func roundedClipUsesAMaskedLayer() {
        let (graph, compositor, backend) = make(
            Color.red.frame(width: 80, height: 80).clipShape(RoundedRectangle(cornerRadius: 12))
        )
        compositor.render(graph.displayList(), size: graph.size, scale: 1)
        let layers = layerDraws(backend)
        #expect(layers.count == 1)
        #expect(layers.first?.2 == true)
        // Drawing again reuses the layer and rasterizes nothing.
        compositor.render(graph.displayList(), size: graph.size, scale: 1)
        #expect(compositor.lastFrame.rasterizations == 0)
        #expect(compositor.lastFrame.uploads == 0)
    }

    @Test func rectangularClipUsesTheClipRect() {
        let (graph, compositor, backend) = make(
            Color.red.frame(width: 100, height: 100).frame(width: 50, height: 50).clipped()
        )
        compositor.render(graph.displayList(), size: graph.size, scale: 1)
        #expect(layerDraws(backend).isEmpty)
        #expect(backend.commands.contains(.clip(rect(75, 75, 50, 50))))
    }

    /// A very tall item is drawn in tiles, and only the tiles that show.
    @Test func tallContentIsTiled() {
        let lines = (0..<400).map { "Line \($0)" }.joined(separator: "\n")
        let (graph, compositor, _) = make(
            ScrollView { Text(lines).frame(maxWidth: .infinity, alignment: .leading) },
            size: CGSize(width: 300, height: 400)
        )
        compositor.render(graph.displayList(), size: graph.size, scale: 2)
        // 800 pixels of window: one tile row, at most 2 tiles.
        #expect(compositor.lastFrame.rasterizations <= 2)
        graph.scroll(by: CGSize(width: 0, height: 3000), at: CGPoint(x: 150, y: 200))
        compositor.render(graph.displayList(), size: graph.size, scale: 2)
        #expect(compositor.lastFrame.rasterizations >= 1)
        #expect(compositor.lastFrame.rasterizations <= 2)
    }
}

/// Scrolls a 10,000 row list and checks the work per frame stays bounded.
@MainActor
@Suite struct ListScrollBenchmark {

    @Test func tenThousandRows() {
        struct Rows: View {
            var body: some View {
                List(0..<10_000, id: \.self) { index in
                    HStack {
                        Circle().fill(Color.blue).frame(width: 24, height: 24)
                        Text("Row \(index)")
                        Spacer()
                        Text("Detail").foregroundStyle(.secondary)
                    }
                }
            }
        }
        let engine = SilicaTextEngine()
        let backend = RecordingBackend()
        let compositor = Compositor(backend: backend, textEngine: engine)
        let size = CGSize(width: 400, height: 800)
        let graph = ViewGraph(rootView: Rows(), textEngine: engine)
        func frame() {
            if graph.needsUpdate {
                graph.layout(in: size)
            }
            compositor.render(graph.displayList(), size: size, scale: 2)
        }
        graph.layout(in: size)
        frame()
        frame()
        var times: [Double] = []
        var maxRasterizations = 0
        var maxNodes = 0
        var updates = 0
        // Two seconds at 120 Hz, scrolling 2,400 points a second.
        for _ in 0..<240 {
            let start = Date()
            graph.scroll(by: CGSize(width: 0, height: 20), at: CGPoint(x: 200, y: 400))
            if graph.needsUpdate { updates += 1 }
            frame()
            times.append(Date().timeIntervalSince(start))
            maxRasterizations = max(maxRasterizations, compositor.lastFrame.rasterizations)
            var nodes = 0
            graph.root.forEachNode { _ in nodes += 1 }
            maxNodes = max(maxNodes, nodes)
        }
        let sorted = times.sorted()
        let median = sorted[sorted.count / 2] * 1000
        let p95 = sorted[sorted.count * 95 / 100] * 1000
        let worst = sorted.last! * 1000
        print("ListScrollBenchmark: median \(median) ms, p95 \(p95) ms, worst \(worst) ms, updates \(updates) of 240 frames, max nodes \(maxNodes), max rasterizations \(maxRasterizations)")
        // Deterministic bounds: rows are created in batches, not every frame,
        // the graph stays small, and frames only rasterize rows coming into view.
        #expect(updates < 60)
        #expect(maxNodes < 2_500)
        #expect(maxRasterizations <= 60)
    }
}
