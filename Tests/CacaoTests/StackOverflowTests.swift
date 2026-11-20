import CacaoRender
import Foundation
#if canImport(CoreGraphics)
import CoreGraphics
#endif
import Testing
@testable import Cacao

@MainActor
@Suite struct StackOverflowTests {

    /// A row too wide for the window: a fixed 1000 points between two
    /// columns that can shrink, as in Apple's tvOS catalog sample.
    private func row() -> some View {
        VStack(alignment: .leading) {
            Text("Title").probe("title")
            HStack(alignment: .top, spacing: 30) {
                VStack(spacing: 12) {
                    Button {} label: { Text("Sign Up").frame(maxWidth: .infinity) }
                    Button {} label: { Text("Buy or Rent").frame(maxWidth: .infinity) }
                }
                .probe("buttons")
                Text("Description").frame(width: 1000).probe("fixed")
                VStack(spacing: 0) {
                    Text("Starring Someone")
                    Text("Director Someone Else")
                }
                .probe("credits")
            }
            .probe("row")
        }
    }

    /// Measured in SwiftUI: the fixed column keeps its width and the others
    /// get what's left, which is nothing, so the row is 1000 and two gaps.
    @Test func flexibleColumnsGiveWayToAFixedOne() {
        let graph = layout(row(), width: 1032, height: 600)
        graph.settle()
        #expect(graph.frame("fixed").width == 1000)
        #expect(graph.frame("buttons").width == 0)
        #expect(graph.frame("credits").width == 0)
        #expect(graph.frame("row").width == 1060)
        // What doesn't fit is centered, overflowing each side alike.
        #expect(graph.frame("row").minX == -14)
        #expect(graph.frame("title").minX == -14)
    }

    @Test func aStackOfAnUnlimitedViewIsUnlimited() {
        let children = VStack {
            Color.red
            Text("Label")
        }
        let graph = layout(children.probe("stack"), width: 300, height: 200)
        // Offered any width at all, it takes it: not a width that isn't a number.
        let size = LayoutProxy.combining(graph.root.layoutChildren)?.size(in: ProposedViewSize(width: .infinity, height: 200))
        #expect(size?.width == .infinity)
    }
}
