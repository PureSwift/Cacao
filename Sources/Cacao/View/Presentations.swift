//
//  Presentations.swift
//  Cacao
//
//  Created by Alsey Coleman Miller on 11/13/26.
//

import CacaoRender
import Foundation
#if canImport(CoreGraphics)
import CoreGraphics
#endif

/// Presents content while a binding is true, owned by this modifier's node.
internal struct _PresentationModifier: ViewModifier, PrimitiveViewModifier {

    let isPresented: Binding<Bool>

    let style: @MainActor (ViewNode) -> PresentationStyle

    let presentation: AnyView

    let onDismiss: (() -> Void)?

    func resolve(content: any View, in context: ResolveContext) -> Resolution {
        let node = context.node
        let graph = context.graph
        let owner = AnyHashable(node.id)
        if isPresented.wrappedValue {
            let isPresented = self.isPresented
            let onDismiss = self.onDismiss
            let style = self.style
            let presentation = self.presentation
            let environment = context.environment
            // Present after this update, when the node has a frame to anchor to.
            graph.deferAction { [weak node, weak graph] in
                guard let node, let graph, node.isAttached, isPresented.wrappedValue else { return }
                graph.present(owner: owner, style: style(node), content: presentation, environment: environment) {
                    isPresented.wrappedValue = false
                    onDismiss?()
                }
            }
        } else {
            graph.removePresentation(owner: owner)
        }
        return Resolution(children: [ChildView(key: 0, view: content)])
    }

    typealias Body = Never
}

/// The visibility of a dialog's title.
public enum Visibility: Hashable, CaseIterable, Sendable {
    case automatic
    case visible
    case hidden
}

extension View {

    // MARK: Sheets

    /// Presents a sheet when a binding to a Boolean value that you provide
    /// is true.
    public func sheet<Content: View>(
        isPresented: Binding<Bool>,
        onDismiss: (() -> Void)? = nil,
        @ViewBuilder content: () -> Content
    ) -> some View {
        modifier(_PresentationModifier(
            isPresented: isPresented,
            style: { _ in .sheet(fillsWindow: false) },
            presentation: AnyView(content()),
            onDismiss: onDismiss
        ))
    }

    /// Presents a sheet using the given item as a data source for the
    /// sheet's content.
    public func sheet<Item: Identifiable, Content: View>(
        item: Binding<Item?>,
        onDismiss: (() -> Void)? = nil,
        @ViewBuilder content: (Item) -> Content
    ) -> some View {
        let presented = Binding(get: { item.wrappedValue != nil }, set: { if !$0 { item.wrappedValue = nil } })
        return modifier(_PresentationModifier(
            isPresented: presented,
            style: { _ in .sheet(fillsWindow: false) },
            presentation: item.wrappedValue.map { AnyView(content($0).id($0.id)) } ?? AnyView(EmptyView()),
            onDismiss: onDismiss
        ))
    }

    /// Presents a modal view that covers the window when a binding to a
    /// Boolean value that you provide is true.
    public func fullScreenCover<Content: View>(
        isPresented: Binding<Bool>,
        onDismiss: (() -> Void)? = nil,
        @ViewBuilder content: () -> Content
    ) -> some View {
        modifier(_PresentationModifier(
            isPresented: isPresented,
            style: { _ in .sheet(fillsWindow: true) },
            presentation: AnyView(content()),
            onDismiss: onDismiss
        ))
    }

    // MARK: Alerts

    /// Presents an alert when a given condition is true, using a text view
    /// for the title.
    public func alert<A: View, M: View>(
        _ title: Text,
        isPresented: Binding<Bool>,
        @ViewBuilder actions: () -> A,
        @ViewBuilder message: () -> M
    ) -> some View {
        modifier(_PresentationModifier(
            isPresented: isPresented,
            style: { _ in .alert },
            presentation: AnyView(_AlertContent(title: title, message: AnyView(message()), actions: AnyView(actions()), isDialog: false)),
            onDismiss: nil
        ))
    }

