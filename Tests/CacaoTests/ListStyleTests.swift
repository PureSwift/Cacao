import CacaoRender
import Foundation
#if canImport(CoreGraphics)
import CoreGraphics
#endif
import Testing
@testable import Cacao

@MainActor
@Suite struct ListStyleTests {

    /// How many separators the list draws.
    func separators(in graph: ViewGraph) -> Int {
        var count = 0
        graph.root.forEachNode { if $0.behavior is DividerBehavior { count += 1 } }
        return count
    }

    func resolved(_ color: Color) -> Color.Resolved {
        color.resolve(in: EnvironmentValues())
    }

    @Test func rowModifiersSetInsetsBackgroundAndSeparators() {
        struct Rows: View {
            var body: some View {
                List {
                    Text("Plain").probe("plain")
                    Text("Inset")
                        .listRowInsets(EdgeInsets(top: 2, leading: 40, bottom: 2, trailing: 0))
                        .probe("inset")
                    Text("Red")
                        .listRowBackground(Color.red)
                        .listRowSeparator(.hidden)
                }
            }
        }
        let graph = layout(Rows(), width: 300, height: 400)
        graph.settle()
        #expect(graph.frame("plain").minX == 16)
        #expect(graph.frame("inset").minX == 40)
        // The red row's background spans the row, and it has no separator.
        let red = graph.colorItems.first { $0.color == resolved(.red) }
        #expect(red?.frame.minX == 0)
        #expect(red?.frame.width == 300)
        #expect(separators(in: graph) == 2)
    }

    @Test func rowModifiersInsideCustomRowViews() {
        struct Row: View {
            var body: some View {
                Text("Custom").listRowInsets(EdgeInsets(top: 0, leading: 30, bottom: 0, trailing: 0)).probe("custom")
            }
        }
        let graph = layout(List { Row() }, width: 300, height: 200)
        graph.settle()
        #expect(graph.frame("custom").minX == 30)
    }

    @Test func insetGroupedRowsSitOnCards() {
        let graph = layout(
            List {
                Section("Fruit") {
                    Text("Apple").probe("apple")
                    Text("Pear")
                }
            }
            .listStyle(.insetGrouped),
            width: 300, height: 400
        )
        graph.settle()
        // Within the margin, over the grouped background.
        #expect(graph.frame("apple").minX == 32)
        let background = resolved(Color.groupedBackground(.light))
        #expect(graph.colorItems.contains { $0.color == background })
        // One separator between the two rows, none after the last.
        #expect(separators(in: graph) == 1)
    }

    @Test func sidebarListsHaveNoSeparators() {
        let graph = layout(
            List {
                Text("Inbox")
                Text("Sent")
            }
            .listStyle(.sidebar),
            width: 300, height: 400
        )
        graph.settle()
        #expect(separators(in: graph) == 0)
    }

    @Test func scrollContentBackgroundHidesTheGroupedBackground() {
        let graph = layout(
            List { Text("Row") }
                .listStyle(.grouped)
                .scrollContentBackground(.hidden),
            width: 300, height: 400
        )
        graph.settle()
        let background = resolved(Color.groupedBackground(.light))
        #expect(!graph.colorItems.contains { $0.color == background })
    }

    @Test func unevenRoundedRectangleRoundsOnlyItsCorners() {
        let path = UnevenRoundedRectangle(topLeadingRadius: 10).path(in: CGRect(x: 0, y: 0, width: 100, height: 50))
        #expect(path.contains(CGPoint(x: 99.5, y: 0.5)))
        #expect(!path.contains(CGPoint(x: 0.5, y: 0.5)))
        #expect(path.contains(CGPoint(x: 0.5, y: 49.5)))
    }
}
