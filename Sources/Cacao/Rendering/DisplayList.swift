//
//  DisplayList.swift
//  Cacao
//
//  Created by Alsey Coleman Miller on 11/13/26.
//

import Foundation
#if canImport(CoreGraphics)
import CoreGraphics
#endif

/// What to draw: a tree of items with frames in the root's coordinate space,
/// back to front.
///
/// Each item carries the identity and version of the view node it came
/// from, so a renderer can keep what it drew for an item until its version
/// changes.
package struct DisplayList: Equatable, Sendable {

    package var items: [Item]

    package init(items: [Item] = []) {
        self.items = items
    }

    /// One drawing or effect.
    package struct Item: Equatable, Sendable {

        package var frame: CGRect

        /// The identity of the view node the item comes from.
        package var identity: Int

        /// The version of the view node, which changes when it's resolved again.
        package var version: Int

        package var value: Value

        package static func == (lhs: Item, rhs: Item) -> Bool {
            lhs.frame == rhs.frame
                && lhs.identity == rhs.identity
                && lhs.version == rhs.version
                && lhs.value == rhs.value
        }
    }

    package enum Value: Equatable, Sendable {

        /// Content drawn in the item's frame.
        case content(Content)

        /// An effect applied to a nested display list.
        case effect(Effect, DisplayList)
    }

    package enum Content: Equatable, Sendable {

        /// The frame filled with a color.
        case color(Color.Resolved)

        /// Text laid out in the frame.
        case text(ResolvedText)

        /// A shape drawn in the frame.
        case shape(ShapeContent)

        /// An image scaled to the frame.
        case image(ImageContent)

        /// A canvas's drawing in the frame.
        case drawing(DrawingContent)
    }

    package enum Effect: Equatable, Sendable {

        /// The nested list drawn as a group with the opacity.
        case opacity(Double)

        /// The nested list clipped to a viewport and moved by a scroll offset.
        case scroll(ScrollEffect)

        /// The nested list clipped to a shape in the item's frame.
        case clip(ClipEffect)

        /// The nested list drawn as one group before effects outside it.
        case compositingGroup

        /// The nested list drawn with an affine transform, in the root's
        /// coordinate space.
        case transform(Transform2D)
    }
}

// MARK: - Building

extension ViewGraph {

    /// The display list for the last layout.
    package func displayList() -> DisplayList {
        needsDisplay = false
        return DisplayList(items: root.displayItems())
    }
}

extension ViewNode {

    /// The node's drawing, as it shows at the graph's current time: with
    /// animated frames and values, transitions in and views transitioning out.
    func displayItems() -> [DisplayList.Item] {
        let graph = self.graph
        let behavior = graph.presentationBehavior(of: self)
        let frame = graph.presentationFrame(of: self)
        var items: [DisplayList.Item] = []
        if let content = behavior?.displayContent(node: self) {
            items.append(DisplayList.Item(frame: frame, identity: id, version: version, value: .content(content)))
        }
        let ordered = behavior?.displayOrder(of: children) ?? children
        var childItems: [[DisplayList.Item]] = ordered.map { $0.displayItems() }
        // Removed children still transitioning out, where they were.
        if let ghosts = graph.ghosts[id] {
            for ghost in ghosts.sorted(by: { $0.index > $1.index }) {
                let progress = ghost.animation.values(at: graph.time).values[0]
                let effect = ghost.transition.effect(progress: progress, frame: ghost.frame, isInsertion: false)
                let wrapped = Self.wrap(ghost.items, opacity: effect.opacity, transform: effect.transform, identity: ghost.identity, frame: ghost.frame)
                childItems.insert(wrapped, at: min(ghost.index, childItems.count))
            }
        }
        let flattened = childItems.flatMap { $0 }
        if let effect = behavior?.displayEffect(node: self) {
            items.append(DisplayList.Item(
                frame: frame,
                identity: id,
                version: version,
                value: .effect(effect, DisplayList(items: flattened))
            ))
        } else {
            items.append(contentsOf: flattened)
        }
        // An insertion transition or a matched geometry move of this node.
        if let state = graph.nodeAnimations[id] {
            if let geometry = state.geometry {
                let progress = CGFloat(geometry.animation.values(at: graph.time).values[0])
                let target = subtreeFrame
                if target.width > 0, target.height > 0 {
                    let source = geometry.from
                    let scaleX = (source.width + (target.width - source.width) * progress) / target.width
                    let scaleY = (source.height + (target.height - source.height) * progress) / target.height
                    let originX = source.minX + (target.minX - source.minX) * progress
                    let originY = source.minY + (target.minY - source.minY) * progress
                    let transform = Transform2D.translation(-target.minX, -target.minY)
                        .concatenating(.scale(scaleX, scaleY))
                        .concatenating(.translation(originX, originY))
                    items = Self.wrap(items, opacity: 1, transform: transform, identity: id, frame: target)
                }
            } else if let transition = state.transition {
                let progress = transition.animation.values(at: graph.time).values[0]
                let effect = transition.transition.effect(progress: progress, frame: subtreeFrame, isInsertion: true)
                items = Self.wrap(items, opacity: effect.opacity, transform: effect.transform, identity: id, frame: subtreeFrame)
            }
        }
        return items
    }

    /// Items wrapped in an opacity and a transform, when they aren't identity.
    static func wrap(_ items: [DisplayList.Item], opacity: Double, transform: Transform2D, identity: Int, frame: CGRect) -> [DisplayList.Item] {
        var items = items
        if opacity < 1 {
            items = [DisplayList.Item(frame: frame, identity: identity, version: 0, value: .effect(.opacity(max(opacity, 0)), DisplayList(items: items)))]
        }
        if transform != .identity {
            items = [DisplayList.Item(frame: frame, identity: identity, version: 0, value: .effect(.transform(transform), DisplayList(items: items)))]
        }
        return items
    }
}
