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

// MARK: - Presentations

/// How a presentation shows above the window's content.
internal enum PresentationStyle {

    /// Anchored to a rectangle in the window, like a menu or popover;
    /// dismissed by a tap outside.
    case popup(anchor: CGRect)

    /// A modal card centered in the window over a dimmed backdrop.
    case sheet(fillsWindow: Bool)

    /// A small modal dialog centered in the window.
    case alert
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
            children.append(ChildView(
                key: "backdrop \(id)",
                view: (isModal ? Color.black.opacity(0.35) : Color.clear)
                    .contentShape(Rectangle())
                    .onTapGesture { [weak graph] in
                        if !isModal { graph?.dismissPresentation(id) }
                    }
                    .transition(.opacity)
            ))
            var environment = presentation.environment ?? context.environment
            environment.dismissPopup = DismissAction { [weak graph] in graph?.dismissPresentation(id) }
            environment.dismiss = environment.dismissPopup!
            // Sheets slide up; dialogs and popups fade.
            let transition: AnyTransition
            switch presentation.style {
            case .sheet: transition = .move(edge: .bottom)
            case .alert, .popup: transition = .opacity
            }
            children.append(ChildView(
                key: "presentation \(id)",
                view: _PresentationContainer(style: presentation.style, content: presentation.content)
                    .transition(transition),
                environment: environment
            ))
        }
        var resolution = Resolution(
            behavior: RootBehavior(styles: graph.presentations.map(\.style)),
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

/// A presentation's chrome: popups draw their own; sheets and dialogs get a
/// card.
internal struct _PresentationContainer: View {

    let style: PresentationStyle

    let content: AnyView

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        switch style {
        case .popup:
            content
        case .sheet, .alert:
            content
                .background { Color.controlBackground(colorScheme) }
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .overlay { RoundedRectangle(cornerRadius: 12).strokeBorder(Color.separator, lineWidth: 1) }
        }
    }
}

internal struct RootBehavior: NodeBehavior {

    /// The style of each presentation, in order.
    let styles: [PresentationStyle]

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
        for (index, style) in styles.enumerated() {
            if let backdrop = LayoutProxy.combining(node.layoutChildren(ofChildAt: 1 + index * 2)) {
                backdrop.place(at: bounds.origin, proposal: ProposedViewSize(bounds.size))
            }
            guard let presentation = LayoutProxy.combining(node.layoutChildren(ofChildAt: 2 + index * 2)) else { continue }
            let margin: CGFloat = 8
            switch style {
            case let .popup(anchor):
                // At its ideal size, below its anchor, or above it when it
                // doesn't fit below, within the window.
                var size = presentation.size(in: ProposedViewSize(width: nil, height: bounds.height - 2 * margin))
                size.height = min(size.height, bounds.height - 2 * margin)
                var origin = CGPoint(x: anchor.minX, y: anchor.maxY + 4)
                if origin.y + size.height > bounds.maxY - margin {
                    origin.y = max(bounds.minY + margin, anchor.minY - 4 - size.height)
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
                node.update(view: _PresentationContainer(style: presentations[index].style, content: content), environment: environment)
                node.invalidate()
            }
            return id
        }
        nextPopupID += 1
        presentations.append(Presentation(
            id: nextPopupID,
            owner: owner,
            style: style,
            content: content,
            environment: environment,
            onDismiss: onDismiss
        ))
        root.invalidate()
        return nextPopupID
    }

    /// Anchors a popup to a rectangle in the window.
    @discardableResult
    func presentPopup(anchor: CGRect, content: AnyView, onDismiss: (() -> Void)? = nil) -> Int {
        present(owner: AnyHashable("popup \(nextPopupID + 1)"), style: .popup(anchor: anchor), content: content, onDismiss: onDismiss)
    }

    /// Dismisses a presentation and those presented after it.
    func dismissPresentation(_ id: Int) {
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