    /// Presents an alert when a given condition is true, using a localized
    /// string key for the title.
    public func alert<A: View, M: View>(
        _ titleKey: LocalizedStringKey,
        isPresented: Binding<Bool>,
        @ViewBuilder actions: () -> A,
        @ViewBuilder message: () -> M
    ) -> some View {
        alert(Text(titleKey), isPresented: isPresented, actions: actions, message: message)
    }

    /// Presents an alert when a given condition is true, using a localized
    /// string key for the title.
    public func alert<A: View>(
        _ titleKey: LocalizedStringKey,
        isPresented: Binding<Bool>,
        @ViewBuilder actions: () -> A
    ) -> some View {
        alert(Text(titleKey), isPresented: isPresented, actions: actions, message: { EmptyView() })
    }

    /// Presents an alert when a given condition is true, using a string for
    /// the title.
    @_disfavoredOverload
    public func alert<S: StringProtocol, A: View>(
        _ title: S,
        isPresented: Binding<Bool>,
        @ViewBuilder actions: () -> A
    ) -> some View {
        alert(Text(title), isPresented: isPresented, actions: actions, message: { EmptyView() })
    }

    /// Presents an alert when a given condition is true, using a text view
    /// for the title.
    public func alert<A: View>(
        _ title: Text,
        isPresented: Binding<Bool>,
        @ViewBuilder actions: () -> A
    ) -> some View {
        alert(title, isPresented: isPresented, actions: actions, message: { EmptyView() })
    }

    /// Presents an alert with a message when a given condition is true,
    /// using a string for the title.
    @_disfavoredOverload
    public func alert<S: StringProtocol, A: View, M: View>(
        _ title: S,
        isPresented: Binding<Bool>,
        @ViewBuilder actions: () -> A,
        @ViewBuilder message: () -> M
    ) -> some View {
        alert(Text(title), isPresented: isPresented, actions: actions, message: message)
    }

    // MARK: Confirmation dialogs

    /// Presents a confirmation dialog when a given condition is true, using
    /// a text view for the title.
    public func confirmationDialog<A: View, M: View>(
        _ title: Text,
        isPresented: Binding<Bool>,
        titleVisibility: Visibility = .automatic,
        @ViewBuilder actions: () -> A,
        @ViewBuilder message: () -> M
    ) -> some View {
        modifier(_PresentationModifier(
            isPresented: isPresented,
            style: { _ in .alert },
            presentation: AnyView(_AlertContent(
                title: titleVisibility == .hidden ? nil : title,
                message: AnyView(message()),
                actions: AnyView(actions()),
                isDialog: true
            )),
            onDismiss: nil
        ))
    }

    /// Presents a confirmation dialog when a given condition is true, using
    /// a text view for the title.
    public func confirmationDialog<A: View>(
        _ title: Text,
        isPresented: Binding<Bool>,
        titleVisibility: Visibility = .automatic,
        @ViewBuilder actions: () -> A
    ) -> some View {
        confirmationDialog(title, isPresented: isPresented, titleVisibility: titleVisibility, actions: actions, message: { EmptyView() })
    }

    /// Presents a confirmation dialog when a given condition is true, using
    /// a string for the title.
    @_disfavoredOverload
    public func confirmationDialog<S: StringProtocol, A: View, M: View>(
        _ title: S,
        isPresented: Binding<Bool>,
        titleVisibility: Visibility = .automatic,
        @ViewBuilder actions: () -> A,
        @ViewBuilder message: () -> M
    ) -> some View {
        confirmationDialog(Text(title), isPresented: isPresented, titleVisibility: titleVisibility, actions: actions, message: message)
    }

    /// Presents a confirmation dialog when a given condition is true, using
    /// a localized string key for the title.
    public func confirmationDialog<A: View, M: View>(
        _ titleKey: LocalizedStringKey,
        isPresented: Binding<Bool>,
        titleVisibility: Visibility = .automatic,
        @ViewBuilder actions: () -> A,
        @ViewBuilder message: () -> M
    ) -> some View {
        confirmationDialog(Text(titleKey), isPresented: isPresented, titleVisibility: titleVisibility, actions: actions, message: message)
    }

    /// Presents a confirmation dialog when a given condition is true.
    public func confirmationDialog<A: View>(
        _ titleKey: LocalizedStringKey,
        isPresented: Binding<Bool>,
        titleVisibility: Visibility = .automatic,
        @ViewBuilder actions: () -> A
    ) -> some View {
        confirmationDialog(titleKey, isPresented: isPresented, titleVisibility: titleVisibility, actions: actions, message: { EmptyView() })
    }

