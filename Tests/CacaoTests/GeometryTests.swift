import Foundation
#if canImport(CoreGraphics)
import CoreGraphics
#endif
import Testing
@testable import Cacao

private struct BoundsKey: PreferenceKey {
    static let defaultValue: Anchor<CGRect>? = nil
    static func reduce(value: inout Anchor<CGRect>?, nextValue: () -> Anchor<CGRect>?) {
        value = value ?? nextValue()
    }
}

@MainActor
@Suite struct GeometryTests {

    @Test func readerContentSeesItsSize() {
        let graph = layout(
            GeometryReader { proxy in
                Text("\(Int(proxy.size.width))x\(Int(proxy.size.height))")
            },
            width: 300, height: 200
        )
        #expect(graph.texts == ["300x200"])
        graph.layout(in: CGSize(width: 250, height: 100))
        #expect(graph.texts == ["250x100"])
    }

    @Test func frameInCoordinateSpaces() {
        let graph = layout(
            VStack(spacing: 0) {
                Color.clear.frame(height: 40)
                HStack(spacing: 0) {
                    Color.clear.frame(width: 30)
                    GeometryReader { proxy in
                        let global = proxy.frame(in: .global)
                        let named = proxy.frame(in: .named("stack"))
                        Text("\(Int(global.minX)),\(Int(global.minY)) \(Int(named.minX)),\(Int(named.minY))")
                    }
                }
                .coordinateSpace(.named("stack"))
            },
            width: 200, height: 200
        )
        #expect(graph.texts == ["30,40 30,0"])
    }

    @Test func readerUpdatesWhenItMoves() {
        struct Moving: View {
            @State var offset: CGFloat = 0
            var body: some View {
                VStack(spacing: 0) {
                    Text("Move").onTapGesture { offset = 50 }
                        .frame(height: 20)
                    Color.clear.frame(height: offset)
                    GeometryReader { proxy in
                        Text("y \(Int(proxy.frame(in: .global).minY))")
                    }
                    .frame(height: 30)
                    Spacer()
                }
            }
        }
        let graph = layout(Moving(), width: 200, height: 300)
        #expect(graph.texts.contains("y 20"))
        graph.tapText("Move")
        graph.settle()
        #expect(graph.texts.contains("y 70"))
    }

    @Test func anchorPreferenceResolvesInOverlay() {
        let graph = layout(
            VStack(alignment: .leading, spacing: 0) {
                Color.clear.frame(height: 30)
                Color.red.frame(width: 40, height: 20)
                    .anchorPreference(key: BoundsKey.self, value: .bounds) { $0 }
            }
            .frame(width: 200, height: 100, alignment: .topLeading)
            .overlayPreferenceValue(BoundsKey.self) { anchor in
                GeometryReader { proxy in
                    if let anchor {
                        let rect = proxy[anchor]
                        Text("\(Int(rect.minX)),\(Int(rect.minY)) \(Int(rect.width))x\(Int(rect.height))")
                    }
                }
            },
            width: 200, height: 100
        )
        #expect(graph.texts == ["0,30 40x20"])
    }

    @Test func geometryChangeReportsValues() {
        let log = GestureLog()
        struct Sized: View {
            let log: GestureLog
            @State var wide = false
            var body: some View {
                VStack {
                    Text("Grow").onTapGesture { wide = true }
                    Color.red.frame(width: wide ? 100 : 50, height: 10)
                        .onGeometryChange(for: CGFloat.self) { $0.size.width } action: { log.log("\(Int($0))") }
                }
            }
        }
        let graph = layout(Sized(log: log))
        #expect(log.events == ["50"])
        graph.tapText("Grow")
        graph.settle()
        #expect(log.events == ["50", "100"])
    }

    @Test func viewThatFitsPicksFirstFittingCandidate() {
        func fitting(width: CGFloat) -> [String] {
            layout(
                ViewThatFits(in: .horizontal) {
                    Text("A long label that needs room")
                    Text("Short")
                },
                width: width, height: 50
            ).texts
        }
        #expect(fitting(width: 400) == ["A long label that needs room"])
        #expect(fitting(width: 40) == ["Short"])
    }

    @Test func zIndexOrdersDrawingAndHits() {
        let log = GestureLog()
        let graph = layout(
            ZStack {
                Color.red.frame(width: 50, height: 50).zIndex(1).onTapGesture { log.log("red") }
                Color.blue.frame(width: 50, height: 50).onTapGesture { log.log("blue") }
            },
            width: 100, height: 100
        )
        // Red draws last, in front.
        #expect(graph.colorItems.last?.color == Color.red.resolve(in: EnvironmentValues()))
        graph.click(CGPoint(x: 50, y: 50), at: 1)
        #expect(log.events == ["red"])
    }

    @Test func ignoresSafeAreaExtendsToWindowEdges() {
        let graph = ViewGraph(rootView: Color.red.probe("inner").ignoresSafeArea().probe("outer"))
        graph.safeAreaInsets = EdgeInsets(top: 20, leading: 0, bottom: 10, trailing: 0)
        graph.layout(in: CGSize(width: 100, height: 100))
        #expect(graph.frame("outer") == rect(0, 20, 100, 70))
        #expect(graph.frame("inner") == rect(0, 0, 100, 100))
    }
}
