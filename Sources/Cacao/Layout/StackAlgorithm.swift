//
//  StackAlgorithm.swift
//  Cacao
//
//  Created by Alsey Coleman Miller on 11/13/26.
//

import Foundation
#if canImport(CoreGraphics)
import CoreGraphics
#endif

/// SwiftUI's stack layout.
///
/// With a concrete proposal along the major axis, children are sized in
/// decreasing layout priority and, within a priority, from least to most
/// flexible, each offered an even share of the space left. Lower priority
/// children have their minimum lengths reserved first. Spacers are sized
/// after every other child. Children are aligned
/// along the minor axis by the stack's alignment guide.
@MainActor
internal struct StackAlgorithm {

    let axis: Axis

    /// The alignment guide children share along the minor axis.
    let alignment: AlignmentKey

    /// The uniform spacing between children, or `nil` for their preferences.
    let uniformSpacing: CGFloat?

    let children: [LayoutProxy]

    /// A child's size and position in the stack's own coordinate space.
    struct Placement {
        var origin: CGPoint
        var dimensions: ViewDimensions
        var proposal: ProposedViewSize
    }

    private var minorAxis: Axis {
        axis.other
    }

    /// The distance between each child and the previous one.
    private func distances() -> [CGFloat] {
        children.indices.map { index in
            guard index > 0 else { return 0 }
            if let uniformSpacing {
                return uniformSpacing
            }
            return children[index - 1].spacing.distance(to: children[index].spacing, along: axis)
        }
    }

    /// Sizes and positions every child for a proposal.
    func arrange(_ proposal: ProposedViewSize) -> (placements: [Placement], size: CGSize) {
        guard !children.isEmpty else {
            return ([], .zero)
        }
        let distances = distances()
        let internalSpacing = distances.reduce(0, +)
        let minorProposal = proposal[minorAxis]
        var dimensions = [ViewDimensions?](repeating: nil, count: children.count)
        var proposals = [ProposedViewSize](repeating: .unspecified, count: children.count)

        if let majorProposal = proposal[axis] {
            let order = fittingOrder(minorProposal: minorProposal)
            let groups = priorityGroups(order)
            func minLength(_ index: Int) -> CGFloat {
                children[index].size(in: ProposedViewSize(0, in: axis, by: minorProposal))[axis]
            }
            var available = majorProposal - internalSpacing
            // Reserve the minimum lengths of children with lower priority.
            for group in groups.dropFirst() {
                for index in group {
                    available -= minLength(index)
                }
            }
            for (groupIndex, group) in groups.enumerated() {
                if groupIndex > 0 {
                    // This group's reservation is now its to use.
                    for index in group {
                        available += minLength(index)
                    }
                }
                var remaining = group.count
                for index in group {
                    let share = Swift.max(available / CGFloat(remaining), 0)
                    let childProposal = ProposedViewSize(share, in: axis, by: minorProposal)
                    let childDimensions = children[index].dimensions(in: childProposal)
                    dimensions[index] = childDimensions
                    proposals[index] = childProposal
                    let taken = childDimensions.size[axis]
                    if !(available - taken).isNaN {
                        available -= taken
                    }
                    remaining -= 1
                }
            }
        } else {
            for index in children.indices {
                let childProposal = ProposedViewSize(nil, in: axis, by: minorProposal)
                dimensions[index] = children[index].dimensions(in: childProposal)
                proposals[index] = childProposal
            }
        }

        // Align along the minor axis, then normalize so the stack starts at 0.
        var minorLower = CGFloat.infinity
        var minorUpper = -CGFloat.infinity
        var minorOrigins: [CGFloat] = []
        for index in children.indices {
            let childDimensions = dimensions[index]!
            let origin = -childDimensions[alignment]
            minorOrigins.append(origin)
            minorLower = Swift.min(minorLower, origin)
            minorUpper = Swift.max(minorUpper, origin + childDimensions.size[minorAxis])
        }
        var placements: [Placement] = []
        var major: CGFloat = 0
        for index in children.indices {
            let childDimensions = dimensions[index]!
            let majorOrigin = major + distances[index]
            placements.append(Placement(
                origin: CGPoint(majorOrigin, in: axis, by: minorOrigins[index] - minorLower),
                dimensions: childDimensions,
                proposal: proposals[index]
            ))
            major = majorOrigin + childDimensions.size[axis]
        }
        return (placements, CGSize(major, in: axis, by: minorUpper - minorLower))
    }

