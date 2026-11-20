import CacaoRender
import Foundation
#if canImport(CoreGraphics)
import CoreGraphics
#endif
import Testing
@testable import Cacao
@testable import CacaoCompositor

@MainActor
@Suite struct ExternalSurfaceTests {

    private func make(_ surface: ExternalSurface, size: CGSize = CGSize(width: 100, height: 100)) -> (ViewGraph, Compositor, RecordingBackend) {
        let engine = SilicaTextEngine()
        let backend = RecordingBackend()
        let compositor = Compositor(backend: backend, textEngine: engine)
        let graph = ViewGraph(rootView: ExternalSurfaceView(surface, scale: 1), textEngine: engine)
        graph.layout(in: size)
        return (graph, compositor, backend)
    }

    private func publish(_ surface: ExternalSurface, width: Int = 4, height: Int = 2, rowOrder: ExternalSurface.RowOrder = .topFirst, isOpaque: Bool = false) {
        let pixels = [UInt8](repeating: 255, count: width * height * 4)
        pixels.withUnsafeBytes {
            surface.publish(pixels: $0, width: width, height: height, rowOrder: rowOrder, isOpaque: isOpaque)
        }
    }

    private func externalDraws(_ backend: RecordingBackend) -> [RecordingBackend.Command] {
        backend.commands.filter {
            if case .drawExternal = $0 { true } else { false }
        }
    }

    private func updates(_ backend: RecordingBackend) -> Int {
        backend.commands.filter {
            if case .updateExternal = $0 { true } else { false }
        }.count
    }

    // MARK: Pixels

    @Test func nothingIsDrawnBeforeAFrame() {
        let surface = ExternalSurface()
        let (graph, compositor, backend) = make(surface)
        compositor.render(graph.displayList(), size: graph.size, scale: 1)
        #expect(externalDraws(backend).isEmpty)
        #expect(!compositor.hasNewExternalFrames)
    }

    @Test func aFrameOfPixelsFillsTheViewsFrame() {
        let surface = ExternalSurface()
        publish(surface, rowOrder: .bottomFirst, isOpaque: true)
        let (graph, compositor, backend) = make(surface)
        compositor.render(graph.displayList(), size: graph.size, scale: 2)
        #expect(updates(backend) == 1)
        guard case let .drawExternal(_, rect, isOpaque, isFlipped)? = externalDraws(backend).first else {
            Issue.record("the frame wasn't drawn")
            return
        }
        #expect(rect == CGRect(x: 0, y: 0, width: 200, height: 200))
        #expect(isOpaque)
        #expect(isFlipped)
        #expect(compositor.lastFrame.externalFrames == 1)
    }

    @Test func theSameFrameIsNotUploadedTwice() {
        let surface = ExternalSurface()
        publish(surface)
        let (graph, compositor, backend) = make(surface)
        compositor.render(graph.displayList(), size: graph.size, scale: 1)
        compositor.render(graph.displayList(), size: graph.size, scale: 1)
        #expect(updates(backend) == 0)
        #expect(externalDraws(backend).count == 1)
        #expect(compositor.lastFrame.externalFrames == 0)
    }

    @Test func aNewFrameUpdatesTheSameTexture() {
        let surface = ExternalSurface()
        publish(surface)
        let (graph, compositor, backend) = make(surface)
        compositor.render(graph.displayList(), size: graph.size, scale: 1)
        let textures = backend.liveTextures
        #expect(!compositor.hasNewExternalFrames)
        publish(surface)
        #expect(compositor.hasNewExternalFrames)
        compositor.render(graph.displayList(), size: graph.size, scale: 1)
        #expect(updates(backend) == 1)
        #expect(backend.liveTextures == textures)
        #expect(!compositor.hasNewExternalFrames)
    }

    @Test func aFrameOfAnotherSizeReplacesTheTexture() {
        let surface = ExternalSurface()
        publish(surface)
        let (graph, compositor, backend) = make(surface)
        compositor.render(graph.displayList(), size: graph.size, scale: 1)
        let textures = backend.liveTextures
        publish(surface, width: 8, height: 8)
        compositor.render(graph.displayList(), size: graph.size, scale: 1)
        #expect(backend.liveTextures.count == textures.count)
        #expect(backend.liveTextures != textures)
    }

    @Test func aSurfaceNoLongerShownReleasesItsTexture() {
        let surface = ExternalSurface()
        publish(surface)
        let (graph, compositor, backend) = make(surface)
        compositor.render(graph.displayList(), size: graph.size, scale: 1)
        #expect(!backend.liveTextures.isEmpty)
        compositor.render(DisplayList(), size: graph.size, scale: 1)
        #expect(backend.liveTextures.isEmpty)
        #expect(compositor.externalSurfaces.isEmpty)
    }

