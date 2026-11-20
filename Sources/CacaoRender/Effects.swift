//
//  Effects.swift
//  CacaoRender
//
//  Created by Alsey Coleman Miller on 11/13/26.
//

import Foundation
#if canImport(CoreGraphics)
import CoreGraphics
#endif

/// A Gaussian blur of a view's drawing.
public struct BlurEffect: Equatable, Sendable {

    /// The blur's radius, in points.
    public var radius: CGFloat

    /// Whether the blur keeps to the view's bounds, without transparency
    /// spreading in at its edges.
    public var isOpaque: Bool

    public init(radius: CGFloat, isOpaque: Bool) {
        self.radius = radius
        self.isOpaque = isOpaque
    }
}

/// A shadow drawn behind a view's content.
public struct ShadowEffect: Equatable, Sendable {

    public var color: ResolvedColor

    public var radius: CGFloat

    public var offset: CGSize

    public init(color: ResolvedColor, radius: CGFloat, offset: CGSize) {
        self.color = color
        self.radius = radius
        self.offset = offset
    }
}

/// The effect of a scroll view on its content's drawing.
public struct ScrollEffect: Equatable, Sendable {

    /// The visible area, in the root's coordinate space.
    public var viewport: CGRect

    /// How far the content is scrolled.
    public var offset: CGPoint

    /// Whether to draw scroll indicators.
    public var showsIndicators: Bool

    /// How opaque the indicators are, from 0 to 1: they fade out a while
    /// after scrolling.
    public var indicatorOpacity: Double

    /// The size of the content, for indicators.
    public var contentSize: CGSize

    public init(viewport: CGRect, offset: CGPoint, showsIndicators: Bool, indicatorOpacity: Double = 1, contentSize: CGSize) {
        self.viewport = viewport
        self.offset = offset
        self.showsIndicators = showsIndicators
        self.indicatorOpacity = indicatorOpacity
        self.contentSize = contentSize
    }
}

/// Clipping of a subtree's drawing to a shape.
public struct ClipEffect: Equatable, Sendable {

    /// The clip, in the frame's coordinate space.
    public var path: Path

    /// Whether the clip is the whole frame, which a renderer can apply
    /// without an offscreen layer.
    public var isRectangle: Bool

    /// Whether the path fills by the even-odd rule.
    public var isEOFilled = false

    public init(path: Path, isRectangle: Bool, isEOFilled: Bool = false) {
        self.path = path
        self.isRectangle = isRectangle
        self.isEOFilled = isEOFilled
    }

    /// The clip as a mask: the path filled in white.
    public var mask: DisplayList.Content {
        .shape(ShapeContent(
            path: path,
            color: ResolvedColor(red: 1, green: 1, blue: 1),
            drawing: .fill(FillStyle(eoFill: isEOFilled))
        ))
    }
}
