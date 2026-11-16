import Foundation
import Observation
import Testing
@testable import Cacao

final class Counter: ObservableObject {
    @Published var count = 0
    var unpublished = 0
}

@Observable
final class ObservableCounter {
    var count = 0
}

@MainActor
@Suite struct ObservableObjectTests {

    @Test func publishedChangesUpdateObservers() {
        struct Shown: View {
            @ObservedObject var counter: Counter
            var body: some View { Text("\(counter.count)") }
        }
        let counter = Counter()
        let graph = layout(Shown(counter: counter))
        #expect(graph.texts == ["0"])
        counter.count = 3
        #expect(graph.needsUpdate)
        graph.settle()
        #expect(graph.texts == ["3"])
        counter.unpublished = 9
        #expect(!graph.needsUpdate)
    }

    @Test func stateObjectIsCreatedOnce() {
        struct Owner: View {
            @StateObject var counter = Counter()
            var body: some View {
                Text("\(counter.count)").onTapGesture { counter.count += 1 }
            }
        }
        struct Parent: View {
            @State var flag = false
            var body: some View {
                VStack {
                    Owner()
                    Text(flag ? "On" : "Off").onTapGesture { flag.toggle() }
                }
            }
        }
        let graph = layout(Parent())
        graph.tapText("0")
        graph.settle()
        #expect(graph.texts.contains("1"))
        // The parent passes a new Owner, which keeps its object.
        graph.tapText("Off")
        graph.settle()
        #expect(graph.texts == ["1", "On"])
    }

    @Test func environmentObjectReachesDescendants() {
        struct Leaf: View {
            @EnvironmentObject var counter: Counter
            var body: some View { Text("Count \(counter.count)") }
        }
        let counter = Counter()
        let graph = layout(VStack { Leaf() }.environmentObject(counter))
        #expect(graph.texts == ["Count 0"])
        counter.count = 2
        graph.settle()
        #expect(graph.texts == ["Count 2"])
    }

    @Test func observedObjectBindings() {
        struct Editor: View {
            @ObservedObject var counter: Counter
            var body: some View {
                Stepper("Count \(counter.count)", value: $counter.count)
            }
        }
        let counter = Counter()
        let graph = layout(Editor(counter: counter))
        #expect(graph.texts.contains("Count 0"))
    }

    @Test func bindableMakesBindings() {
        let counter = ObservableCounter()
        @Bindable var bindable = counter
        $bindable.count.wrappedValue = 5
        #expect(counter.count == 5)
    }

    @Test func appStorageReadsAndWritesDefaults() throws {
        let suite = "CacaoTests.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        struct Stored: View {
            @AppStorage("launches", store: nil) var unused = 0
            let defaults: UserDefaults
            var body: some View {
                Reader(storage: AppStorage(wrappedValue: 0, "launches", store: defaults))
            }
        }
        struct Reader: View {
            let storage: AppStorage<Int>
            var body: some View {
                Text("\(storage.wrappedValue)").onTapGesture { storage.wrappedValue += 1 }
            }
        }
        struct Direct: View {
            @AppStorage var count: Int
            init(defaults: UserDefaults) {
                _count = AppStorage(wrappedValue: 0, "count", store: defaults)
            }
            var body: some View {
                Text("Count \(count)").onTapGesture { count += 1 }
            }
        }
        let graph = layout(VStack { Direct(defaults: defaults); Direct(defaults: defaults) })
        #expect(graph.texts == ["Count 0", "Count 0"])
        graph.tapText("Count 0")
        graph.settle()
        // Both views using the key update.
        #expect(graph.texts == ["Count 1", "Count 1"])
        #expect(defaults.integer(forKey: "count") == 1)
    }

    @Test func taskRunsOnAppearAndCancelsOnDisappear() async {
        let log = GestureLog()
        struct Host: View {
            let log: GestureLog
            @State var shows = true
            var body: some View {
                VStack {
                    Text("Toggle").onTapGesture { shows.toggle() }
                    if shows {
                        Text("Loading").task {
                            await MainActor.run { log.log("started") }
                            try? await Task.sleep(nanoseconds: 5_000_000_000)
                            let cancelled = Task.isCancelled
                            await MainActor.run { log.log(cancelled ? "cancelled" : "finished") }
                        }
                    }
                }
            }
        }
        let graph = layout(Host(log: log))
        for _ in 0..<50 where log.events.isEmpty {
            try? await Task.sleep(nanoseconds: 10_000_000)
        }
        #expect(log.events == ["started"])
        graph.tapText("Toggle")
        graph.settle()
        for _ in 0..<100 where log.events.count < 2 {
            try? await Task.sleep(nanoseconds: 10_000_000)
        }
        #expect(log.events == ["started", "cancelled"])
    }
}
