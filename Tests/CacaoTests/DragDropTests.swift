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
}
