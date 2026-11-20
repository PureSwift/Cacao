//
//  ViewSpacing.swift
//  Cacao
//
//  Created by Alsey Coleman Miller on 11/13/26.
//

import CacaoRender
import Foundation
#if canImport(CoreGraphics)
import CoreGraphics
#endif

/// The distance used between two adjacent views when neither states a
/// preference.
internal let defaultSpacing: CGFloat = 8

/// A collection of the geometric spacing preferences of a view.
///
/// Each edge either states a minimum distance or leaves it to the system
/// default. Between two views, the distance is the sum of the touching edges'
/// stated values, the one stated value, or the default when neither states one.
public struct ViewSpacing: Equatable, Sendable {

    internal var edges: [Edge: CGFloat]

    internal init(edges: [Edge: CGFloat]) {
        self.edges = edges
    }

    /// Initializes an instance with default spacing values on every edge.
    public init() {
        self.init(edges: [:])
    }

    /// A view spacing instance that contains zero on all edges.
    public static let zero = ViewSpacing(edges: [.top: 0, .leading: 0, .bottom: 0, .trailing: 0])

    /// Merges the spacing preferences of another view into this one, for
    /// the given edges, keeping the larger minimum where both state one.
    public mutating func formUnion(_ other: ViewSpacing, edges: Edge.Set = .all) {
        for edge in Edge.allCases where edges.contains(Edge.Set(edge)) {
            if let a = self.edges[edge], let b = other.edges[edge] {
                self.edges[edge] = Swift.max(a, b)
            } else {
                self.edges[edge] = nil
            }
        }
    }

    /// Gets a new value that merges the spacing preferences of another view.
    public func union(_ other: ViewSpacing, edges: Edge.Set = .all) -> ViewSpacing {
        var result = self
        result.formUnion(other, edges: edges)
        return result
    }

    /// Gets the preferred spacing distance along the specified axis to the
    /// view that returns a specified spacing preference.
    public func distance(to next: ViewSpacing, along axis: Axis) -> CGFloat {
        let trailing = axis == .horizontal ? edges[.trailing] : edges[.bottom]
        let leading = axis == .horizontal ? next.edges[.leading] : next.edges[.top]
        switch (trailing, leading) {
        case let (a?, b?): return a + b
        case let (a?, nil): return a
        case let (nil, b?): return b
        case (nil, nil): return defaultSpacing
        }
    }

    /// Returns these preferences with the given edges reset to the default.
    internal func resetting(_ edges: Edge.Set) -> ViewSpacing {
        var result = self
        for edge in Edge.allCases where edges.contains(Edge.Set(edge)) {
            result.edges[edge] = nil
        }
        return result
    }

    /// Spacing that only states zero along one axis, like a spacer's.
    internal static func zero(along axis: Axis) -> ViewSpacing {
        axis == .horizontal
            ? ViewSpacing(edges: [.leading: 0, .trailing: 0])
            : ViewSpacing(edges: [.top: 0, .bottom: 0])
    }
}