    // MARK: Popovers

    /// Presents a popover when a given condition is true, anchored to this view.
    public func popover<Content: View>(
        isPresented: Binding<Bool>,
        attachmentAnchor: PopoverAttachmentAnchor = .rect(.bounds),
        arrowEdge: Edge = .top,
        @ViewBuilder content: () -> Content
    ) -> some View {
        modifier(_PresentationModifier(
            isPresented: isPresented,
            style: { node in .popup(anchor: node.windowFrame, edge: .bottom) },
            presentation: AnyView(_PopoverContent(content: AnyView(content()))),
            onDismiss: nil
        ))
    }

    // MARK: Context menus

    /// Adds a context menu to a view, shown on a secondary click.
    public func contextMenu<MenuItems: View>(@ViewBuilder menuItems: () -> MenuItems) -> some View {
        modifier(_ContextMenuModifier(items: AnyView(_MenuContent(content: AnyView(menuItems())))))
    }

    /// Adds custom swipe actions to a row in a list. With a pointer, there's
    /// no swipe: the actions show in the row's context menu, as on the Mac.
    public func swipeActions<T: View>(
        edge: HorizontalEdge = .trailing,
        allowsFullSwipe: Bool = true,
        @ViewBuilder content: () -> T
    ) -> some View {
        modifier(_ContextMenuModifier(items: AnyView(_MenuContent(content: AnyView(content())))))
    }
}

/// An anchor for a popover.
public enum PopoverAttachmentAnchor: Sendable {

    /// The anchor point for the popover relative to the source's frame.
    case rect(Anchor<CGRect>.Source)

    /// The anchor point for the popover expressed as a unit point.
    case point(UnitPoint)
}

/// A popover's chrome: a card sized to its content.
internal struct _PopoverContent: View {

    let content: AnyView

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        content
            .environment(\.screenBackground, Color.controlBackground(colorScheme))
            .padding(12)
            .background { RoundedRectangle(cornerRadius: 10).fill(Color.controlBackground(colorScheme)) }
            .overlay { RoundedRectangle(cornerRadius: 10).strokeBorder(Color.separator, lineWidth: 1) }
    }
}

/// An alert's or confirmation dialog's content: title, message and actions.
internal struct _AlertContent: View {

    let title: Text?

    let message: AnyView

    let actions: AnyView

    /// Whether to stack actions full width, as a confirmation dialog does.
    let isDialog: Bool

    var body: some View {
        let options = Cacao.options(in: actions)
        VStack(spacing: 14) {
            if let title {
                title
                    .font(.headline)
                    .multilineTextAlignment(.center)
            }
            message
                .font(.callout)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            if options.isEmpty || options.allSatisfy({ $0.label.view is EmptyView }) {
                Button("OK") { }
                    .buttonStyle(.borderedProminent)
            } else if isDialog || options.count > 2 {
                VStack(spacing: 8) {
                    actions
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
            } else {
                HStack(spacing: 10) {
                    actions
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
            }
        }
        .padding(20)
    }
}

// MARK: - Context menus

internal struct _ContextMenuModifier: ViewModifier, PrimitiveViewModifier {

    let items: AnyView

    func resolve(content: any View, in context: ResolveContext) -> Resolution {
        var attributes = NodeAttributes()
        attributes.contextMenu = items
        return Resolution(children: [ChildView(key: 0, view: content)], attributes: attributes)
    }

    typealias Body = Never
}

extension ViewGraph {

    /// Opens the context menu of the innermost view under a point that has
    /// one, at the point; returns whether one opened.
    @discardableResult
    package func secondaryClick(at point: CGPoint) -> Bool {
        let path = root.hitTest(point) ?? []
        guard let node = path.last(where: { $0.attributes.contextMenu != nil }),
              let items = node.attributes.contextMenu else {
            return false
        }
        dismissAllPopups()
        presentPopup(anchor: CGRect(x: point.x, y: point.y - 4, width: 1, height: 1), content: items)
        return true
    }
}
