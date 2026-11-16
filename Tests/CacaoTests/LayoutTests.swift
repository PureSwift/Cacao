import Foundation
#if canImport(CoreGraphics)
import CoreGraphics
#endif
import Testing
@testable import Cacao

/// Layout results computed by hand from SwiftUI's rules. The same cases run
/// against Apple's SwiftUI on macOS in `CacaoLayoutParityTests`.
@MainActor
@Suite struct LayoutTests {

    @Test func rootContentIsCentered() {
        let graph = layout(Color.red.frame(width: 100, height: 50).probe("a"), width: 400, height: 300)
        #expect(graph.frame("a") == rect(150, 125, 100, 50))
    }

    @Test func hstackOfFixedViews() {
        let graph = layout(
            HStack {
                Color.red.frame(width: 50, height: 50).probe("a")
                Color.blue.frame(width: 30, height: 80).probe("b")
            }
            .probe("stack"),
            width: 300, height: 200
        )
        // 50 + 8 + 30 = 88 wide, 80 tall, centered vertically within the stack.
        #expect(graph.frame("stack") == rect(106, 60, 88, 80))
        #expect(graph.frame("a") == rect(106, 75, 50, 50))
        #expect(graph.frame("b") == rect(164, 60, 30, 80))
    }

    @Test func hstackSharesSpaceWithFlexibleViews() {
        let graph = layout(
            HStack {
                Color.red.probe("a")
                Color.blue.frame(width: 40).probe("b")
                Color.green.probe("c")
            }
            .frame(width: 300, height: 100),
            width: 300, height: 100
        )
        // The fixed view is sized first; the rest is split evenly.
        // (300 - 16 - 40) / 2 = 122
        #expect(graph.frame("b").width == 40)
        #expect(graph.frame("a") == rect(0, 0, 122, 100))
        #expect(graph.frame("c") == rect(178, 0, 122, 100))
    }

    @Test func vstackAlignment() {
        let graph = layout(
            VStack(alignment: .leading, spacing: 10) {
                Color.red.frame(width: 100, height: 20).probe("a")
                Color.blue.frame(width: 40, height: 20).probe("b")
            }
            .probe("stack"),
            width: 200, height: 200
        )
        #expect(graph.frame("stack") == rect(50, 75, 100, 50))
        #expect(graph.frame("a") == rect(50, 75, 100, 20))
        #expect(graph.frame("b") == rect(50, 105, 40, 20))
    }

    @Test func spacerTakesRemainingSpace() {
        let graph = layout(
            HStack {
                Color.red.frame(width: 20, height: 20).probe("a")
                Spacer().probe("spacer")
                Color.blue.frame(width: 20, height: 20).probe("b")
            }
            .frame(width: 300),
            width: 300, height: 100
        )
        // A spacer has no spacing to its neighbors.
        #expect(graph.frame("a") == rect(0, 40, 20, 20))
        #expect(graph.frame("spacer").width == 260)
        #expect(graph.frame("b") == rect(280, 40, 20, 20))
    }

    @Test func spacerMinimumLengthWhenFixed() {
        let graph = layout(
            HStack {
                Color.red.frame(width: 20, height: 20)
                Spacer()
                Color.blue.frame(width: 20, height: 20)
            }
            .fixedSize()
            .probe("stack"),
            width: 300, height: 100
        )
        #expect(graph.frame("stack").size == CGSize(width: 48, height: 20))
    }

    @Test func layoutPriority() {
        let graph = layout(
            HStack(spacing: 0) {
                Color.red.frame(minWidth: 50).probe("a")
                Color.blue.frame(minWidth: 50).layoutPriority(1).probe("b")
            }
            .frame(width: 300, height: 50),
            width: 300, height: 50
        )
        // The higher priority view gets everything but the other's minimum.
        #expect(graph.frame("a").width == 50)
        #expect(graph.frame("b").width == 250)
    }

    @Test func padding() {
        let graph = layout(
            Color.red.frame(width: 40, height: 40).probe("inner")
                .padding(10)
                .padding(.horizontal, 5)
                .probe("outer"),
            width: 200, height: 200
        )
        #expect(graph.frame("outer") == rect(65, 70, 70, 60))
        #expect(graph.frame("inner") == rect(80, 80, 40, 40))
    }

    @Test func flexibleFrameAlignment() {
        let graph = layout(
            Color.red.frame(width: 30, height: 30).probe("inner")
                .frame(minWidth: 100, minHeight: 60, alignment: .topLeading)
                .probe("frame"),
            width: 300, height: 200
        )
        #expect(graph.frame("frame") == rect(100, 70, 100, 60))
        #expect(graph.frame("inner") == rect(100, 70, 30, 30))
    }

    @Test func infiniteMaxWidthFillsProposal() {
        let graph = layout(
            VStack {
                Color.red.frame(width: 50, height: 50).frame(maxWidth: .infinity).probe("wide")
            },
            width: 300, height: 100
        )
        #expect(graph.frame("wide") == rect(0, 25, 300, 50))
    }

    @Test func zstackAlignment() {
        let graph = layout(
            ZStack(alignment: .bottomTrailing) {
                Color.red.frame(width: 100, height: 80).probe("a")
                Color.blue.frame(width: 30, height: 20).probe("b")
            },
            width: 200, height: 200
        )
        #expect(graph.frame("a") == rect(50, 60, 100, 80))
        #expect(graph.frame("b") == rect(120, 120, 30, 20))
    }

