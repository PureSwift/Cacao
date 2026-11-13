import Foundation
import Testing
@testable import Cacao

@MainActor
@Suite struct EnvironmentTests {

    struct AccentKey: EnvironmentKey {
        static let defaultValue = "none"
    }

    struct AccentReader: View {
        @Environment(\.accent) var accent
        var body: some View {
            Text(accent)
        }
    }

    @Test func customKeyFlowsDown() {
        let graph = layout(
            VStack {
                AccentReader()
                AccentReader().environment(\.accent, "inner")
            }
            .environment(\.accent, "outer")
        )
        #expect(graph.texts == ["outer", "inner"])
    }

    @Test func defaultValue() {
        let graph = layout(AccentReader())
        #expect(graph.texts == ["none"])
    }

    @Test func fontAndColorResolveInText() {
        let graph = layout(
            Text("Title")
                .font(.title)
                .foregroundStyle(.red)
        )
        guard case let .content(.text(text)) = graph.displayList().items.first?.value else {
            Issue.record("Expected text")
            return
        }
        #expect(text.runs.first?.font.size == 28)
        #expect(text.runs.first?.color == Color.red.resolve(in: EnvironmentValues()))
    }

    @Test func colorSchemeChangesSystemColors() {
        var environment = EnvironmentValues()
        environment.colorScheme = .dark
        #expect(Color.primary.resolve(in: environment) == Color.Resolved(red: 1, green: 1, blue: 1))
        environment.colorScheme = .light
        #expect(Color.primary.resolve(in: environment) == Color.Resolved(red: 0, green: 0, blue: 0))
    }

    struct SumKey: PreferenceKey {
        static let defaultValue = 0
        static func reduce(value: inout Int, nextValue: () -> Int) {
            value += nextValue()
        }
    }

    @Test func preferencesCombineSiblings() {
        var received: [Int] = []
        _ = layout(
            VStack {
                Color.red.preference(key: SumKey.self, value: 1)
                Color.red.preference(key: SumKey.self, value: 2)
                Color.red
                    .preference(key: SumKey.self, value: 3)
                    .transformPreference(SumKey.self) { $0 *= 10 }
            }
            .onPreferenceChange(SumKey.self) { received.append($0) }
        )
        #expect(received == [33])
    }

    @Test func customModifierWithState() {
        struct Badge: ViewModifier {
            @State var label = "new"
            func body(content: Content) -> some View {
                HStack {
                    content
                    Text(label)
                }
            }
        }
        let graph = layout(Text("Inbox").modifier(Badge()))
        #expect(graph.texts == ["Inbox", "new"])
    }
}

extension EnvironmentValues {

    var accent: String {
        get { self[EnvironmentTests.AccentKey.self] }
        set { self[EnvironmentTests.AccentKey.self] = newValue }
    }
}
