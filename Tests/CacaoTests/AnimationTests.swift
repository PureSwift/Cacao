import Foundation
#if canImport(CoreGraphics)
import CoreGraphics
#endif
import Observation
import Testing
@testable import Cacao

/// A drawn item, with the opacity and transforms of its ancestors.
struct DrawnItem {
    let item: DisplayList.Item
    let opacity: Double
    let transforms: [Transform2D]
}

extension ViewGraph {

    /// Every content item in the display list, in drawing order.
    var drawnItems: [DrawnItem] {
        func collect(_ list: DisplayList, opacity: Double, transforms: [Transform2D]) -> [DrawnItem] {
            list.items.flatMap { item -> [DrawnItem] in
                switch item.value {
                case .content:
                    return [DrawnItem(item: item, opacity: opacity, transforms: transforms)]
                case let .effect(.opacity(value), nested):
                    return collect(nested, opacity: opacity * value, transforms: transforms)
                case let .effect(.transform(transform), nested):
                    return collect(nested, opacity: opacity, transforms: transforms + [transform])
                case let .effect(_, nested):
                    return collect(nested, opacity: opacity, transforms: transforms)
                }
            }
        }
        return collect(displayList(), opacity: 1, transforms: [])
    }

    /// The drawn color items.
    var colorItems: [(color: Color.Resolved, frame: CGRect, opacity: Double)] {
        drawnItems.compactMap { drawn in
            guard case let .content(.color(color)) = drawn.item.value else { return nil }
            return (color, drawn.item.frame, drawn.opacity)
        }
    }

    /// Moves to a time and settles the updates it causes.
    func advance(to time: Double) {
        advanceAnimations(to: time)
        settle()
    }
}

@Observable
@MainActor
final class AnimationModel {
    var flag = false
}

@MainActor
@Suite struct AnimationCurveTests {

    @Test func linearProgress() {
        let animation = Animation.linear(duration: 2)
        #expect(animation.progress(at: 0).value == 0)
        #expect(animation.progress(at: 1).value == 0.5)
        #expect(animation.progress(at: 2).isFinished)
    }

    @Test func easeInOutIsSymmetric() {
        let animation = Animation.easeInOut(duration: 1)
        let value = animation.progress(at: 0.5).value
        #expect(abs(value - 0.5) < 0.01)
        #expect(animation.progress(at: 0.25).value < 0.25)
    }

    @Test func springSettles() {
        let animation = Animation.spring(response: 0.5, dampingFraction: 0.5)
        var overshoots = false
        var time = 0.0
        while !animation.progress(at: time).isFinished {
            if animation.progress(at: time).value > 1.01 { overshoots = true }
            time += 1.0 / 60
            #expect(time < 11)
        }
        #expect(overshoots)
        #expect(animation.progress(at: time).value == 1)
    }

    @Test func delayAndSpeed() {
        let animation = Animation.linear(duration: 1).delay(0.5).speed(2)
        #expect(animation.progress(at: 0.4).value == 0)
        // Half a second in its own time, after the delay.
        #expect(abs(animation.progress(at: 0.5 + 0.25).value - 0.5) < 0.001)
    }

    @Test func repeatAutoreverses() {
        let animation = Animation.linear(duration: 1).repeatCount(2)
        #expect(abs(animation.progress(at: 1.5).value - 0.5) < 0.001)
        #expect(animation.progress(at: 1.75).value < 0.5)
        let ended = animation.progress(at: 2)
        #expect(ended.isFinished && ended.value == 0)
        #expect(!Animation.linear(duration: 1).repeatForever().progress(at: 100.5).isFinished)
    }
}

@MainActor
@Suite struct AnimationTests {

