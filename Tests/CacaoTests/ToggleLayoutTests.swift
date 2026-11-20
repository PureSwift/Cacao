import CacaoRender
import Foundation
#if canImport(CoreGraphics)
import CoreGraphics
#endif
import Testing
@testable import Cacao

@MainActor
@Suite struct ToggleLayoutTests {

    @MainActor
    final class Model: ObservableObject {
        @Published var isOn = true
    }

    struct Content: View {
        @ObservedObject var model: Model
        var body: some View {
            Toggle("Notifications", isOn: $model.isOn)
                .frame(width: 200, height: 40)
        }
    }

    /// The frames of the shapes drawn, back to front.
    private func shapes(_ graph: ViewGraph) -> [CGRect] {
        func collect(_ items: [DisplayList.Item]) -> [CGRect] {
            items.flatMap { item -> [CGRect] in
                switch item.value {
                case .content(.shape): [item.frame]
                case .content: []
                case let .effect(_, nested): collect(nested.items)
                }
            }
        }
        return collect(graph.displayList().items)
    }

    @Test func theKnobMovesWhenTheSwitchIsTapped() {
        let model = Model()
        let graph = ViewGraph(rootView: Content(model: model), textEngine: FixedTextEngine())
        let size = CGSize(width: 200, height: 40)
        graph.layout(in: size)
        let on = shapes(graph)
        // The track, then the knob at its trailing end.
        #expect(on.count == 2)
        #expect(on[1].midX > on[0].midX)

        graph.pointer(.began, at: CGPoint(x: 180, y: 20))
        graph.pointer(.ended, at: CGPoint(x: 180, y: 20))
        #expect(model.isOn == false)
        graph.update()
        graph.layout(in: size)
        graph.advanceAnimations(to: 10)
        let off = shapes(graph)
        #expect(off.count == 2)
        #expect(off[0] == on[0])
        // The knob is at the leading end.
        #expect(off[1].midX < off[0].midX)
    }
}
