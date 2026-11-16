import Foundation
import Testing
@testable import Cacao

extension EnvironmentValues {
    @Entry var accentLevel: Int = 3
    @Entry var badgeText: String?
}

@MainActor
@Suite struct EntryMacroTests {

    struct Reader: View {
        @Environment(\.accentLevel) var level
        @Environment(\.badgeText) var badge
        var body: some View {
            Text("\(level) \(badge ?? "none")")
        }
    }

    @Test func entryDeclaresAnEnvironmentValue() {
        var values = EnvironmentValues()
        #expect(values.accentLevel == 3)
        #expect(values.badgeText == nil)
        values.accentLevel = 5
        #expect(values.accentLevel == 5)
        let graph = layout(VStack {
            Reader()
            Reader().environment(\.accentLevel, 7).environment(\.badgeText, "new")
        })
        #expect(graph.texts == ["3 none", "7 new"])
    }
}
