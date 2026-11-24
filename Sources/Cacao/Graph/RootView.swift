//
//  RootView.swift
//  Cacao
//
//  Created by Alsey Coleman Miller on 11/13/26.
//

import CacaoRender
import Foundation
#if canImport(CoreGraphics)
import CoreGraphics
#endif

// MARK: - Presentations

/// How a presentation shows above the window's content.
internal enum PresentationStyle {

    /// Anchored to a rectangle in the window, like a menu or popover, on
    /// one of its sides; dismissed by a tap outside.
    case popup(anchor: CGRect, edge: PopupEdge)

    /// A modal card centered in the window over a dimmed backdrop.
    case sheet(fillsWindow: Bool)

    /// A small modal dialog centered in the window.
    case alert
}

/// The side of its anchor a popup opens on.
package enum PopupEdge: Hashable, Sendable {

    /// Below, their leading edges lined up: a menu from a button.
    case bottom

    /// After, their tops lined up: a submenu.
    case trailing
}

/// A view presented above the window's content.
internal struct Presentation {

    let id: Int

    /// The identity of what presented it, to update or remove it.
    let owner: AnyHashable

    let style: PresentationStyle

    var content: AnyView

    var environment: EnvironmentValues?

    let onDismiss: (() -> Void)?

    /// Whether the popup shows in a surface of its own, outside the window,
    /// rather than in it.
    var isDetached = false

    /// The popup it opened from, as a submenu does from its menu.
    var parentID: Int?

    /// The height the system gave its surface, when it made it shorter.
    var maximumHeight: CGFloat?

    /// The view it opened from, like a submenu's item, which takes focus
    /// back when the keyboard closes it.
    var opener = WeakNodeReference()

    /// Whether it's a menu, which a choice in it, or in its submenus,
    /// closes.
    var isMenu = false
}

/// The root of a graph: the app's content, centered in the window, and the
/// presentations above it, which it reads from the graph.
internal struct _GraphRoot: View, PrimitiveView {

    let content: AnyView

    func resolve(in context: ResolveContext) -> Resolution {
        let graph = context.graph
        var children = [ChildView(key: "content", view: content)]
        for presentation in graph.presentations {
            let isModal: Bool
            switch presentation.style {
            case .popup: isModal = false
            case .sheet, .alert: isModal = true
            }
            let id = presentation.id
            // A tap outside a popup in a surface of its own closes its
            // whole chain of menus, which are all outside the window.
            let dismissed = presentation.isDetached ? graph.rootPopupID(of: id) : id
            children.append(ChildView(
                key: "backdrop \(id)",
                view: (isModal ? Color.black.opacity(0.35) : Color.clear)
                    .contentShape(Rectangle())
                    .onTapGesture { [weak graph] in
                        if !isModal { graph?.dismissPresentation(dismissed) }
                    }
                    .transition(.opacity)
            ))
            var environment = presentation.environment ?? context.environment
            // A choice in a menu closes it, and the menus it opened from.
            environment.dismissPopup = DismissAction { [weak graph] in
                guard let graph else { return }
                graph.dismissPresentation(graph.rootMenuID(of: id))
            }
            environment.dismiss = environment.dismissPopup!
            environment.dismissPopupsAbove = DismissAction { [weak graph] in graph?.dismissPresentations(after: id) }
            environment.menuItemHovered = DismissAction { [weak graph] in graph?.menuItemHovered() }
            children.append(ChildView(
                key: "presentation \(id)",
                view: presentation.containerView,
                environment: environment
            ))
        }
        // A tooltip above everything, where the pointer rested.
        if let tooltip = graph.tooltip {
            children.append(ChildView(key: "tooltip", view: _Tooltip(text: tooltip.text)))
        }
        var resolution = Resolution(
            behavior: RootBehavior(
                presentations: graph.presentations.map { presentation in
                    RootBehavior.Placement(
                        style: presentation.style,
                        detachedOrigin: presentation.isDetached ? ViewGraph.detachedOrigin(of: presentation.id) : nil,
                        maximumHeight: presentation.maximumHeight ?? graph.popupMaximumHeight
                    )
                },
                tooltipLocation: graph.tooltip?.location
            ),
            children: children
        )
        // Presenting or dismissing doesn't change the content; a new root
        // view does.
        resolution.keepsExistingChildren = !context.node.wasUpdatedByParent
        // Presentations come and go animated.
        let ids = graph.presentations.map(\.id)
        let storage = context.node.dynamicStorage["presentationIDs"] as? StorageBox<[Int]>
        if let storage, storage.value != ids {
            resolution.transaction = { $0.animateByDefault() }
        }
        context.node.dynamicStorage["presentationIDs"] = StorageBox(ids)
        return resolution
    }

