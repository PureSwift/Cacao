//
//  PopupSurfaces.swift
//  Cacao
//
//  Created by Alsey Coleman Miller on 11/24/26.
//

import CacaoRender
import Foundation
#if canImport(CoreGraphics)
import CoreGraphics
#endif

/// Distances between popups and what they open from.
internal enum PopupMetrics {

    /// Between a button and the menu below it.
    static let gap: CGFloat = 4

    /// How far a submenu sits above the item it opens from, so their
    /// titles line up: the menu's inset and border.
    static let submenuInset: CGFloat = 5
}

/// A popup in a surface of its own, outside the window: what the host
/// opens a surface for, and where it goes.
///
/// The graph keeps the popup's views with the window's, laid out away from
/// the window's content (at `origin`), so state, environment and
/// presentations work as they do in the window. The host draws the popup's
/// display list in the surface, and sends the surface's input to the graph
/// at `origin` plus where it is in the popup.
package struct DetachedPopup: Equatable, Sendable {

    /// The presentation's identifier.
    package let id: Int

    /// The detached popup it opened from, like a submenu's menu; `nil` when
    /// it opened from the window.
    package let parentID: Int?

    /// What it opens next to, in its parent's coordinates: the window's,
    /// or the parent popup's, from its top left corner.
    package let anchor: CGRect

    package let edge: PopupEdge

    /// Moves it from where the edge puts it, as for a gap below a button.
    package let offset: CGSize

    /// Its size, in points.
    package let size: CGSize

    /// Where it is in the graph.
    package let origin: CGPoint
}

extension ViewGraph {

    /// Where a detached popup's views go: far from the window's content,
    /// and from each other, so a point in one hits nothing else.
    static func detachedOrigin(of id: Int) -> CGPoint {
        CGPoint(x: 100_000 * CGFloat(id), y: 100_000)
    }

    /// Whether a frame is where detached popups go, outside the window.
    static func isDetached(_ frame: CGRect) -> Bool {
        frame.minX >= 50_000
    }

    /// The node showing a presentation.
    func presentationNode(_ id: Int) -> ViewNode? {
        root.children.first { $0.key == AnyHashable("presentation \(id)") }
    }

    /// The first popup of a chain of detached popups, like a menu of its
    /// submenus.
    func rootPopupID(of id: Int) -> Int {
        var current = id
        while let parent = presentations.first(where: { $0.id == current })?.parentID {
            current = parent
        }
        return current
    }

    /// The first menu of a chain of menus, like a menu of its submenus.
    func rootMenuID(of id: Int) -> Int {
        var current = id
        while let presentation = presentations.first(where: { $0.id == current }), presentation.isMenu,
              let parent = presentation.parentID,
              presentations.contains(where: { $0.id == parent && $0.isMenu }) {
            current = parent
        }
        return current
    }

    /// The nodes of detached popups, which the window doesn't draw.
    var detachedNodeIDs: Set<Int> {
        Set(presentations.filter(\.isDetached).compactMap { presentationNode($0.id)?.id })
    }

    /// The popups showing in surfaces of their own, after the last layout,
    /// each after the one it opened from.
    package var detachedPopups: [DetachedPopup] {
        presentations.compactMap { presentation -> DetachedPopup? in
            guard presentation.isDetached, case let .popup(anchor, edge) = presentation.style,
                  let node = presentationNode(presentation.id) else {
                return nil
            }
            let frame = node.subtreeFrame
            guard !frame.isNull else { return nil }
            var parentAnchor = anchor
            let parentID = presentation.parentID.flatMap { id in
                presentations.contains { $0.id == id && $0.isDetached } ? id : nil
            }
            if let parentID {
                let parentOrigin = Self.detachedOrigin(of: parentID)
                parentAnchor = anchor.offsetBy(dx: -parentOrigin.x, dy: -parentOrigin.y)
            }
            let offset: CGSize
            switch edge {
            case .bottom: offset = CGSize(width: 0, height: PopupMetrics.gap)
            case .trailing: offset = CGSize(width: 0, height: -PopupMetrics.submenuInset)
            }
            return DetachedPopup(
                id: presentation.id,
                parentID: parentID,
                anchor: parentAnchor,
                edge: edge,
                offset: offset,
                size: frame.size,
                origin: Self.detachedOrigin(of: presentation.id)
            )
        }
    }

    /// A detached popup's drawing, with its top left corner at `origin`.
    package func popupDisplayList(_ id: Int, at origin: CGPoint = .zero) -> DisplayList {
        guard let node = presentationNode(id) else { return DisplayList(items: []) }
        let detached = Self.detachedOrigin(of: id)
        let items = node.displayItems()
        let transform = Transform2D.translation(origin.x - detached.x, origin.y - detached.y)
        return DisplayList(items: ViewNode.wrap(items, opacity: 1, transform: transform, identity: node.id, frame: node.subtreeFrame))
    }

    /// The point in the graph at a point in a detached popup.
    package func point(_ point: CGPoint, inPopup id: Int) -> CGPoint {
        let origin = Self.detachedOrigin(of: id)
        return CGPoint(x: point.x + origin.x, y: point.y + origin.y)
    }