    /// Children in the order they're sized: decreasing priority, then
    /// increasing flexibility.
    private func fittingOrder(minorProposal: CGFloat?) -> [Int] {
        struct Range {
            let min: CGFloat
            let max: CGFloat
        }
        var ranges: [Int: Range] = [:]
        func range(_ index: Int) -> Range {
            if let range = ranges[index] {
                return range
            }
            let child = children[index]
            let range = Range(
                min: child.size(in: ProposedViewSize(0, in: axis, by: minorProposal))[axis],
                max: child.size(in: ProposedViewSize(.infinity, in: axis, by: minorProposal))[axis]
            )
            ranges[index] = range
            return range
        }
        func isLessFlexible(_ lhs: Range, _ rhs: Range) -> Bool {
            let lhsDiff = lhs.max - lhs.min
            let rhsDiff = rhs.max - rhs.min
            if lhsDiff == rhsDiff {
                let lhsMin = lhsDiff == .infinity ? -lhs.min : 0
                let rhsMin = rhsDiff == .infinity ? -rhs.min : 0
                return lhsMin < rhsMin
            }
            return lhsDiff < rhsDiff
        }
        // A stable insertion sort, so equally flexible children keep their order.
        var order = Array(children.indices)
        for i in 1..<Swift.max(order.count, 1) {
            var j = i
            while j > 0 {
                let a = order[j - 1]
                let b = order[j]
                let pa = children[a].stackPriority
                let pb = children[b].stackPriority
                let shouldSwap: Bool
                if pa != pb {
                    shouldSwap = pb > pa
                } else {
                    shouldSwap = isLessFlexible(range(b), range(a))
                }
                guard shouldSwap else { break }
                order.swapAt(j - 1, j)
                j -= 1
            }
        }
        return order
    }

    /// Splits the fitting order into runs of equal priority.
    private func priorityGroups(_ order: [Int]) -> [[Int]] {
        var groups: [[Int]] = []
        for index in order {
            if let last = groups.last?.last, children[last].stackPriority == children[index].stackPriority {
                groups[groups.count - 1].append(index)
            } else {
                groups.append([index])
            }
        }
        return groups
    }

    func size(in proposal: ProposedViewSize) -> CGSize {
        arrange(proposal).size
    }

    /// The proposal children are arranged with when placing: the major axis
    /// keeps the stack's proposal, the minor axis uses the stack's size.
    private func placingProposal(size: CGSize, proposal: ProposedViewSize) -> ProposedViewSize {
        ProposedViewSize(proposal[axis], in: axis, by: proposal[minorAxis] ?? size[minorAxis])
    }

    func place(in bounds: CGRect, proposal: ProposedViewSize) {
        let (placements, _) = arrange(placingProposal(size: bounds.size, proposal: proposal))
        for (child, placement) in zip(children, placements) {
            child.place(
                at: CGPoint(x: bounds.minX + placement.origin.x, y: bounds.minY + placement.origin.y),
                proposal: placement.proposal
            )
        }
    }

    func explicitAlignment(_ key: AlignmentKey, size: CGSize, proposal: ProposedViewSize) -> CGFloat? {
        let (placements, _) = arrange(placingProposal(size: size, proposal: proposal))
        return key.combineExplicit(placements.map { placement in
            placement.dimensions[explicit: key].map { $0 + placement.origin[key.axis] }
        })
    }

    /// The first child's spacing at the leading edge, the last's at the
    /// trailing edge, and all children's merged along the minor axis.
    func spacing() -> ViewSpacing {
        guard let first = children.first, let last = children.last else {
            return .zero
        }
        let firstSpacing = first.spacing
        let lastSpacing = last.spacing
        var minor = firstSpacing
        for child in children.dropFirst() {
            minor.formUnion(child.spacing, edges: axis == .horizontal ? .vertical : .horizontal)
        }
        var edges: [Edge: CGFloat] = [:]
        let (leadingEdge, trailingEdge): (Edge, Edge) = axis == .horizontal ? (.leading, .trailing) : (.top, .bottom)
        let minorEdges: [Edge] = axis == .horizontal ? [.top, .bottom] : [.leading, .trailing]
        edges[leadingEdge] = firstSpacing.edges[leadingEdge]
        edges[trailingEdge] = lastSpacing.edges[trailingEdge]
        for edge in minorEdges {
            edges[edge] = minor.edges[edge]
        }
        return ViewSpacing(edges: edges)
    }
}
