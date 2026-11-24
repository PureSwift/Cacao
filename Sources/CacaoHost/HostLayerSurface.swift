//
//  HostLayerSurface.swift
//  CacaoHost
//
//  Created by Alsey Coleman Miller on 11/23/26.
//

#if canImport(CoreGraphics)
import CoreGraphics
#endif
import Foundation

/// A window placed in a layer of the screen instead of among the windows:
/// a panel, dock or desktop anchored to the screen's edges.
///
/// On Wayland compositors with `wlr-layer-shell` (sway, Hyprland, KDE and
/// the like) the window becomes a layer surface. Everywhere else it opens
/// as an ordinary window.
public struct HostLayerSurface: Equatable, Sendable {

    /// The layers, from the bottom of the stack up. Windows are drawn
    /// between the bottom and top layers.
    public enum Layer: Hashable, Sendable {
        case background
        case bottom
        case top
        case overlay
    }

    /// The edges of the screen a surface is anchored to.
    public struct Edges: OptionSet, Hashable, Sendable {

        public let rawValue: UInt32

        public init(rawValue: UInt32) {
            self.rawValue = rawValue
        }

        public static let top = Edges(rawValue: 1 << 0)
        public static let bottom = Edges(rawValue: 1 << 1)
        public static let left = Edges(rawValue: 1 << 2)
        public static let right = Edges(rawValue: 1 << 3)

        public static let all: Edges = [.top, .bottom, .left, .right]
    }

    /// Whether the surface takes keyboard focus.
    public enum KeyboardInteractivity: Hashable, Sendable {
        /// Never.
        case none
        /// Always, while it's on the top or overlay layer.
        case exclusive
        /// When clicked, like a window.
        case onDemand
    }

    public var layer: Layer

    /// The edges the surface is anchored to. Anchored to two opposite
    /// edges, it spans the screen between them; to none, it's centered.
    public var edges: Edges

    /// How much of the anchored edge, in points, to keep windows and other
    /// surfaces out of: 0 for none, or -1 to cover what others keep.
    public var exclusiveZone: CGFloat

    /// Distances from the anchored edges, in points.
    public var margins: HostInsets

    public var keyboardInteractivity: KeyboardInteractivity

    /// What the surface is for, such as `dock`, for the compositor's rules.
    public var namespace: String

    public init(
        layer: Layer,
        edges: Edges,
        exclusiveZone: CGFloat = 0,
        margins: HostInsets = HostInsets(),
        keyboardInteractivity: KeyboardInteractivity = .onDemand,
        namespace: String = ""
    ) {
        self.layer = layer
        self.edges = edges
        self.exclusiveZone = exclusiveZone
        self.margins = margins
        self.keyboardInteractivity = keyboardInteractivity
        self.namespace = namespace
    }

    /// The size to ask the compositor for: 0 along an axis anchored at both
    /// ends, which asks for all of it, and the window's size otherwise.
    public func requestedSize(for size: CGSize) -> CGSize {
        CGSize(
            width: edges.isSuperset(of: [.left, .right]) ? 0 : size.width,
            height: edges.isSuperset(of: [.top, .bottom]) ? 0 : size.height
        )
    }
}
