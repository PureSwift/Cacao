//
//  RootView.swift
//  Cacao
//
//  Created by Alsey Coleman Miller on 11/13/26.
//

import Foundation
#if canImport(CoreGraphics)
import CoreGraphics
#endif

/// A view presented above the window's content, like a menu, anchored to a
/// rectangle in the window.
internal struct Popup: Identifiable {

    let id: Int

    /// The rectangle the popup opens from, in the window.
    let anchor: CGRect

    let content: AnyView

    let onDismiss: (() -> Void)?
}

/// The root of a graph: the app's content, centered in the window, and the
/// popups presented above it.
internal struct _GraphRoot: View, PrimitiveView {

    let content: AnyView

    let popups: [Popup]

    func resolve(in context: ResolveContext) -> Resolution {
        var children = [ChildView(key: "content", view: content)]
        if !popups.isEmpty {
            let graph = context.graph
            children.append(ChildView(
                key: "backdrop",
                view: Color.clear
                    .contentShape(Rectangle())
                    .onTapGesture { [weak graph] in graph?.dismissAllPopups() }
            ))
            for popup in popups {
                var environment = context.environment
                environment.dismissPopup = DismissAction { [weak graph] in graph?.dismissPopup(popup.id) }
                children.append(ChildView(key: popup.id, view: popup.content, environment: environment))
            }
        }
        return Resolution(behavior: RootBehavior(anchors: popups.map(\.anchor)), children: children)
    }

    typealias Body = Never
}

internal struct RootBehavior: NodeBehavior {

    /// The anchor of each popup, in order.
    let anchors: [CGRect]

    func sizeThatFits(_ proposal: ProposedViewSize, node: ViewNode) -> CGSize {
        proposal.replacingUnspecifiedDimensions(by: .zero)
    }

    func placeChildren(in bounds: CGRect, proposal: ProposedViewSize, node: ViewNode) {
        if let content = LayoutProxy.combining(node.layoutChildren(ofChildAt: 0)) {
            let size = content.size(in: proposal)
            content.place(
                at: CGPoint(x: bounds.minX + (bounds.width - size.width) / 2, y: bounds.minY + (bounds.height - size.height) / 2),
                proposal: proposal
            )
        }
        guard !anchors.isEmpty else { return }
        if let backdrop = LayoutProxy.combining(node.layoutChildren(ofChildAt: 1)) {
            backdrop.place(at: bounds.origin, proposal: ProposedViewSize(bounds.size))
        }
        // Each popup at its ideal size, below its anchor, or above it when it
        // doesn't fit below, kept within the window.
        for (index, anchor) in anchors.enumerated() {
            guard let popup = LayoutProxy.combining(node.layoutChildren(ofChildAt: index + 2)) else { continue }
            let maxSize = ProposedViewSize(width: nil, height: bounds.height - 16)
            var size = popup.size(in: maxSize)
            size.height = min(size.height, bounds.height - 16)
            var origin = CGPoint(x: anchor.minX, y: anchor.maxY + 4)
            if origin.y + size.height > bounds.maxY - 8 {
                origin.y = max(bounds.minY + 8, anchor.minY - 4 - size.height)
            }
            origin.x = min(max(origin.x, bounds.minX + 8), bounds.maxX - 8 - size.width)
            popup.place(at: origin, proposal: ProposedViewSize(size))
        }
    }
}

// MARK: - Dismissing

/// An action that dismisses a presentation.
public struct DismissAction: Sendable {

    internal let action: @MainActor @Sendable () -> Void

    internal init(_ action: @escaping @MainActor @Sendable () -> Void) {
        self.action = action
    }

    /// Dismisses the current presentation.
    @MainActor
    public func callAsFunction() {
        action()
    }
}

private struct DismissPopupKey: EnvironmentKey {
    static let defaultValue: DismissAction? = nil
}

extension EnvironmentValues {

    /// Dismisses the popup the view is in, if any.
    internal var dismissPopup: DismissAction? {
        get { self[DismissPopupKey.self] }
        set { self[DismissPopupKey.self] = newValue }
    }
}

// MARK: - Graph

extension ViewGraph {

    /// Presents a popup anchored to a rectangle in the window.
    @discardableResult
    func presentPopup(anchor: CGRect, content: AnyView, onDismiss: (() -> Void)? = nil) -> Int {
        nextPopupID += 1
        popups.append(Popup(id: nextPopupID, anchor: anchor, content: content, onDismiss: onDismiss))
        updateRoot()
        return nextPopupID
    }

    /// Dismisses a popup and those presented after it.
    func dismissPopup(_ id: Int) {
        guard let index = popups.firstIndex(where: { $0.id == id }) else { return }
        let dismissed = popups[index...]
        popups.removeSubrange(index...)
        updateRoot()
        dismissed.reversed().forEach { $0.onDismiss?() }
    }

    func dismissAllPopups() {
        if let first = popups.first {
            dismissPopup(first.id)
        }
    }

    /// Whether a popup is showing.
    package var isPresentingPopup: Bool {
        !popups.isEmpty
    }

    func updateRoot() {
        root.update(view: _GraphRoot(content: rootContent, popups: popups), environment: environment)
        root.invalidate()
    }
}

extension ViewNode {

    /// The node's subtree frame as it shows in the window, after the
    /// offsets of the scroll views it's in.
    var windowFrame: CGRect {
        var frame = subtreeFrame
        var ancestor = parent
        while let node = ancestor {
            if let scroll = node.behavior as? ScrollBehavior {
                let offset = scroll.state(of: node).offset
                frame = frame.offsetBy(dx: -offset.x, dy: -offset.y)
            }
            ancestor = node.parent
        }
        return frame
    }
}
