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
    }

    package enum Effect: Equatable, Sendable {

        /// The nested list drawn as a group with the opacity.
        case opacity(Double)
    }
}

// MARK: - Building

extension ViewGraph {

    /// The display list for the last layout.
    package func displayList() -> DisplayList {
        DisplayList(items: root.displayItems())
    }
}

extension ViewNode {

    func displayItems() -> [DisplayList.Item] {
        var items: [DisplayList.Item] = []
        if let content = behavior?.displayContent(node: self) {
            items.append(DisplayList.Item(frame: frame, identity: id, version: version, value: .content(content)))
        }
        let ordered = behavior?.displayOrder(of: children) ?? children
        let childItems = ordered.flatMap { $0.displayItems() }
        if let effect = behavior?.displayEffect(node: self) {
            items.append(DisplayList.Item(
                frame: frame,
                identity: id,
                version: version,
                value: .effect(effect, DisplayList(items: childItems))
            ))
        } else {
            items.append(contentsOf: childItems)
        }
        return items
    }
}