    typealias Body = Never
}

extension Presentation {

    /// How it comes and goes: sheets slide up; dialogs and popups fade. A
    /// popup in a surface of its own comes and goes with its surface.
    var transition: AnyTransition {
        switch style {
        case .sheet: .move(edge: .bottom)
        case .popup where isDetached: .identity
        case .alert, .popup: .opacity
        }
    }

    /// The view showing it, in its chrome.
    @MainActor
    var containerView: some View {
        _PresentationContainer(style: style, content: content)
            .transition(transition)
    }
}

/// A presentation's chrome: popups draw their own; sheets and dialogs get a
/// card.
internal struct _PresentationContainer: View {

    let style: PresentationStyle

    let content: AnyView

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        // A presentation isn't part of the screen that presents it: a
        // navigation stack in it has its own bar.
        switch style {
        case .popup:
            content
                .environment(\.screenContext, nil)
        case .sheet, .alert:
            content
                .environment(\.screenContext, nil)
                .environment(\.screenBackground, Color.controlBackground(colorScheme))
                .background { Color.controlBackground(colorScheme) }
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .overlay { RoundedRectangle(cornerRadius: 12).strokeBorder(Color.separator, lineWidth: 1) }
        }
    }
}

internal struct RootBehavior: NodeBehavior {

    /// How a presentation is placed.
    struct Placement {

        let style: PresentationStyle

        /// Where a popup in a surface of its own goes, away from the
        /// window's content.
        let detachedOrigin: CGPoint?

        /// The tallest a popup in a surface of its own gets.
        let maximumHeight: CGFloat
    }

    /// Each presentation, in order.
    let presentations: [Placement]

    var styles: [PresentationStyle] {
        presentations.map(\.style)
    }

    /// Where the pointer rested, when a tooltip shows.
    var tooltipLocation: CGPoint? = nil

    func sizeThatFits(_ proposal: ProposedViewSize, node: ViewNode) -> CGSize {
        proposal.replacingUnspecifiedDimensions(by: .zero)
    }

