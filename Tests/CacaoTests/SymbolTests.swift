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
        // Phosphor has no trash in a circle, so Cacao encloses its trash.
        let trash = Symbols.parts("trash")?.count ?? 0
        let parts = Symbols.parts("trash.circle.fill")
        #expect(trash > 0)
        #expect(parts?.count == trash + 1)
        #expect(parts?.first?.isFilled == true)
        #expect(parts?.last?.isKnockout == true)
        #expect(Symbols.parts("trash.circle")?.last?.isKnockout == false)
        #expect(Symbols.parts("trash.square")?.count == trash + 1)
        #expect(Symbols.parts("no.such.symbol") == nil)
        #expect(Symbols.parts("no.such.symbol.circle.fill") == nil)
    }

    @Test func symbolNamesAcrossCategoriesHaveDrawings() {
        let names = [
            "chevron.right", "arrow.up.right", "arrow.triangle.2.circlepath", "square.and.arrow.up",
            "plus", "xmark", "checkmark", "magnifyingglass", "gearshape", "house", "person.2",
            "trash", "folder.badge.plus", "doc.on.doc", "envelope.open", "bell", "bookmark",
            "calendar", "clock", "photo", "camera", "play", "speaker.wave.2", "mic", "wifi",
            "battery.100percent", "cart", "creditcard", "sidebar.left", "text.alignleft",
            "airplane", "cloud.rain", "sun.max", "moon", "bolt", "leaf", "chart.bar", "trophy",
            // Names Cacao draws itself, which Phosphor has nothing for.
            "info",
        ]
        for name in names {
            #expect(Symbols.parts(name)?.isEmpty == false, "\(name)")
        }
        #expect(Symbols.glyphNameCount > 500)
    }

    @Test func otherNamesForASymbolDrawTheSame() {
        func paths(_ name: String) -> [Path]? { Symbols.parts(name)?.map(\.path) }
        #expect(paths("chevron.backward") == paths("chevron.left"))
        #expect(paths("gear") == paths("gearshape"))
        #expect(paths("multiply.circle.fill") == paths("xmark.circle.fill"))
        #expect(paths("chevron.left") != paths("chevron.right"))
    }

    @Test func filledSymbolsHaveTheirOwnDrawing() {
        for name in ["heart", "house", "bell", "person", "folder", "checkmark.circle", "exclamationmark.triangle"] {
            let outline = Symbols.parts(name)
            let filled = Symbols.parts(name + ".fill")
            #expect(outline?.contains { !$0.isFilled } == true, "\(name)")
            #expect(filled?.isEmpty == false && filled?.allSatisfy(\.isFilled) == true, "\(name).fill")
            #expect(filled?.contains(where: \.isKnockout) == false, "\(name).fill")
        }
    }

    @Test func slashedSymbolsUsePhosphorsOrAreStruckThrough() {
        // Phosphor draws a slashed bell.
        #expect(Symbols.parts("bell.slash")?.map(\.path) == Symbols.glyph("bell.slash", filled: false)?.map(\.path))
        // It has no slashed trash, so the trash gets a stroke through it.
        #expect(Symbols.glyph("trash.slash", filled: false) == nil)
        let trash = Symbols.parts("trash")?.count ?? 0
        let slashed = Symbols.parts("trash.slash")
        #expect(slashed?.count == trash + 1)
        #expect(slashed?.last?.isFilled == false)
        #expect(slashed?.last?.isKnockout == false)
        #expect(Symbols.parts("trash.slash.fill")?.first?.isFilled == true)
        #expect(Symbols.parts("trash.slash.circle.fill")?.count == trash + 2)
    }

    @Test func mirroredSymbolsFaceTheOtherWay() {
        func bounds(_ name: String) -> CGRect? {
            Symbols.parts(name).map { $0.reduce(CGRect.null) { $0.union($1.path.boundingRect) } }
        }
        guard let left = bounds("sidebar.left"), let right = bounds("sidebar.right") else {
            Issue.record("Sidebars")
            return
        }
        #expect(abs(left.minX - (1 - right.maxX)) < 0.001)
        #expect(Symbols.parts("sidebar.left")?.map(\.path) != Symbols.parts("sidebar.right")?.map(\.path))
    }

    @Test func symbolsStayAboutTheirSquare() {
        for name in ["house", "star.fill", "gearshape", "globe", "arrow.left", "person.2.fill", "battery.100percent"] {
            let bounds = (Symbols.parts(name) ?? []).reduce(CGRect.null) { $0.union($1.path.boundingRect) }
            #expect(bounds.minX > -0.1 && bounds.minY > -0.1 && bounds.maxX < 1.1 && bounds.maxY < 1.1, "\(name)")
            #expect(max(bounds.width, bounds.height) > 0.6, "\(name)")
        }
    }

    @Test func strokesFollowTheFontWeight() {
        func lineWidth(_ weight: Font.Weight) -> CGFloat? {
            let graph = layout(Image(systemName: "house").font(.system(size: 100, weight: weight)))
            for case let .shape(shape, _) in drawing(graph)?.operations ?? [] {
                if case let .stroke(style) = shape.drawing { return style.lineWidth }
            }
            return nil
        }
        guard let light = lineWidth(.light), let regular = lineWidth(.regular), let bold = lineWidth(.bold) else {
            Issue.record("A stroked house")
            return
        }
        #expect(light < regular && regular < bold)
        // Phosphor's regular stroke: 16 of 256, enlarged like the glyph.
        #expect(abs(regular - 16.0 / 256 * 1.15) < 0.0001)
        #expect(abs(bold / regular - 1.5) < 0.0001)
    }

    @Test func originalSymbolsIgnoreTheForegroundStyle() {
        let graph = layout(Image(systemName: "heart.fill").renderingMode(.original).foregroundStyle(.red))
        let colors = (drawing(graph)?.operations ?? []).compactMap { operation -> Color.Resolved? in
            if case let .shape(shape, _) = operation { return shape.color }
            return nil
        }
        #expect(colors == [Color.primary.resolve(in: EnvironmentValues())])
    }

    @Test func unknownSymbolsKeepTheirSize() {
        let graph = layout(Image(systemName: "no.such.symbol").font(.system(size: 20)).probe("unknown"))
        #expect(graph.frame("unknown").size == CGSize(width: 20, height: 20))
        #expect(drawing(graph) == nil)
    }
}
