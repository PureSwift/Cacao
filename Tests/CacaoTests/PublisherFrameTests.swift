import Foundation
#if canImport(CoreGraphics)
import CoreGraphics
#endif
#if canImport(Combine)
import Combine
#endif
import Testing
@testable import Cacao

@MainActor
@Suite struct PublisherFrameTests {

    @Test func onReceiveRunsTheLatestAction() async {
        let subject = PassthroughSubject<Int, Never>()
        let log = GestureLog()
        struct Receiver: View {
            let subject: PassthroughSubject<Int, Never>
            let log: GestureLog
            @State var offset = 0
            var body: some View {
                Color.red
                    .onReceive(subject) { value in
                        log.log("\(value + offset)")
                        offset += 10
                    }
            }
        }
        let graph = layout(Receiver(subject: subject, log: log))
        // Values sent off the main thread arrive on the main actor.
        subject.send(1)
        await Task.yield()
        graph.update()
        subject.send(2)
        await Task.yield()
        #expect(log.events == ["1", "12"])
    }

    @Test func publishedPropertiesPublish() {
        final class Model: ObservableObject {
            @Published var count = 0
        }
        let model = Model()
        var received: [Int] = []
        let cancellable = model.$count.sink { received.append($0) }
        model.count = 3
        cancellable.cancel()
        model.count = 4
        #expect(received == [0, 3])
    }

    @Test func containerRelativeFrameSizesToTheWindow() {
        let graph = layout(
            Color.red.containerRelativeFrame(.horizontal) { length, _ in length / 2 }.probe("half"),
            width: 400, height: 300
        )
        #expect(graph.frame("half").width == 200)
        #expect(graph.frame("half").height == 300)
    }

    @Test func containerRelativeFrameSizesToTheScrollView() {
        let graph = layout(
            ScrollView(.horizontal) {
                HStack(spacing: 10) {
                    ForEach(0..<6) { index in
                        Color.blue
                            .containerRelativeFrame(.horizontal, count: 3, spacing: 10)
                            .probe("item\(index)")
                    }
                }
            }
            .frame(width: 320, height: 100),
            width: 400, height: 300
        )
        // Three columns with two gaps of 10 in 320 points.
        #expect(graph.frame("item0").width == 100)
        #expect(graph.frame("item1").minX - graph.frame("item0").minX == 110)
    }
}