    func placeChildren(in bounds: CGRect, proposal: ProposedViewSize, node: ViewNode) {
        if let content = LayoutProxy.combining(node.layoutChildren(ofChildAt: 0)) {
            // Content stays inside the window's safe area.
            let insets = node.graph.safeAreaInsets
            let safe = CGRect(
                x: bounds.minX + insets.leading,
                y: bounds.minY + insets.top,
                width: max(bounds.width - insets.leading - insets.trailing, 0),
                height: max(bounds.height - insets.top - insets.bottom, 0)
            )
            let proposal = ProposedViewSize(safe.size)
            let size = content.size(in: proposal)
            content.place(
                at: CGPoint(x: safe.minX + (safe.width - size.width) / 2, y: safe.minY + (safe.height - size.height) / 2),
                proposal: proposal
            )
        }
        if let location = tooltipLocation, bounds.insetBy(dx: -1, dy: -1).contains(location),
           let tooltip = LayoutProxy.combining(node.layoutChildren(ofChildAt: 1 + styles.count * 2)) {
            // Below and right of the pointer, within the window, at most
            // 300 points wide.
            var size = tooltip.size(in: .unspecified)
            if size.width > 300 {
                size = tooltip.size(in: ProposedViewSize(width: 300, height: nil))
            }
            let margin: CGFloat = 4
            var origin = CGPoint(x: location.x + 8, y: location.y + 18)
            if origin.y + size.height > bounds.maxY - margin {
                origin.y = location.y - 8 - size.height
            }
            origin.x = min(max(origin.x, bounds.minX + margin), bounds.maxX - margin - size.width)
            tooltip.place(at: origin, proposal: ProposedViewSize(size))
        }
        for (index, placement) in presentations.enumerated() {
            if let backdrop = LayoutProxy.combining(node.layoutChildren(ofChildAt: 1 + index * 2)) {
                backdrop.place(at: bounds.origin, proposal: ProposedViewSize(bounds.size))
            }
            guard let presentation = LayoutProxy.combining(node.layoutChildren(ofChildAt: 2 + index * 2)) else { continue }
            let margin: CGFloat = 8
            switch placement.style {
            case .popup where placement.detachedOrigin != nil:
                // At its ideal size, away from the content: the system
                // places its surface next to the anchor.
                var size = presentation.size(in: ProposedViewSize(width: nil, height: placement.maximumHeight))
                size.height = min(size.height, placement.maximumHeight)
                presentation.place(at: placement.detachedOrigin!, proposal: ProposedViewSize(size))
            case let .popup(anchor, edge):
                // At its ideal size, within the window: below its anchor,
                // or above it when it doesn't fit below; or after it, or
                // before it when it doesn't fit after.
                var size = presentation.size(in: ProposedViewSize(width: nil, height: bounds.height - 2 * margin))
                size.height = min(size.height, bounds.height - 2 * margin)
                var origin: CGPoint
                switch edge {
                case .bottom:
                    origin = CGPoint(x: anchor.minX, y: anchor.maxY + PopupMetrics.gap)
                    if origin.y + size.height > bounds.maxY - margin {
                        origin.y = max(bounds.minY + margin, anchor.minY - PopupMetrics.gap - size.height)
                    }
                case .trailing:
                    origin = CGPoint(x: anchor.maxX, y: anchor.minY - PopupMetrics.submenuInset)
                    if origin.x + size.width > bounds.maxX - margin {
                        origin.x = anchor.minX - size.width
                    }
                    origin.y = min(max(origin.y, bounds.minY + margin), bounds.maxY - margin - size.height)
                }
                origin.x = min(max(origin.x, bounds.minX + margin), bounds.maxX - margin - size.width)
                presentation.place(at: origin, proposal: ProposedViewSize(size))
            case let .sheet(fillsWindow):
                let size: CGSize
                if fillsWindow {
                    size = bounds.size
                } else {
                    // Its ideal size, at least a comfortable minimum, within the window.
                    let maximum = CGSize(width: bounds.width - 80, height: bounds.height - 80)
                    let ideal = presentation.size(in: ProposedViewSize(width: min(maximum.width, 520), height: nil))
                    size = CGSize(
                        width: min(max(ideal.width, min(420, maximum.width)), maximum.width),
                        height: min(max(ideal.height, min(320, maximum.height)), maximum.height)
                    )
                }
                presentation.place(
                    at: CGPoint(x: bounds.midX - size.width / 2, y: bounds.midY - size.height / 2),
                    proposal: ProposedViewSize(size)
                )
            case .alert:
                let width = min(300, bounds.width - 2 * margin)
                let size = presentation.size(in: ProposedViewSize(width: width, height: nil))
                presentation.place(
                    at: CGPoint(x: bounds.midX - width / 2, y: bounds.midY - size.height / 2),
                    proposal: ProposedViewSize(width: width, height: size.height)
                )
            }
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

private struct DismissKey: EnvironmentKey {
    static let defaultValue = DismissAction { }
}

extension EnvironmentValues {

    /// Dismisses the popup or dialog the view is in, if any; buttons in
    /// popups and dialogs call it after their action.
    internal var dismissPopup: DismissAction? {
        get { self[DismissPopupKey.self] }
        set { self[DismissPopupKey.self] = newValue }
    }

    /// An action that dismisses the current presentation.
    public var dismiss: DismissAction {
        get { self[DismissKey.self] }
        set { self[DismissKey.self] = newValue }
    }
}

// MARK: - Graph

extension ViewGraph {

    /// Presents a view, or updates the one presented by the same owner.
    @discardableResult
    func present(
        owner: AnyHashable,
        style: PresentationStyle,
        content: AnyView,
        environment: EnvironmentValues? = nil,
        onDismiss: (() -> Void)? = nil
    ) -> Int {
        if let index = presentations.firstIndex(where: { $0.owner == owner }) {
            presentations[index].content = content
            presentations[index].environment = environment
            let id = presentations[index].id
            // Update the presented view alone, not the whole window.
            if let node = root.children.first(where: { $0.key == AnyHashable("presentation \(id)") }) {
                var environment = node.environment
                if let presenter = presentations[index].environment {
                    environment = presenter
                    environment.dismissPopup = node.environment.dismissPopup
                    environment.dismiss = node.environment.dismiss
                }
                node.update(view: presentations[index].containerView, environment: environment)
                node.invalidate()
            }
            return id
        }
        nextPopupID += 1
        var presentation = Presentation(
            id: nextPopupID,
            owner: owner,
            style: style,
            content: content,
            environment: environment,
            onDismiss: onDismiss
        )
        if case let .popup(anchor, _) = style {
            // Belonging to the popup it opens from, if any, as a submenu
            // does: its anchor is in that popup.
            let point = CGPoint(x: anchor.midX, y: anchor.midY)
            let parent = presentations.last { presentation in
                guard case .popup = presentation.style else { return false }
                return presentationNode(presentation.id)?.subtreeFrame.contains(point) ?? false
            }
            presentation.parentID = parent?.id
            // In a surface of its own, as its parent is.
            presentation.isDetached = opensPopupSurfaces && (parent?.isDetached ?? true)
        }
        presentations.append(presentation)
        root.invalidate()
        return nextPopupID
    }

    /// Anchors a popup to a rectangle in the window, on one of its sides.
    @discardableResult
    func presentPopup(anchor: CGRect, edge: PopupEdge = .bottom, content: AnyView, opener: ViewNode? = nil, onDismiss: (() -> Void)? = nil) -> Int {
        let id = present(owner: AnyHashable("popup \(nextPopupID + 1)"), style: .popup(anchor: anchor, edge: edge), content: content, onDismiss: onDismiss)
        if let index = presentations.firstIndex(where: { $0.id == id }) {
            presentations[index].opener.node = opener
            presentations[index].isMenu = true
        }
        return id
    }

    /// Dismisses the presentations presented after one, like a submenu
    /// of a menu.
    func dismissPresentations(after id: Int) {
        guard let index = presentations.firstIndex(where: { $0.id == id }), index + 1 < presentations.count else { return }
        dismissPresentation(presentations[index + 1].id)
    }

    /// Dismisses a presentation and those presented after it.
    package func dismissPresentation(_ id: Int) {
        guard let index = presentations.firstIndex(where: { $0.id == id }) else { return }
        let dismissed = presentations[index...]
        presentations.removeSubrange(index...)
        root.invalidate()
        dismissed.reversed().forEach { $0.onDismiss?() }
    }

    /// Removes what an owner presented, without calling its dismiss action.
    func removePresentation(owner: AnyHashable) {
        guard let index = presentations.firstIndex(where: { $0.owner == owner }) else { return }
        presentations.remove(at: index)
        root.invalidate()
    }

    func dismissAllPopups() {
        if let first = presentations.first(where: { if case .popup = $0.style { true } else { false } }) {
            dismissPresentation(first.id)
        }
    }

    /// Dismisses the topmost presentation.
    func dismissTopPresentation() {
        if let last = presentations.last {
            dismissPresentation(last.id)
        }
    }

    /// Whether a popup is showing.
    package var isPresentingPopup: Bool {
        presentations.contains { if case .popup = $0.style { true } else { false } }
    }

    /// Whether anything is presented above the content.
    package var isPresenting: Bool {
        !presentations.isEmpty
    }

    func updateRoot() {
        root.update(view: _GraphRoot(content: rootContent), environment: environment)
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
