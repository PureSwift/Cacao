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
                case .content(.shape), .content(.roundedRectangle): [item.frame]
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

    private func settle(_ graph: ViewGraph) {
        let size = CGSize(width: 200, height: 40)
        graph.update()
        graph.layout(in: size)
        graph.advanceAnimations(to: graph.time + 5)
        graph.update()
        graph.layout(in: size)
    }

    private func drag(_ graph: ViewGraph, from start: CGPoint, by distance: CGFloat) {
        graph.pointer(.began, at: start, time: 0)
        for step in 1...4 {
            graph.pointer(.moved, at: CGPoint(x: start.x + distance * CGFloat(step) / 4, y: start.y), time: Double(step) * 0.02)
        }
        graph.pointer(.ended, at: CGPoint(x: start.x + distance, y: start.y), time: 0.1)
        settle(graph)
    }

    @Test func draggingRightTurnsItOnAndLeftOff() {
        let model = Model()
        model.isOn = false
        let graph = ViewGraph(rootView: Content(model: model), textEngine: FixedTextEngine())
        graph.layout(in: CGSize(width: 200, height: 40))
        let knob = CGPoint(x: 178, y: 20)
        drag(graph, from: knob, by: 30)
        #expect(model.isOn == true)
        #expect(shapes(graph)[1].midX > shapes(graph)[0].midX)
        // Dragging right again leaves it on.
        drag(graph, from: knob, by: 30)
        #expect(model.isOn == true)
        drag(graph, from: knob, by: -30)
        #expect(model.isOn == false)
        #expect(shapes(graph)[1].midX < shapes(graph)[0].midX)
        drag(graph, from: knob, by: -30)
        #expect(model.isOn == false)
    }

    @Test func aShortDragFallsBackToWhereItWas() {
        let model = Model()
        let graph = ViewGraph(rootView: Content(model: model), textEngine: FixedTextEngine())
        graph.layout(in: CGSize(width: 200, height: 40))
        // On, dragged left by less than half the knob's travel.
        drag(graph, from: CGPoint(x: 178, y: 20), by: -7)
        #expect(model.isOn == true)
    }

    @Test func theKnobSlidesRatherThanJumps() {
        let model = Model()
        let graph = ViewGraph(rootView: Content(model: model), textEngine: FixedTextEngine())
        let size = CGSize(width: 200, height: 40)
        graph.layout(in: size)
        let on = shapes(graph)[1].midX
        graph.advanceAnimations(to: 1)
        graph.pointer(.began, at: CGPoint(x: 100, y: 20), time: 1)
        graph.pointer(.ended, at: CGPoint(x: 100, y: 20), time: 1)
        #expect(model.isOn == false)
        graph.update()
        graph.layout(in: size)
        // Part of the way there, a moment into the animation.
        graph.advanceAnimations(to: 1.06)
        graph.update()
        graph.layout(in: size)
        let moving = shapes(graph)[1].midX
        graph.advanceAnimations(to: 3)
        graph.update()
        graph.layout(in: size)
        let off = shapes(graph)[1].midX
        #expect(off < on)
        #expect(moving < on)
        #expect(moving > off)
    }
}
