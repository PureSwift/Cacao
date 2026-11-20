import CacaoRender
import Foundation
import Observation
import Testing
@testable import Cacao

@MainActor
@Suite struct StateTests {

    struct Counter: View {

        @State var count = 0

        var body: some View {
            Text("Count: \(count)")
                .background { Exposer(binding: $count) }
        }
    }

    /// Hands a binding to the test through a preference.
    struct Exposer: View {
        let binding: Binding<Int>
        var body: some View {
            Color.clear.preference(key: BindingKey.self, value: BindingBox(binding: binding))
        }
    }

    struct BindingBox: Equatable {
        let binding: Binding<Int>
        static func == (lhs: BindingBox, rhs: BindingBox) -> Bool { false }
    }

    struct BindingKey: PreferenceKey {
        static var defaultValue: BindingBox? { nil }
        static func reduce(value: inout BindingBox?, nextValue: () -> BindingBox?) {
            value = value ?? nextValue()
        }
    }

    @Test func stateUpdatesBody() {
        var binding: Binding<Int>?
        let graph = layout(Counter().onPreferenceChange(BindingKey.self) { binding = $0?.binding })
        #expect(graph.texts == ["Count: 0"])
        binding?.wrappedValue = 5
        #expect(graph.needsUpdate)
        graph.update()
        #expect(graph.texts == ["Count: 5"])
        #expect(binding?.wrappedValue == 5)
    }

    @Test func stateResetsWhenBranchChanges() {
        struct Root: View {
            var showFirst: Bool
            var body: some View {
                if showFirst {
                    Counter()
                } else {
                    Counter()
                }
            }
        }
        var binding: Binding<Int>?
        let graph = ViewGraph(rootView: Root(showFirst: true).onPreferenceChange(BindingKey.self) { binding = $0?.binding })
        binding?.wrappedValue = 3
        graph.update()
        #expect(graph.texts == ["Count: 3"])
        // Same type, other branch: a different identity, so fresh state.
        graph.setRootView(Root(showFirst: false).onPreferenceChange(BindingKey.self) { binding = $0?.binding })
        graph.update()
        #expect(graph.texts == ["Count: 0"])
    }

    @Test func statePersistsAcrossParentUpdates() {
        struct Parent: View {
            @State var title = "A"
            var body: some View {
                VStack {
                    Text(title)
                    Counter()
                }
                .background { TitleExposer(title: $title) }
            }
        }
        struct TitleExposer: View {
            let title: Binding<String>
            var body: some View {
                Color.clear.onAppear { TitleExposer.last = title }
            }
            nonisolated(unsafe) static var last: Binding<String>?
        }
        var counter: Binding<Int>?
        let graph = ViewGraph(rootView: Parent().onPreferenceChange(BindingKey.self) { counter = $0?.binding })
        counter?.wrappedValue = 7
        graph.update()
        TitleExposer.last?.wrappedValue = "B"
        graph.update()
        #expect(graph.texts == ["B", "Count: 7"])
    }

    @Test func forEachKeepsStateByID() {
        struct Row: View {
            let id: Int
            @State var taps = 0
            var body: some View {
                Text("\(id):\(taps)")
                    .onAppear { Row.bindings[id] = $taps }
            }
            nonisolated(unsafe) static var bindings: [Int: Binding<Int>] = [:]
        }
        struct List: View {
            var ids: [Int]
            var body: some View {
                VStack {
                    ForEach(ids, id: \.self) { Row(id: $0) }
                }
            }
        }
        Row.bindings = [:]
        let graph = ViewGraph(rootView: List(ids: [1, 2, 3]))
        Row.bindings[2]?.wrappedValue = 9
        graph.update()
        #expect(graph.texts == ["1:0", "2:9", "3:0"])
        graph.setRootView(List(ids: [3, 2]))
        graph.update()
        #expect(graph.texts == ["3:0", "2:9"])
    }

    @Test func idModifierResetsState() {
        struct Root: View {
            var identity: Int
            var body: some View {
                Counter().id(identity)
            }
        }
        var binding: Binding<Int>?
        let graph = ViewGraph(rootView: Root(identity: 1).onPreferenceChange(BindingKey.self) { binding = $0?.binding })
        binding?.wrappedValue = 4
        graph.update()
        graph.setRootView(Root(identity: 1).onPreferenceChange(BindingKey.self) { binding = $0?.binding })
        graph.update()
        #expect(graph.texts == ["Count: 4"])
        graph.setRootView(Root(identity: 2).onPreferenceChange(BindingKey.self) { binding = $0?.binding })
        graph.update()
        #expect(graph.texts == ["Count: 0"])
    }

    @Observable
    final class Model {
        var name = "Ada"
    }

    @Test func observableObjectInvalidatesReaders() {
        struct Greeting: View {
            let model: Model
            var body: some View {
                Text("Hello, \(model.name)")
            }
        }
        let model = Model()
        let graph = layout(Greeting(model: model))
        #expect(graph.texts == ["Hello, Ada"])
        model.name = "Grace"
        #expect(graph.needsUpdate)
        graph.update()
        #expect(graph.texts == ["Hello, Grace"])
    }

    @Test func environmentObject() {
        struct Greeting: View {
            @Environment(Model.self) var model
            var body: some View {
                Text(model.name)
            }
        }
        let model = Model()
        let graph = layout(VStack { Greeting() }.environment(model))
        #expect(graph.texts == ["Ada"])
        model.name = "Lin"
        graph.update()
        #expect(graph.texts == ["Lin"])
    }

    @Test func appearAndDisappear() {
        struct Root: View {
            var show: Bool
            var log: Log
            var body: some View {
                VStack {
                    if show {
                        Text("Shown")
                            .onAppear { log.events.append("appear") }
                            .onDisappear { log.events.append("disappear") }
                    }
                }
            }
        }
        final class Log { var events: [String] = [] }
        let log = Log()
        let graph = ViewGraph(rootView: Root(show: true, log: log))
        #expect(log.events == ["appear"])
        graph.setRootView(Root(show: true, log: log))
        graph.update()
        #expect(log.events == ["appear"])
        graph.setRootView(Root(show: false, log: log))
        graph.update()
        #expect(log.events == ["appear", "disappear"])
    }
}