    struct Resizing: View {
        let model: AnimationModel
        var body: some View {
            VStack {
                Color.red.frame(width: model.flag ? 200 : 100, height: 50)
                Spacer()
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    @Test func withAnimationInterpolatesFrames() {
        let model = AnimationModel()
        let graph = layout(Resizing(model: model))
        #expect(graph.colorItems.first?.frame.width == 100)
        withAnimation(.linear(duration: 1)) { model.flag = true }
        graph.settle()
        #expect(graph.hasActiveAnimations)
        #expect(graph.colorItems.first?.frame.width == 100)
        graph.advance(to: 0.5)
        #expect(graph.colorItems.first?.frame.width == 150)
        graph.advance(to: 1)
        #expect(graph.colorItems.first?.frame.width == 200)
        #expect(!graph.hasActiveAnimations)
    }

    @Test func changesWithoutAnimationJump() {
        let model = AnimationModel()
        let graph = layout(Resizing(model: model))
        model.flag = true
        graph.settle()
        #expect(!graph.hasActiveAnimations)
        #expect(graph.colorItems.first?.frame.width == 200)
    }

    @Test func retargetingStartsFromPresentation() {
        let model = AnimationModel()
        let graph = layout(Resizing(model: model))
        withAnimation(.linear(duration: 1)) { model.flag = true }
        graph.settle()
        graph.advance(to: 0.5)
        withAnimation(.linear(duration: 1)) { model.flag = false }
        graph.settle()
        // Back from 150, where it was, not from 200.
        #expect(graph.colorItems.first?.frame.width == 150)
        graph.advance(to: 1)
        #expect(graph.colorItems.first?.frame.width == 125)
    }

    @Test func implicitAnimationModifier() {
        struct Implicit: View {
            let model: AnimationModel
            var body: some View {
                Color.blue
                    .frame(width: 100, height: model.flag ? 100 : 20)
                    .animation(.linear(duration: 2), value: model.flag)
            }
        }
        let model = AnimationModel()
        let graph = layout(Implicit(model: model))
        model.flag = true
        graph.settle()
        graph.advance(to: 1)
        #expect(graph.colorItems.first?.frame.height == 60)
        graph.advance(to: 2)
        #expect(graph.colorItems.first?.frame.height == 100)
    }

    @Test func opacityAnimates() {
        struct Fading: View {
            let model: AnimationModel
            var body: some View {
                Color.red.frame(width: 50, height: 50).opacity(model.flag ? 0 : 1)
            }
        }
        let model = AnimationModel()
        let graph = layout(Fading(model: model))
        withAnimation(.linear(duration: 1)) { model.flag = true }
        graph.settle()
        graph.advance(to: 0.5)
        #expect(abs((graph.colorItems.first?.opacity ?? 0) - 0.5) < 0.001)
        graph.advance(to: 1)
        #expect((graph.colorItems.first?.opacity ?? 1) == 0)
    }

    @Test func colorAnimates() {
        struct Tinting: View {
            let model: AnimationModel
            var body: some View {
                (model.flag ? Color(red: 1, green: 0, blue: 0) : Color(red: 0, green: 0, blue: 1))
                    .frame(width: 50, height: 50)
            }
        }
        let model = AnimationModel()
        let graph = layout(Tinting(model: model))
        withAnimation(.linear(duration: 1)) { model.flag = true }
        graph.settle()
        graph.advance(to: 0.5)
        let color = graph.colorItems.first?.color
        #expect(abs((color?.red ?? 0) - 0.5) < 0.01)
        #expect(abs((color?.blue ?? 0) - 0.5) < 0.01)
    }

    @Test func insertionFadesIn() {
        struct Inserting: View {
            let model: AnimationModel
            var body: some View {
                VStack {
                    if model.flag {
                        Color.green.frame(width: 50, height: 50)
                    }
                }
            }
        }
        let model = AnimationModel()
        let graph = layout(Inserting(model: model))
        #expect(graph.colorItems.isEmpty)
        withAnimation(.linear(duration: 1)) { model.flag = true }
        graph.settle()
        #expect(graph.colorItems.first?.opacity == 0)
        graph.advance(to: 0.5)
        #expect(abs((graph.colorItems.first?.opacity ?? 0) - 0.5) < 0.001)
        graph.advance(to: 1)
        #expect(graph.colorItems.first?.opacity == 1)
    }

    @Test func removalTransitionsOut() {
        struct Removing: View {
            let model: AnimationModel
            var body: some View {
                VStack {
                    if !model.flag {
                        Color.green.frame(width: 50, height: 50)
                            .transition(.scale)
                    }
                }
            }
        }
        let model = AnimationModel()
        let graph = layout(Removing(model: model))
        withAnimation(.linear(duration: 1)) { model.flag = true }
        graph.settle()
        graph.advance(to: 0.5)
        let drawn = graph.drawnItems.filter { if case .content(.color) = $0.item.value { true } else { false } }
        #expect(drawn.count == 1)
        #expect(drawn.first?.transforms.first.map { abs($0.a - 0.5) < 0.001 } == true)
        graph.advance(to: 1)
        #expect(graph.colorItems.isEmpty)
        #expect(!graph.hasActiveAnimations)
    }

    @Test func disablesAnimations() {
        let model = AnimationModel()
        let graph = layout(Resizing(model: model))
        var transaction = Transaction(animation: .linear(duration: 1))
        transaction.disablesAnimations = true
        withTransaction(transaction) { model.flag = true }
        graph.settle()
        #expect(!graph.hasActiveAnimations)
        #expect(graph.colorItems.first?.frame.width == 200)
    }

    @Test func animatableViewReResolves() {
        struct Counter: View, Animatable {
            var value: Double
            nonisolated var animatableData: Double {
                get { value }
                set { value = newValue }
            }
            var body: some View {
                Text("\(Int(value.rounded()))")
            }
        }
        struct Host: View {
            let model: AnimationModel
            var body: some View {
                Counter(value: model.flag ? 100 : 0)
            }
        }
        let model = AnimationModel()
        let graph = layout(Host(model: model))
        #expect(graph.texts == ["0"])
        withAnimation(.linear(duration: 1)) { model.flag = true }
        graph.settle()
        graph.advance(to: 0.25)
        #expect(graph.texts == ["25"])
        graph.advance(to: 1)
        #expect(graph.texts == ["100"])
        #expect(!graph.hasActiveAnimations)
    }

    @Test func scaleEffectAddsTransform() {
        let graph = layout(Color.red.frame(width: 100, height: 100).scaleEffect(2), width: 100, height: 100)
        let transform = graph.drawnItems.first?.transforms.first
        #expect(transform?.a == 2)
        #expect(transform?.d == 2)
        // Scaled around the center.
        #expect(transform?.apply(CGPoint(x: 50, y: 50)) == CGPoint(x: 50, y: 50))
    }

    @Test func matchedGeometryMovesBetweenViews() {
        struct Matched: View {
            let model: AnimationModel
            let namespace: Namespace.ID
            var body: some View {
                VStack(spacing: 0) {
                    if !model.flag {
                        Color.red.frame(width: 50, height: 50)
                            .matchedGeometryEffect(id: "box", in: namespace)
                    }
                    Spacer()
                    if model.flag {
                        Color.red.frame(width: 50, height: 50)
                            .matchedGeometryEffect(id: "box", in: namespace)
                    }
                }
            }
        }
        let model = AnimationModel()
        let graph = layout(Matched(model: model, namespace: Namespace().wrappedValue), width: 100, height: 200)
        #expect(graph.colorItems.first?.frame.minY == 0)
        withAnimation(.linear(duration: 1)) { model.flag = true }
        graph.settle()
        graph.advance(to: 0.5)
        // The moving view is halfway: at the destination, moved up by half.
        let moving = graph.drawnItems.filter { $0.item.frame.minY == 150 && !$0.transforms.isEmpty }
        #expect(moving.count == 1)
        let point = moving.first?.transforms.reduce(CGPoint(x: 25, y: 175)) { $1.apply($0) }
        #expect(point.map { abs($0.y - 100) < 0.5 } == true)
    }

    @Test func matchedGeometryFollowerTracksSource() {
        struct Tabs: View {
            let model: AnimationModel
            let namespace: Namespace.ID
            var body: some View {
                HStack(spacing: 0) {
                    ForEach(0..<2) { index in
                        Color.clear.frame(width: 50, height: 20)
                            .matchedGeometryEffect(id: index, in: namespace)
                    }
                }
                .overlay {
                    Color.blue
                        .matchedGeometryEffect(id: model.flag ? 1 : 0, in: namespace, isSource: false)
                }
            }
        }
        let model = AnimationModel()
        let graph = layout(Tabs(model: model, namespace: Namespace().wrappedValue), width: 100, height: 20)
        // The indicator takes the first tab's frame, not the overlay's.
        func indicator() -> CGRect? {
            graph.colorItems.last { $0.color == Color.blue.resolve(in: EnvironmentValues()) }?.frame
        }
        #expect(indicator() == CGRect(x: 0, y: 0, width: 50, height: 20))
        withAnimation(.linear(duration: 1)) { model.flag = true }
        graph.settle()
        graph.advance(to: 0.5)
        #expect(indicator()?.minX == 25)
        graph.advance(to: 1)
        #expect(indicator() == CGRect(x: 50, y: 0, width: 50, height: 20))
    }
}

@MainActor
@Suite struct PrimitiveObservationTests {

    @Test func forEachContentTracksObservableReads() {
        struct Rows: View {
            let model: AnimationModel
            var body: some View {
                VStack {
                    ForEach(0..<2) { index in
                        Text(model.flag ? "On \(index)" : "Off \(index)")
                    }
                }
            }
        }
        let model = AnimationModel()
        let graph = layout(Rows(model: model))
        #expect(graph.texts == ["Off 0", "Off 1"])
        model.flag = true
        graph.settle()
        #expect(graph.texts == ["On 0", "On 1"])
    }

    @Test func canvasRedrawsWhenObservableReadsChange() {
        let model = AnimationModel()
        let graph = layout(Canvas { context, size in
            context.fill(Path(CGRect(origin: .zero, size: size)), with: .color(model.flag ? .red : .blue))
        })
        func color() -> Color.Resolved? {
            graph.drawnItems.compactMap { drawn -> Color.Resolved? in
                guard case let .content(.drawing(drawing)) = drawn.item.value,
                      case let .shape(shape, _) = drawing.operations.first else { return nil }
                return shape.color
            }.first
        }
        #expect(color() == Color.blue.resolve(in: EnvironmentValues()))
        model.flag = true
        #expect(graph.needsUpdate)
        graph.settle()
        #expect(color() == Color.red.resolve(in: EnvironmentValues()))
    }
}
