//
//  Stacks.swift
//  Cacao
//
//  Created by Alsey Coleman Miller on 11/13/26.
//

import CacaoRender
import Foundation
#if canImport(CoreGraphics)
import CoreGraphics
#endif

// MARK: - HStackLayout

/// A horizontal container that you can use in conditional layouts.
public struct HStackLayout: Layout {

    /// The vertical alignment of subviews.
    public var alignment: VerticalAlignment

    /// The distance between adjacent subviews, or `nil` for the default.
    public var spacing: CGFloat?

    public init(alignment: VerticalAlignment = .center, spacing: CGFloat? = nil) {
        self.alignment = alignment
        self.spacing = spacing
    }

    public static var layoutProperties: LayoutProperties {
        var properties = LayoutProperties()
        properties.stackOrientation = .horizontal
        return properties
    }

    private func algorithm(_ subviews: Subviews) -> StackAlgorithm {
        StackAlgorithm(axis: .horizontal, alignment: alignment.key, uniformSpacing: spacing, children: subviews.proxies)
    }

    public func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout Void) -> CGSize {
        algorithm(subviews).size(in: proposal)
    }

    public func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout Void) {
        algorithm(subviews).place(in: bounds, proposal: proposal)
    }

    public func spacing(subviews: Subviews, cache: inout Void) -> ViewSpacing {
        algorithm(subviews).spacing()
    }

    public func explicitAlignment(
        of guide: HorizontalAlignment,
        in bounds: CGRect,
        proposal: ProposedViewSize,
        subviews: Subviews,
        cache: inout Void
    ) -> CGFloat? {
        algorithm(subviews).explicitAlignment(guide.key, size: bounds.size, proposal: proposal)
    }

    public func explicitAlignment(
        of guide: VerticalAlignment,
        in bounds: CGRect,
        proposal: ProposedViewSize,
        subviews: Subviews,
        cache: inout Void
    ) -> CGFloat? {
        algorithm(subviews).explicitAlignment(guide.key, size: bounds.size, proposal: proposal)
    }
}

// MARK: - VStackLayout

/// A vertical container that you can use in conditional layouts.
public struct VStackLayout: Layout {

    /// The horizontal alignment of subviews.
    public var alignment: HorizontalAlignment

    /// The distance between adjacent subviews, or `nil` for the default.
    public var spacing: CGFloat?

    public init(alignment: HorizontalAlignment = .center, spacing: CGFloat? = nil) {
        self.alignment = alignment
        self.spacing = spacing
    }

    public static var layoutProperties: LayoutProperties {
        var properties = LayoutProperties()
        properties.stackOrientation = .vertical
        return properties
    }

    private func algorithm(_ subviews: Subviews) -> StackAlgorithm {
        StackAlgorithm(axis: .vertical, alignment: alignment.key, uniformSpacing: spacing, children: subviews.proxies)
    }

    public func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout Void) -> CGSize {
        algorithm(subviews).size(in: proposal)
    }

    public func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout Void) {
        algorithm(subviews).place(in: bounds, proposal: proposal)
    }

    public func spacing(subviews: Subviews, cache: inout Void) -> ViewSpacing {
        algorithm(subviews).spacing()
    }

    public func explicitAlignment(
        of guide: HorizontalAlignment,
        in bounds: CGRect,
        proposal: ProposedViewSize,
        subviews: Subviews,
        cache: inout Void
    ) -> CGFloat? {
        algorithm(subviews).explicitAlignment(guide.key, size: bounds.size, proposal: proposal)
    }

    public func explicitAlignment(
        of guide: VerticalAlignment,
        in bounds: CGRect,
        proposal: ProposedViewSize,
        subviews: Subviews,
        cache: inout Void
    ) -> CGFloat? {
        algorithm(subviews).explicitAlignment(guide.key, size: bounds.size, proposal: proposal)
    }
}

// MARK: - ZStackLayout

/// An overlaying container that you can use in conditional layouts.
public struct ZStackLayout: Layout {

    /// The alignment of subviews.
    public var alignment: Alignment

