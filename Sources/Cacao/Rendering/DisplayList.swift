//
//  DisplayList.swift
//  Cacao
//
//  Created by Alsey Coleman Miller on 11/13/26.
//

import CacaoRender
import Foundation
#if canImport(CoreGraphics)
import CoreGraphics
#endif

/// What to draw: a tree of items with frames in the root's coordinate space,
// MARK: - Building

extension ViewGraph {

    /// The display list for the last layout.
    package func displayList() -> DisplayList {
        needsDisplay = false
        return DisplayList(items: root.displayItems() + dragPreviewItems())
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
        var ordered = orderedChildren
        // Popups in surfaces of their own aren't drawn in the window.
        let isRoot = self === graph.root
        if isRoot, graph.presentations.contains(where: \.isDetached) {
            let detached = graph.detachedNodeIDs
            ordered.removeAll { detached.contains($0.id) }
        }
        var childItems: [[DisplayList.Item]] = ordered.map { $0.displayItems() }
        // Removed children still transitioning out, where they were.
        if let ghosts = graph.ghosts[id] {
            for ghost in ghosts.sorted(by: { $0.index > $1.index }) where !(isRoot && ViewGraph.isDetached(ghost.frame)) {
                let progress = ghost.animation.values(at: graph.time).values[0]
                let effect = ghost.transition.effect(progress: progress, frame: ghost.frame, container: graph.size, isInsertion: false)
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
                let effect = transition.transition.effect(progress: progress, frame: subtreeFrame, container: graph.size, isInsertion: true)
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