    @Test func backgroundAndOverlay() {
        let graph = layout(
            Color.red.frame(width: 60, height: 40).probe("a")
                .background(alignment: .topLeading) { Color.blue.frame(width: 20, height: 20).probe("background") }
                .overlay { Color.green.probe("overlay") },
            width: 100, height: 100
        )
        #expect(graph.frame("a") == rect(20, 30, 60, 40))
        #expect(graph.frame("background") == rect(20, 30, 20, 20))
        #expect(graph.frame("overlay") == rect(20, 30, 60, 40))
        // Background first, then content, then overlay.
        let colors = graph.displayList().items.compactMap { item -> Color.Resolved? in
            if case let .content(.color(color)) = item.value { return color }
            return nil
        }
        let environment = EnvironmentValues()
        #expect(colors == [Color.blue, .red, .green].map { $0.resolve(in: environment) })
    }

    @Test func alignmentGuide() {
        let graph = layout(
            VStack(alignment: .leading, spacing: 0) {
                Color.red.frame(width: 50, height: 20).probe("a")
                Color.blue.frame(width: 50, height: 20).alignmentGuide(.leading) { _ in 20 }.probe("b")
            }
            .probe("stack"),
            width: 200, height: 200
        )
        // b's leading guide is 20 points in, so b starts 20 points before a.
        #expect(graph.frame("stack") == rect(65, 80, 70, 40))
        #expect(graph.frame("a") == rect(85, 80, 50, 20))
        #expect(graph.frame("b") == rect(65, 100, 50, 20))
    }

    @Test func offsetMovesContentOnly() {
        let graph = layout(
            HStack(spacing: 0) {
                Color.red.frame(width: 40, height: 40).probe("inner").offset(x: 10, y: 5).probe("a")
                Color.blue.frame(width: 40, height: 40).probe("b")
            },
            width: 200, height: 100
        )
        #expect(graph.frame("a") == rect(60, 30, 40, 40))
        #expect(graph.frame("inner") == rect(70, 35, 40, 40))
        #expect(graph.frame("b") == rect(100, 30, 40, 40))
    }

    @Test func idealSizeOfColor() {
        let graph = layout(
            HStack { Color.red; Color.blue }.fixedSize().probe("stack"),
            width: 200, height: 100
        )
        #expect(graph.frame("stack").size == CGSize(width: 28, height: 10))
    }

    @Test func customLayout() {
        struct Diagonal: Layout {
            func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout Void) -> CGSize {
                subviews.reduce(.zero) { size, subview in
                    let child = subview.sizeThatFits(.unspecified)
                    return CGSize(width: size.width + child.width, height: size.height + child.height)
                }
            }
            func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout Void) {
                var point = bounds.origin
                for subview in subviews {
                    let child = subview.sizeThatFits(.unspecified)
                    subview.place(at: point, proposal: .unspecified)
                    point.x += child.width
                    point.y += child.height
                }
            }
        }
        let graph = layout(
            Diagonal {
                Color.red.frame(width: 10, height: 20).probe("a")
                Color.blue.frame(width: 30, height: 10).probe("b")
            },
            width: 100, height: 100
        )
        #expect(graph.frame("a") == rect(30, 35, 10, 20))
        #expect(graph.frame("b") == rect(40, 55, 30, 10))
    }

    @Test func textWrapsToProposedWidth() {
        // The fixed engine: 0.5 × 17 = 8.5 points a character, 20.4 a line.
        let graph = layout(
            Text("Hello world").frame(width: 60).probe("text"),
            width: 200, height: 200
        )
        #expect(abs(graph.frame("text").height - 40.8) < 0.001)
    }

    @Test func firstTextBaselineAlignment() {
        let graph = layout(
            HStack(alignment: .firstTextBaseline) {
                Text("Big").font(.system(size: 40)).probe("big")
                Text("small").font(.system(size: 10)).probe("small")
            },
            width: 400, height: 200
        )
        let big = graph.frame("big")
        let small = graph.frame("small")
        #expect(abs((big.minY + 40 * 0.95) - (small.minY + 10 * 0.95)) < 0.001)
    }

    @Test func modifierFollowsACustomViewsBodyAsItChanges() {
        struct Growing: View {
            let model: AnimationModel
            @State private var taps = 0
            var body: some View {
                Button("Taps \(taps)") { taps += 1 }
                    .frame(width: 80, height: 20)
                    .probe("button")
                if model.flag {
                    Color.blue.frame(width: 20, height: 20).probe("extra")
                }
            }
        }
        let model = AnimationModel()
        let graph = layout(
            HStack(spacing: 0) {
                Growing(model: model).padding(5)
            }
            .probe("stack"),
            width: 300, height: 100
        )
        #expect(graph.frame("stack").width == 90)
        graph.tapText("Taps 0")
        graph.settle()
        // A second view gets its own padding, beside the first.
        model.flag = true
        graph.settle()
        #expect(graph.frame("stack").width == 120)
        #expect(graph.frame("extra").minX == graph.frame("button").maxX + 10)
        #expect(graph.texts.contains("Taps 1"))
        // Back to one view, padded once.
        model.flag = false
        graph.settle()
        #expect(graph.frame("stack").width == 90)
        #expect(graph.texts.contains("Taps 1"))
    }
}
