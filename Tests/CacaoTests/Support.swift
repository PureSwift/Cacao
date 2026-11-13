import Foundation
#if canImport(CoreGraphics)
import CoreGraphics
#endif
import Testing
@testable import Cacao

/// Lays out a view in a container of the given size.
@MainActor
func layout<V: View>(_ view: V, width: CGFloat = 400, height: CGFloat = 300) -> ViewGraph {
    let graph = ViewGraph(rootView: view)
    graph.layout(in: CGSize(width: width, height: height))
    return graph
}

extension ViewGraph {

    /// The frame of the view with the identifier, failing the test if none.
    func frame(_ identifier: String, sourceLocation: SourceLocation = #_sourceLocation) -> CGRect {
        guard let frame = frame(forIdentifier: identifier) else {
            Issue.record("No view with identifier \(identifier)", sourceLocation: sourceLocation)
            return .null
        }
        return frame
    }

    /// The strings of all text in the display list, in drawing order.
    var texts: [String] {
        func collect(_ list: DisplayList) -> [String] {
            list.items.flatMap { item -> [String] in
                switch item.value {
                case let .content(.text(text)): [text.string]
                case .content: []
                case let .effect(_, nested): collect(nested)
                }
            }
        }
        return collect(displayList())
    }
}

extension View {

    func probe(_ identifier: String) -> some View {
        accessibilityIdentifier(identifier)
    }
}

func rect(_ x: CGFloat, _ y: CGFloat, _ width: CGFloat, _ height: CGFloat) -> CGRect {
    CGRect(x: x, y: y, width: width, height: height)
}
