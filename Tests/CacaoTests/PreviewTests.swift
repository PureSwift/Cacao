import CacaoRender
import Foundation
import Testing
@testable import Cacao

#Preview("Greeting") {
    Text("Hello, preview")
}

#Preview {
    VStack {
        Text("First")
        Text("Second")
    }
}

@MainActor
@Suite struct PreviewTests {

    /// The previews this file declares.
    private var previews: [any _PreviewRegistration.Type] {
        PreviewRegistry.all.filter { $0.fileID.hasSuffix("PreviewTests.swift") }
    }

    @Test func previewsAreFoundInADebugBuild() {
        #if DEBUG
        #expect(previews.count == 2)
        let names = previews.map { $0.name }
        #expect(names == ["Greeting", nil])
        let line = previews.first.map { $0.line }
        #expect(line == 6)
        #else
        #expect(previews.isEmpty)
        #endif
    }

    @Test func aPreviewMakesItsView() throws {
        #if DEBUG
        let named = try #require(previews.first)
        #expect(layout(named.makeView()).texts == ["Hello, preview"])
        let unnamed = try #require(previews.last)
        #expect(layout(unnamed.makeView()).texts == ["First", "Second"])
        #endif
    }
}

@MainActor
@Suite struct LabelStyleTests {

    /// The title over the icon, each marked.
    struct Stacked: LabelStyle {
        func makeBody(configuration: Configuration) -> some View {
            VStack {
                Text("above")
                configuration.title
                configuration.icon
            }
        }
    }

    private func label() -> some View {
        Label(title: { Text("Title") }, icon: { Text("Icon") })
    }

    @Test func labelsShowTheirIconThenTitleByDefault() {
        #expect(layout(label()).texts == ["Icon", "Title"])
    }

    @Test func builtInStylesChooseWhatShows() {
        #expect(layout(label().labelStyle(.titleOnly)).texts == ["Title"])
        #expect(layout(label().labelStyle(.iconOnly)).texts == ["Icon"])
        #expect(layout(label().labelStyle(.titleAndIcon)).texts == ["Icon", "Title"])
    }

    @Test func aCustomStyleMakesTheLabelsBody() {
        #expect(layout(label().labelStyle(Stacked())).texts == ["above", "Title", "Icon"])
    }
}

@MainActor
@Suite struct FocusEnvironmentTests {

    struct Reader: View {
        @Environment(\.isFocused) var isFocused
        var body: some View {
            Text(isFocused ? "focused" : "not focused")
        }
    }

    @Test func aFocusableViewsContentReadsWhetherItHasFocus() {
        let graph = layout(VStack {
            Reader().focusable()
            Text("Elsewhere").focusable()
        })
        graph.settle()
        #expect(graph.texts.contains("not focused"))
        graph.tapText("not focused")
        graph.settle()
        #expect(graph.texts.contains("focused"))
        // Focus moves on.
        graph.tapText("Elsewhere")
        graph.settle()
        #expect(graph.texts.contains("not focused"))
    }

    @Test func focusSectionsLeaveAViewAsItIs() {
        #expect(layout(Text("Shelf").focusSection()).texts == ["Shelf"])
    }

    @Test func viewsOutsideAFocusableViewAreNotFocused() {
        #expect(layout(Reader()).texts == ["not focused"])
    }
}
