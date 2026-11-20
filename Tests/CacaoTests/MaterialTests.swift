import CacaoRender
import Foundation
#if canImport(CoreGraphics)
import CoreGraphics
#endif
import Testing
@testable import Cacao

@MainActor
@Suite struct MaterialTests {

    /// The backdrops and filled shapes drawn, back to front.
    private func contents(_ view: some View, size: CGSize = CGSize(width: 200, height: 100)) -> [(DisplayList.Content, CGRect)] {
        let graph = ViewGraph(rootView: view, textEngine: FixedTextEngine())
        graph.layout(in: size)
        var found: [(DisplayList.Content, CGRect)] = []
        func collect(_ items: [DisplayList.Item]) {
            for item in items {
                switch item.value {
                case let .content(content):
                    switch content {
                    case .backdrop, .shape, .color: found.append((content, item.frame))
                    default: break
                    }
                case let .effect(_, nested): collect(nested.items)
                }
            }
        }
        collect(graph.displayList().items)
        return found
    }

    private func backdrops(_ contents: [(DisplayList.Content, CGRect)]) -> [(BackdropContent, CGRect)] {
        contents.compactMap { content, frame in
            if case let .backdrop(backdrop) = content { (backdrop, frame) } else { nil }
        }
    }

    @Test func aMaterialBackgroundIsABackdropUnderATint() {
        let drawn = contents(Text("Hi").frame(width: 80, height: 40).background(.regularMaterial))
        let found = backdrops(drawn)
        #expect(found.count == 1)
        #expect(found.first?.1.size == CGSize(width: 80, height: 40))
        #expect(found.first?.0.blurRadius == 20)
        #expect(found.first?.0.cornerRadius == 0)
        // The backdrop first, then the tint over it, translucent.
        guard case .backdrop = drawn.first?.0 else {
            Issue.record("the backdrop isn't drawn first")
            return
        }
        guard drawn.count >= 2, case let .shape(tint) = drawn[1].0 else {
            Issue.record("no tint over the backdrop")
            return
        }
        #expect(tint.color.opacity > 0.5)
        #expect(tint.color.opacity < 0.7)
    }

    @Test func thinnerMaterialsLetMoreThrough() {
        func opacity(_ material: Material) -> Float {
            let drawn = contents(Color.clear.frame(width: 50, height: 50).background(material))
            for (content, _) in drawn {
                if case let .shape(shape) = content { return shape.color.opacity }
            }
            return -1
        }
        let opacities = [Material.ultraThin, .thin, .regular, .thick, .ultraThick].map(opacity)
        #expect(opacities.allSatisfy { $0 > 0 })
        #expect(zip(opacities, opacities.dropFirst()).allSatisfy { $0 < $1 })
    }

    @Test func theBackdropTakesItsShapesCorners() {
        let rounded = backdrops(contents(
            Color.clear.frame(width: 100, height: 60).background(.thinMaterial, in: RoundedRectangle(cornerRadius: 12))
        ))
        #expect(rounded.first?.0.cornerRadius == 12)
        let capsule = backdrops(contents(
            Color.clear.frame(width: 100, height: 60).background(.thinMaterial, in: Capsule())
        ))
        #expect(capsule.first?.0.cornerRadius == 30)
        let filled = backdrops(contents(RoundedRectangle(cornerRadius: 8).fill(.ultraThinMaterial).frame(width: 40, height: 40)))
        #expect(filled.first?.0.cornerRadius == 8)
    }

    @Test func theTintFollowsTheColorScheme() {
        func brightness(_ scheme: ColorScheme) -> Float {
            let drawn = contents(Color.clear.frame(width: 50, height: 50).background(.regularMaterial).environment(\.colorScheme, scheme))
            for (content, _) in drawn {
                if case let .shape(shape) = content { return shape.color.red }
            }
            return -1
        }
        #expect(brightness(.light) > 0.9)
        #expect(brightness(.dark) < 0.2)
    }
}
