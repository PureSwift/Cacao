import Foundation
#if canImport(CoreGraphics)
import CoreGraphics
#endif
import Testing
@testable import Cacao

@MainActor
@Suite struct DragDropTests {

    final class Log {
        var dropped: [String] = []
        var location: CGPoint?
        var targeted: [Bool] = []
    }

    func scene(_ log: Log) -> some View {
        HStack(spacing: 40) {
            Text("Item")
                .padding()
                .draggable("payload")
                .probe("source")
            Color.blue
                .frame(width: 100, height: 100)
                .dropDestination(for: String.self) { items, location in
                    log.dropped += items
                    log.location = location
                    return true
                } isTargeted: { log.targeted.append($0) }
                .probe("destination")
        }
    }

    @Test func dragsValuesBetweenViews() {
        let log = Log()
        let graph = layout(scene(log))
        let source = graph.frame("source"), destination = graph.frame("destination")
        let start = CGPoint(x: source.midX, y: source.midY)
        let end = CGPoint(x: destination.minX + 10, y: destination.minY + 20)
        graph.pointer(.began, at: start, time: 0)
        graph.pointer(.moved, at: CGPoint(x: start.x + 20, y: start.y), time: 0.05)
        // The dragged view follows the pointer.
        #expect(graph.displayList().items.contains { $0.identity == Int.min / 2 })
        graph.pointer(.moved, at: end, time: 0.1)
        #expect(log.targeted == [true])
        graph.pointer(.ended, at: end, time: 0.15)
        #expect(log.dropped == ["payload"])
        #expect(log.location == CGPoint(x: 10, y: 20))
        #expect(log.targeted == [true, false])
        #expect(!graph.displayList().items.contains { $0.identity == Int.min / 2 })
    }

    @Test func takesDropsFromTheSystem() {
        let log = Log()
        let graph = layout(scene(log))
        let destination = graph.frame("destination")
        let point = CGPoint(x: destination.midX, y: destination.midY)
        graph.systemDrop(.moved, items: [], at: point)
        #expect(log.targeted == [true])
        let accepted = graph.systemDrop(.dropped, items: [URL(fileURLWithPath: "/tmp/notes.txt")], at: point)
        #expect(accepted)
        // A file arrives as its path when the destination takes strings.
        #expect(log.dropped == ["/tmp/notes.txt"])
        #expect(log.targeted == [true, false])
    }

    @Test func dropsOutsideTargetsGoNowhere() {
        let log = Log()
        let graph = layout(scene(log))
        #expect(!graph.systemDrop(.dropped, items: ["text"], at: CGPoint(x: 1, y: 1)))
        #expect(log.dropped.isEmpty)
        #expect(convertDropItem(URL(string: "https://example.com")!, to: String.self) == "https://example.com")
        #expect(convertDropItem("text", to: Int.self) == nil)
    }

    // MARK: Item providers

    final class ProviderLog {
        var providers: [NSItemProvider] = []
        var location: CGPoint?
        var events: [String] = []
    }

    struct Delegate: DropDelegate {
        let log: ProviderLog
        var accepts = true
        func validateDrop(info: DropInfo) -> Bool { accepts }
        func dropEntered(info: DropInfo) { log.events.append("entered") }
        func dropUpdated(info: DropInfo) -> DropProposal? {
            log.events.append("updated \(Int(info.location.x))")
            return DropProposal(operation: .copy)
        }
        func dropExited(info: DropInfo) { log.events.append("exited") }
        func performDrop(info: DropInfo) -> Bool {
            log.events.append("perform")
            log.providers = info.itemProviders(for: [.plainText])
            return true
        }
    }

    func providerScene(_ log: ProviderLog, delegate: Delegate? = nil) -> some View {
        HStack(spacing: 20) {
            Color.red
                .frame(width: 60, height: 60)
                .onDrag {
                    let provider = NSItemProvider()
                    provider.registerDataRepresentation(forTypeIdentifier: UTType.utf8PlainText.identifier, visibility: .all) { completion in
                        completion(Data("dragged".utf8), nil)
                        return nil
                    }
                    return provider
                }
                .probe("source")
            Group {
                if let delegate {
                    Color.blue.onDrop(of: [.plainText], delegate: delegate)
                } else {
                    Color.blue.onDrop(of: [.plainText], isTargeted: nil) { providers, location in
                        log.providers = providers
                        log.location = location
                        return true
                    }
                }
            }
            .frame(width: 100, height: 100)
            .probe("destination")
        }
    }

    func text(of provider: NSItemProvider?) async -> String? {
        guard let provider else { return nil }
        return await withCheckedContinuation { continuation in
            provider.loadDataRepresentation(forTypeIdentifier: UTType.plainText.identifier) { data, _ in
                continuation.resume(returning: data.flatMap { String(data: $0, encoding: .utf8) })
            }
        }
    }

    func drag(in graph: ViewGraph, to end: CGPoint, through points: [CGPoint] = []) {
        let source = graph.frame("source")
        let start = CGPoint(x: source.midX, y: source.midY)
        graph.pointer(.began, at: start, time: 0)
        graph.pointer(.moved, at: CGPoint(x: start.x + 10, y: start.y), time: 0.05)
        for (index, point) in points.enumerated() {
            graph.pointer(.moved, at: point, time: 0.1 + Double(index) * 0.05)
        }
        graph.pointer(.moved, at: end, time: 0.5)
        graph.pointer(.ended, at: end, time: 0.55)
    }

    @Test func dragsItemProvidersBetweenViews() async {
        let log = ProviderLog()
        let graph = layout(providerScene(log))
        let destination = graph.frame("destination")
        drag(in: graph, to: CGPoint(x: destination.minX + 30, y: destination.minY + 40))
        #expect(log.location == CGPoint(x: 30, y: 40))
        #expect(log.providers.count == 1)
        #expect(await text(of: log.providers.first) == "dragged")
    }

    @Test func dropDelegateFollowsTheDrag() {
        let log = ProviderLog()
        let graph = layout(providerScene(log, delegate: Delegate(log: log)))
        let destination = graph.frame("destination")
        let inside = CGPoint(x: destination.minX + 10, y: destination.midY)
        let outside = CGPoint(x: destination.maxX + 50, y: destination.midY)
        drag(in: graph, to: CGPoint(x: destination.minX + 20, y: destination.midY), through: [inside, outside])
        #expect(log.events == ["entered", "updated 10", "exited", "entered", "updated 20", "perform"])
        #expect(log.providers.count == 1)
    }

    @Test func dropDelegateCanRefuseDrops() {
        let log = ProviderLog()
        let graph = layout(providerScene(log, delegate: Delegate(log: log, accepts: false)))
        let destination = graph.frame("destination")
        drag(in: graph, to: CGPoint(x: destination.midX, y: destination.midY))
        #expect(log.events.isEmpty)
        #expect(log.providers.isEmpty)
    }

    @Test func systemDropsArriveAsProviders() async {
        let log = ProviderLog()
        let graph = layout(providerScene(log))
        let destination = graph.frame("destination")
        let point = CGPoint(x: destination.midX, y: destination.midY)
        graph.systemDrop(.moved, items: [], at: point)
        #expect(graph.systemDrop(.dropped, items: ["from the system"], at: point))
        #expect(await text(of: log.providers.first) == "from the system")
        // Items of other types aren't taken.
        log.providers = []
        #expect(!graph.systemDrop(.dropped, items: [Data([1, 2])], at: point))
        #expect(log.providers.isEmpty)
    }
}
