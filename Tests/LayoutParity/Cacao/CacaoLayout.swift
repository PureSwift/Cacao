//
//  CacaoLayout.swift
//  CacaoParityCacao
//
//  Lays out the corpus with Cacao.
//

import Cacao
import Foundation
#if canImport(CoreGraphics)
import CoreGraphics
#endif

extension View {

    /// Records the view's frame in the root's coordinate space.
    func probe(_ name: String) -> some View {
        accessibilityIdentifier(name)
    }
}

@MainActor
public enum CacaoLayout {

    /// The names of the corpus's cases.
    public static var caseNames: [String] {
        LayoutCorpus.cases.map(\.name)
    }

    /// The frames of the probed views in a case, laid out by Cacao.
    public static func frames(of name: String) -> [String: CGRect] {
        guard let layoutCase = LayoutCorpus.cases.first(where: { $0.name == name }) else {
            return [:]
        }
        let size = layoutCase.size
        let graph = ViewGraph(rootView: layoutCase.view.frame(width: size.width, height: size.height))
        graph.layout(in: size)
        return graph.identifiedFrames()
    }
}
