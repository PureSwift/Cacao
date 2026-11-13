//
//  ViewModifiers.swift
//  Cacao
//
//  Created by Alsey Coleman Miller on 11/13/26.
//

import Foundation
#if canImport(CoreGraphics)
import CoreGraphics
#endif

// MARK: - Opacity

internal struct OpacityBehavior: UnaryLayoutBehavior {

    let opacity: Double

    func sizeThatFits(_ proposal: ProposedViewSize, child: LayoutProxy) -> CGSize {
        child.size(in: proposal)
    }

    func placement(of child: LayoutProxy, size: CGSize, proposal: ProposedViewSize) -> (proposal: ProposedViewSize, origin: CGPoint) {
        (proposal, CGPoint(x: 0, y: 0))
    }

    func displayEffect(node: ViewNode) -> DisplayList.Effect? {
        .opacity(opacity)
    }
}

internal struct _OpacityEffect: ViewModifier, LayoutModifier {

    let opacity: Double

    var behavior: any NodeBehavior { OpacityBehavior(opacity: opacity) }

    typealias Body = Never
}

// MARK: - Identity

/// Gives its content an explicit identity, so a new identity replaces it.
internal struct IDView<Content: View, ID: Hashable>: View, PrimitiveView {

    let content: Content

    let id: ID

    func resolve(in context: ResolveContext) -> Resolution {
        Resolution(children: [ChildView(key: id, view: content)])
    }

    typealias Body = Never
}

// MARK: - Attributes

/// Sets attributes of its node, such as lifecycle actions or an identifier.
internal struct _AttributesModifier: ViewModifier, PrimitiveViewModifier {

    let modify: (inout NodeAttributes) -> Void

    func resolve(content: any View, in context: ResolveContext) -> Resolution {
        var attributes = NodeAttributes()
        modify(&attributes)
        return Resolution(children: [ChildView(key: 0, view: content)], attributes: attributes)
    }

    typealias Body = Never
}

// MARK: - View

extension View {

    /// Sets the transparency of this view.
    public func opacity(_ opacity: Double) -> some View {
        modifier(_OpacityEffect(opacity: opacity))
    }

    /// Hides this view unconditionally; it still takes up space.
    public func hidden() -> some View {
        opacity(0)
    }

    /// Binds a view's identity to the given proxy value.
    ///
    /// When the value changes, the view is replaced and its state reset.
    public func id<ID: Hashable>(_ id: ID) -> some View {
        IDView(content: self, id: id)
    }

    /// Uses the string you specify to identify the view.
    public func accessibilityIdentifier(_ identifier: String) -> some View {
        modifier(_AttributesModifier { $0.identifier = identifier })
    }

    /// Adds an action to perform before this view appears.
    public func onAppear(perform action: (() -> Void)? = nil) -> some View {
        modifier(_AttributesModifier { $0.onAppear = action })
    }

    /// Adds an action to perform after this view disappears.
    public func onDisappear(perform action: (() -> Void)? = nil) -> some View {
        modifier(_AttributesModifier { $0.onDisappear = action })
    }
}