    @Test func publishingCallsTheHandlerOnThePublishingThread() async {
        let surface = ExternalSurface()
        let woken = Woken()
        surface.onPublish = { woken.count() }
        await Task.detached {
            let pixels = [UInt8](repeating: 0, count: 16)
            pixels.withUnsafeBytes { surface.publish(pixels: $0, width: 2, height: 2) }
        }.value
        #expect(woken.value == 1)
        #expect(surface.pixelSize == CGSize(width: 2, height: 2))
    }

    @Test func theViewTakesTheSurfacesSizeWhereUnspecified() {
        let surface = ExternalSurface()
        publish(surface, width: 40, height: 20)
        let graph = ViewGraph(rootView: ExternalSurfaceView(surface, scale: 2).fixedSize(), textEngine: SilicaTextEngine())
        graph.layout(in: CGSize(width: 100, height: 100))
        let item = graph.displayList().items.first
        #expect(item?.frame.size == CGSize(width: 20, height: 10))
    }

    // MARK: Shared buffers

    /// A surface with shared buffers that are only described: a compositor
    /// that imports them is the recording backend, which opens nothing.
    private func shared(count: Int = 3) -> ExternalSurface {
        ExternalSurface(buffers: (0..<count).map { _ in
            ExternalSurface.Buffer(fileDescriptor: -1, width: 64, height: 32, stride: 256, fourCC: 0x3432_4241)
        })
    }

    @Test func aSharedBufferIsImportedOnceAndDrawnFlipped() {
        let surface = shared()
        surface.publish(buffer: 1, isOpaque: true)
        let (graph, compositor, backend) = make(surface)
        backend.importsBuffers = true
        compositor.render(graph.displayList(), size: graph.size, scale: 1)
        let imported = backend.liveTextures
        #expect(imported.count == 1)
        guard case let .drawExternal(_, _, isOpaque, isFlipped)? = externalDraws(backend).first else {
            Issue.record("the buffer wasn't drawn")
            return
        }
        #expect(isOpaque)
        #expect(isFlipped)
        #expect(updates(backend) == 0)
        surface.publish(buffer: 1)
        compositor.render(graph.displayList(), size: graph.size, scale: 1)
        #expect(backend.liveTextures == imported)
    }

    @Test func buffersInUseAreTheShownAndTheNewest() {
        let surface = shared()
        #expect(surface.buffersInUse == 0)
        surface.publish(buffer: 0)
        #expect(surface.buffersInUse == 0b001)
        #expect(surface.takeBuffer() == ExternalSurface.TakenBuffer(index: 0, frames: 1, isWaiting: false))
        surface.publish(buffer: 2)
        // Buffer 0 is on screen until the compositor takes buffer 2.
        #expect(surface.buffersInUse == 0b101)
        #expect(surface.takeBuffer()?.index == 2)
        #expect(surface.buffersInUse == 0b100)
    }

    @Test func aFrameIsShownOnlyOnceItsFenceSignals() throws {
        let surface = shared()
        surface.publish(buffer: 0)
        // A pipe stands in for the GPU's fence: readable once written to.
        var ends: [Int32] = [0, 0]
        #expect(pipe(&ends) == 0)
        defer { close(ends[1]) }
        surface.publish(buffer: 1, fence: ends[0])
        #expect(surface.buffersInUse == 0b011)
        let before = try #require(surface.takeBuffer())
        #expect(before.index == 0)
        #expect(before.isWaiting)
        #expect(surface.hasNewFrame)
        var byte: UInt8 = 1
        #expect(write(ends[1], &byte, 1) == 1)
        let after = try #require(surface.takeBuffer())
        #expect(after.index == 1)
        #expect(!after.isWaiting)
        #expect(!surface.hasNewFrame)
    }

    @Test func buffersThatCannotBeImportedFallBackToPixels() {
        let surface = shared()
        surface.publish(buffer: 0)
        let (graph, compositor, backend) = make(surface)
        compositor.render(graph.displayList(), size: graph.size, scale: 1)
        #expect(externalDraws(backend).isEmpty)
        // The producer learns of it, and publishes pixels.
        #expect(surface.buffersInUse == nil)
        #expect(!surface.usesBuffers)
        publish(surface)
        compositor.render(graph.displayList(), size: graph.size, scale: 1)
        #expect(updates(backend) == 1)
        #expect(externalDraws(backend).count == 1)
    }
}

/// Counts calls from any thread.
private final class Woken: @unchecked Sendable {
    private let lock = NSLock()
    private var calls = 0
    func count() {
        lock.lock()
        calls += 1
        lock.unlock()
    }
    var value: Int {
        lock.lock()
        defer { lock.unlock() }
        return calls
    }
}
