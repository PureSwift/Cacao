//
//  ContainerRelativeFrame.swift
//  Cacao
//
//  Created by Alsey Coleman Miller on 11/13/26.
//

import Foundation
#if canImport(CoreGraphics)
import CoreGraphics
#endif

/// The size of a container that views inside size themselves relative to:
/// a scroll view's viewport, kept by its node.
@MainActor
internal final class ContainerSize {

    var size: CGSize?

    /// For views inside: the size they last read.
    var read: CGSize?

    static func of(_ node: ViewNode) -> ContainerSize {
        if let box = node.dynamicStorage["containerSize"] as? ContainerSize {
            return box
        }
        let box = ContainerSize()
        node.dynamicStorage["containerSize"] = box
        return box
    }
}

extension ViewNode {

    /// The size of the nearest container: a scroll view's viewport, or the
    /// window's safe area.
    var containerSize: CGSize {
        var node = parent
        while let current = node {
            if let size = (current.dynamicStorage["containerSize"] as? ContainerSize)?.size {
                return size
            }
            node = current.parent
        }
        let insets = graph.safeAreaInsets
        return CGSize(
            width: max(0, graph.size.width - insets.leading - insets.trailing),
            height: max(0, graph.size.height - insets.top - insets.bottom)
        )
    }
}

internal struct ContainerRelativeFrameBehavior: NodeBehavior {

    let axes: Axis.Set

    let alignment: Alignment

    let length: (CGFloat, Axis) -> CGFloat

    /// A fixed frame of the lengths relative to the container, recording
    /// what the node read so that it lays out again if that changes.
    func frame(_ node: ViewNode) -> FrameBehavior {
        let container = node.containerSize
        let record = ContainerSize.of(node)
        if record.read != container {
            record.read = container
            node.graph.afterLayout { [weak node] in
                guard let node else { return }
                if ContainerSize.of(node).read != node.containerSize {
                    node.invalidate()
                }
            }
        }
        return FrameBehavior(
            width: axes.contains(.horizontal) ? max(0, length(container.width, .horizontal)) : nil,
            height: axes.contains(.vertical) ? max(0, length(container.height, .vertical)) : nil,
            alignment: alignment
        )
    }

    func sizeThatFits(_ proposal: ProposedViewSize, node: ViewNode) -> CGSize {
        frame(node).sizeThatFits(proposal, node: node)
    }

    func placeChildren(in bounds: CGRect, proposal: ProposedViewSize, node: ViewNode) {
        frame(node).placeChildren(in: bounds, proposal: proposal, node: node)
    }

    func spacing(node: ViewNode) -> ViewSpacing {
        frame(node).spacing(node: node)
    }

    func explicitAlignment(_ key: AlignmentKey, size: CGSize, proposal: ProposedViewSize, node: ViewNode) -> CGFloat? {
        frame(node).explicitAlignment(key, size: size, proposal: proposal, node: node)
    }
}

internal struct _ContainerRelativeFrame: ViewModifier, PrimitiveViewModifier {

    let axes: Axis.Set

    let alignment: Alignment

    let length: (CGFloat, Axis) -> CGFloat

    func resolve(content: any View, in context: ResolveContext) -> Resolution {
        Resolution(
            behavior: ContainerRelativeFrameBehavior(axes: axes, alignment: alignment, length: length),
            children: [ChildView(key: 0, view: content)]
        )
    }

    typealias Body = Never
}

extension View {

    /// Positions this view within an invisible frame with a size relative
    /// to the nearest container: a scroll view, or the window.
    public func containerRelativeFrame(_ axes: Axis.Set, alignment: Alignment = .center) -> some View {
        modifier(_ContainerRelativeFrame(axes: axes, alignment: alignment) { length, _ in length })
    }

    /// Positions this view within an invisible frame with a size relative
    /// to the nearest container: `span` of `count` columns or rows, with
    /// `spacing` between them.
    public func containerRelativeFrame(
        _ axes: Axis.Set,
        count: Int,
        span: Int = 1,
        spacing: CGFloat,
        alignment: Alignment = .center
    ) -> some View {
        modifier(_ContainerRelativeFrame(axes: axes, alignment: alignment) { length, _ in
            let count = CGFloat(max(count, 1)), span = CGFloat(max(span, 1))
            let column = (length - spacing * (count - 1)) / count
            return column * span + spacing * (span - 1)
        })
    }

    /// Positions this view within an invisible frame with a size relative
    /// to the nearest container, as the closure computes it from the
    /// container's length on each axis.
    public func containerRelativeFrame(
        _ axes: Axis.Set,
        alignment: Alignment = .center,
        _ length: @escaping (CGFloat, Axis) -> CGFloat
    ) -> some View {
        modifier(_ContainerRelativeFrame(axes: axes, alignment: alignment, length: length))
    }
}
