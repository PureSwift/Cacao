//
//  DisplayList.swift
//  CacaoRender
//
//  Created by Alsey Coleman Miller on 11/13/26.
//

import Foundation
#if canImport(CoreGraphics)
import CoreGraphics
#endif

/// back to front.
///
/// Each item carries the identity and version of the view node it came
/// from, so a renderer can keep what it drew for an item until its version
/// changes.
public struct DisplayList: Equatable, Sendable {

    public var items: [Item]

    public init(items: [Item] = []) {
        self.items = items
    }

    /// One drawing or effect.
    public struct Item: Equatable, Sendable {

        public var frame: CGRect

        /// The identity of the view node the item comes from.
        public var identity: Int

        /// The version of the view node, which changes when it's resolved again.
        public var version: Int

        public var value: Value

        public init(frame: CGRect, identity: Int, version: Int, value: Value) {
            self.frame = frame
            self.identity = identity
            self.version = version
            self.value = value
        }

        public static func == (lhs: Item, rhs: Item) -> Bool {
            lhs.frame == rhs.frame
                && lhs.identity == rhs.identity
                && lhs.version == rhs.version
                && lhs.value == rhs.value
        }
    }

    public enum Value: Equatable, Sendable {

        /// Content drawn in the item's frame.
        case content(Content)

        /// An effect applied to a nested display list.
        case effect(Effect, DisplayList)
    }

    public enum Content: Equatable, Sendable {

        /// The frame filled with a color.
        case color(ResolvedColor)

        /// Text laid out in the frame.
        case text(ResolvedText)

        /// A shape drawn in the frame.
        case shape(ShapeContent)

        /// An image scaled to the frame.
        case image(ImageContent)

        /// A canvas's drawing in the frame.
        case drawing(DrawingContent)

        /// An external surface's newest frame, stretched to the frame.
        case external(ExternalContent)

        /// What is drawn so far behind the frame, blurred.
        case backdrop(BackdropContent)
    }

    public enum Effect: Equatable, Sendable {

        /// The nested list drawn as a group with the opacity.
        case opacity(Double)

        /// The nested list drawn over its shadow.
        case shadow(ShadowEffect)

        /// The nested list blurred.
        case blur(BlurEffect)

        /// The nested list's colors transformed by a matrix.
        case colorMatrix(ColorMatrix)

        /// The nested list clipped to a viewport and moved by a scroll offset.
        case scroll(ScrollEffect)

        /// The nested list clipped to a shape in the item's frame.
        case clip(ClipEffect)

        /// The nested list drawn only as much as a mask's drawing is opaque.
        case mask(DisplayList)

        /// The nested list drawn as one group before effects outside it.
        case compositingGroup

        /// The nested list drawn with an affine transform, in the root's
        /// coordinate space.
        case transform(Transform2D)
    }
}
