//
//  DrawingContent.swift
//  CacaoRender
//
//  Created by Alsey Coleman Miller on 11/13/26.
//

import Foundation
#if canImport(CoreGraphics)
import CoreGraphics
#endif

/// Drawing commands recorded by a canvas, rasterized like a shape.
public struct DrawingContent: Equatable, Sendable {

    public var operations: [Operation]

    public init(operations: [Operation]) {
        self.operations = operations
    }

    public enum Operation: Equatable, Sendable {
        /// A filled or stroked path.
        case shape(ShapeContent, DrawingState)
        /// Text laid out in a rectangle.
        case text(ResolvedText, CGRect, DrawingState)
        /// An image scaled to a rectangle.
        case image(ImageContent, CGRect, DrawingState)
        /// A path filled with an image repeated from an origin, at a scale.
        case tiledImage(Path, isEOFilled: Bool, ImageContent, origin: CGPoint, scale: CGFloat, DrawingState)
        /// A view's drawing (a canvas symbol), its frames from its origin.
        case items([DisplayList.Item], DrawingState)
        /// Operations drawn together, then composited with the state's
        /// opacity, blend mode, filters and masks.
        case layer(DrawingContent, DrawingState)

        public var state: DrawingState {
            switch self {
            case let .shape(_, state), let .text(_, _, state), let .image(_, _, state),
                 let .tiledImage(_, _, _, _, _, state), let .items(_, state), let .layer(_, state):
                state
            }
        }
    }
}

/// A clip of drawing commands: a path, in the coordinates of a transform.
public struct DrawingClip: Equatable, Sendable {

    public var path: Path

    public var transform: Transform2D

    public var isEOFilled: Bool

    /// Whether drawing shows outside the path instead.
    public var isInverse = false

    public init(path: Path, transform: Transform2D, isEOFilled: Bool, isInverse: Bool = false) {
        self.path = path
        self.transform = transform
        self.isEOFilled = isEOFilled
        self.isInverse = isInverse
    }
}

/// A filter applied to drawing as it's composited.
public enum DrawingFilter: Equatable, Sendable {
    /// A shadow: the drawing's silhouette in a color, blurred and moved,
    /// below the drawing, above it or alone.
    case shadow(color: ResolvedColor, radius: CGFloat, offset: CGSize, blendMode: BlendMode, placement: ShadowPlacement, invertsAlpha: Bool)
    /// A Gaussian blur.
    case blur(radius: CGFloat, isOpaque: Bool)
    /// A transformation of colors.
    case colorMatrix(ColorMatrix)
    /// Opaque in a color where alpha is in a range, transparent elsewhere.
    case alphaThreshold(min: Double, max: Double, color: ResolvedColor)

    public enum ShadowPlacement: Equatable, Sendable {
        case below, above, only
    }
}

/// A layer whose alpha masks drawing commands.
public struct DrawingMask: Equatable, Sendable {

    public var content: DrawingContent

    public var opacity: Double

    public var isInverse: Bool

    public init(content: DrawingContent, opacity: Double, isInverse: Bool) {
        self.content = content
        self.opacity = opacity
        self.isInverse = isInverse
    }
}

/// The transform, opacity, clips, blend mode, filters and masks a drawing
/// command is drawn with.
public struct DrawingState: Equatable, Sendable {

    public var transform = Transform2D.identity

    public var opacity = 1.0

    /// Paths the drawing is clipped to.
    public var clips: [DrawingClip] = []

    public var blendMode = BlendMode.normal

    public var filters: [DrawingFilter] = []

    public var masks: [DrawingMask] = []

    public init() { }

    /// Whether the command composites on its own, from its own bitmap.
    public var isComposited: Bool {
        blendMode != .normal || !filters.isEmpty || !masks.isEmpty
    }
}

/// Modes for compositing a view with overlapping content.
public enum BlendMode: Hashable, Sendable {
    case normal, multiply, screen, overlay, darken, lighten, colorDodge, colorBurn, softLight, hardLight
    case difference, exclusion, hue, saturation, color, luminosity, sourceAtop, destinationOver
    case destinationOut, plusDarker, plusLighter
}
