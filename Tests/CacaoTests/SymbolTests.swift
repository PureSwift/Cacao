import CacaoRender
import Foundation
#if canImport(CoreGraphics)
import CoreGraphics
#endif
import Testing
@testable import Cacao

@MainActor
@Suite struct SymbolTests {

    func drawing(_ graph: ViewGraph) -> DrawingContent? {
        graph.displayList().items.compactMap { item -> DrawingContent? in
            if case let .content(.drawing(drawing)) = item.value { return drawing }
            return nil
        }.first
    }

    @Test func symbolsDrawInTheForegroundAtTheFontSize() {
        let graph = layout(Image(systemName: "star.fill").foregroundStyle(.red).font(.system(size: 20)).probe("star"))
        #expect(graph.frame("star").size == CGSize(width: 20, height: 20))
        let shapes = drawing(graph)?.operations.compactMap { operation -> ShapeContent? in
            if case let .shape(shape, _) = operation { return shape }
            return nil
        } ?? []
        #expect(shapes.count == 1)
        #expect(shapes.first?.color == Color.red.resolve(in: EnvironmentValues()))
        if case .fill = shapes.first?.drawing { } else { Issue.record("A filled star") }
    }

    @Test func imageScaleSizesSymbols() {
        let graph = layout(HStack {
            Image(systemName: "plus").imageScale(.small).probe("small")
            Image(systemName: "plus").imageScale(.large).probe("large")
        }.font(.system(size: 20)))
        #expect(graph.frame("small").width == 16)
        #expect(graph.frame("large").width == 26)
    }

    @Test func enclosedSymbolsKnockOutTheirGlyph() {
        let parts = Symbols.parts("checkmark.circle.fill")
        #expect(parts?.count == 2)
        #expect(parts?.first?.isFilled == true)
        #expect(parts?.last?.isKnockout == true)
        #expect(Symbols.parts("checkmark.circle")?.last?.isKnockout == false)
        #expect(Symbols.parts("no.such.symbol") == nil)
    }

    @Test func unknownSymbolsKeepTheirSize() {
        let graph = layout(Image(systemName: "no.such.symbol").font(.system(size: 20)).probe("unknown"))
        #expect(graph.frame("unknown").size == CGSize(width: 20, height: 20))
        #expect(drawing(graph) == nil)
    }
}