    public init(alignment: Alignment = .center) {
        self.alignment = alignment
    }

    /// The size of the subviews with the highest layout priority.
    public func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout Void) -> CGSize {
        guard let maxPriority = subviews.map(\.priority).max() else {
            return .zero
        }
        return subviews
            .filter { $0.priority == maxPriority }
            .map { $0.sizeThatFits(proposal) }
            .reduce(CGSize.zero) { CGSize(width: max($0.width, $1.width), height: max($0.height, $1.height)) }
    }

    public func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout Void) {
        let childProposal = ProposedViewSize(bounds.size)
        let maxPriority = subviews.map(\.priority).max() ?? 0
        var guide = CGPoint(x: -CGFloat.infinity, y: -CGFloat.infinity)
        for subview in subviews where subview.priority == maxPriority {
            let dimensions = subview.dimensions(in: childProposal)
            guide.x = max(guide.x, dimensions[alignment.horizontal])
            guide.y = max(guide.y, dimensions[alignment.vertical])
        }
        for subview in subviews {
            let dimensions = subview.dimensions(in: childProposal)
            subview.place(
                at: CGPoint(
                    x: bounds.minX + guide.x - dimensions[alignment.horizontal],
                    y: bounds.minY + guide.y - dimensions[alignment.vertical]
                ),
                proposal: childProposal
            )
        }
    }

    public func explicitAlignment(
        of guide: HorizontalAlignment,
        in bounds: CGRect,
        proposal: ProposedViewSize,
        subviews: Subviews,
        cache: inout Void
    ) -> CGFloat? {
        let childProposal = ProposedViewSize(bounds.size)
        let anchor = subviews.map { $0.dimensions(in: childProposal)[alignment.horizontal] }.max() ?? 0
        return guide.combineExplicit(subviews.map { subview in
            let dimensions = subview.dimensions(in: childProposal)
            return dimensions[explicit: guide].map { $0 + anchor - dimensions[alignment.horizontal] }
        })
    }

    public func explicitAlignment(
        of guide: VerticalAlignment,
        in bounds: CGRect,
        proposal: ProposedViewSize,
        subviews: Subviews,
        cache: inout Void
    ) -> CGFloat? {
        let childProposal = ProposedViewSize(bounds.size)
        let anchor = subviews.map { $0.dimensions(in: childProposal)[alignment.vertical] }.max() ?? 0
        return guide.combineExplicit(subviews.map { subview in
            let dimensions = subview.dimensions(in: childProposal)
            return dimensions[explicit: guide].map { $0 + anchor - dimensions[alignment.vertical] }
        })
    }
}

// MARK: - Views

/// A view that arranges its subviews in a horizontal line.
public struct HStack<Content: View>: View {

    internal let layout: HStackLayout

    internal let content: Content

    /// Creates a horizontal stack with the given spacing and vertical alignment.
    public init(
        alignment: VerticalAlignment = .center,
        spacing: CGFloat? = nil,
        @ViewBuilder content: () -> Content
    ) {
        self.layout = HStackLayout(alignment: alignment, spacing: spacing)
        self.content = content()
    }

    public var body: some View {
        layout { content }
    }
}

/// A view that arranges its subviews in a vertical line.
public struct VStack<Content: View>: View {

    internal let layout: VStackLayout

    internal let content: Content

    /// Creates an instance with the given spacing and horizontal alignment.
    public init(
        alignment: HorizontalAlignment = .center,
        spacing: CGFloat? = nil,
        @ViewBuilder content: () -> Content
    ) {
        self.layout = VStackLayout(alignment: alignment, spacing: spacing)
        self.content = content()
    }

    public var body: some View {
        layout { content }
    }
}

/// A view that overlays its subviews, aligning them in both axes.
public struct ZStack<Content: View>: View {

    internal let layout: ZStackLayout

    internal let content: Content

    /// Creates an instance with the given alignment.
    public init(
        alignment: Alignment = .center,
        @ViewBuilder content: () -> Content
    ) {
        self.layout = ZStackLayout(alignment: alignment)
        self.content = content()
    }

    public var body: some View {
        layout { content }
    }
}