    /// Lays a detached popup out to the height the system gave its
    /// surface, when it made it shorter to fit the screen.
    package func setPopupHeight(_ height: CGFloat?, for id: Int) {
        guard let index = presentations.firstIndex(where: { $0.id == id }),
              presentations[index].maximumHeight != height else {
            return
        }
        presentations[index].maximumHeight = height
        root.invalidate()
    }

    /// Draws a popup in the window after all, as when the host couldn't
    /// open a surface for it; its own popups go with it.
    package func attachPopup(_ id: Int) {
        guard let index = presentations.firstIndex(where: { $0.id == id }), presentations[index].isDetached else { return }
        for later in index..<presentations.count where presentations[later].isDetached {
            presentations[later].isDetached = false
        }
        // Their views move into the window.
        root.invalidate()
    }
}

// MARK: - Menus

extension ViewGraph {

    /// Shows new content in a presentation, as a menu whose items changed
    /// while it's open.
    func updatePresentation(_ id: Int, content: AnyView) {
        guard let presentation = presentations.first(where: { $0.id == id }) else { return }
        present(owner: presentation.owner, style: presentation.style, content: content, environment: presentation.environment)
    }

    /// The focusable views in a presentation, in order.
    func focusableNodes(inPresentation id: Int) -> [ViewNode] {
        guard let node = presentationNode(id) else { return [] }
        var nodes: [ViewNode] = []
        node.forEachNode { node in
            if node.attributes.focus != nil {
                nodes.append(node)
            }
        }
        return nodes
    }

    /// Focuses a presentation's first focusable view, like a menu's first
    /// item, once it's laid out.
    func focusFirstItem(inPresentation id: Int) {
        afterLayout { [weak self] in
            guard let self, let first = self.focusableNodes(inPresentation: id).first else { return }
            self.focus(first)
        }
    }

    /// The topmost popup, if a popup is topmost.
    var topPopupID: Int? {
        guard let last = presentations.last, case .popup = last.style else { return nil }
        return last.id
    }

    /// Moves through the topmost popup's items with the arrow keys: up and
    /// down from item to item, wrapping around, and left out of a submenu.
    /// Returns whether it handled the key.
    func moveInTopPopup(_ key: KeyCode) -> Bool {
        guard let id = topPopupID else { return false }
        switch key {
        case .up, .down:
            let items = focusableNodes(inPresentation: id)
            guard !items.isEmpty else { return false }
            let current = focusedNode.flatMap { node in items.firstIndex { $0 === node } }
            let next: Int
            if key == .down {
                next = current.map { ($0 + 1) % items.count } ?? 0
            } else {
                next = current.map { ($0 - 1 + items.count) % items.count } ?? items.count - 1
            }
            focus(items[next])
            return true
        case .left:
            // A submenu closes, back to its menu.
            guard presentations.count >= 2, case .popup = presentations[presentations.count - 2].style else { return false }
            let opener = presentations.last?.opener.node
            dismissPresentation(id)
            // Back to the item it opened from.
            if let target = opener?.firstFocusable, target.isAttached {
                focus(target)
            }
            return true
        default:
            return false
        }
    }

    /// Moves from menu to menu as the pointer moves across a menu bar's
    /// titles: while a title's menu is open, the pointer on another title
    /// opens its menu instead.
    func switchMenu(at point: CGPoint) {
        guard let first = presentations.first, case .popup = first.style,
              let opener = first.opener.node, opener.attributes.opensMenuOnHover != nil,
              let content = root.children.first(where: { $0.key == AnyHashable("content") }),
              let path = content.hitTest(point),
              let title = path.last(where: { $0.attributes.opensMenuOnHover != nil }),
              title !== opener,
              let open = title.attributes.opensMenuOnHover else {
            return
        }
        dismissPresentation(first.id)
        open()
    }

    /// The pointer came to rest on a menu item: the keyboard's highlight in
    /// a popup gives way to it.
    func menuItemHovered() {
        guard let node = focusedNode, node.isAttached else { return }
        var ancestor = node.parent
        while let current = ancestor {
            if current.parent === root, let key = current.key.base as? String, key.hasPrefix("presentation ") {
                focus(nil)
                return
            }
            ancestor = current.parent
        }
    }
}

private struct MenuItemHoveredKey: EnvironmentKey {
    static let defaultValue: DismissAction? = nil
}

private struct DismissPopupsAboveKey: EnvironmentKey {
    static let defaultValue: DismissAction? = nil
}

extension EnvironmentValues {

    /// Dismisses what was presented after the popup the view is in, like
    /// a submenu of its menu.
    internal var dismissPopupsAbove: DismissAction? {
        get { self[DismissPopupsAboveKey.self] }
        set { self[DismissPopupsAboveKey.self] = newValue }
    }

    /// Tells the graph the pointer came to rest on a menu item.
    internal var menuItemHovered: DismissAction? {
        get { self[MenuItemHoveredKey.self] }
        set { self[MenuItemHoveredKey.self] = newValue }
    }
}
