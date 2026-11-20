//
//  Accessibility.swift
//  Cacao
//
//  Created by Alsey Coleman Miller on 11/13/26.
//

import CacaoRender
import Foundation
#if canImport(CoreGraphics)
import CoreGraphics
#endif

// MARK: - Traits

/// A set of accessibility traits that describe how an element behaves.
public struct AccessibilityTraits: OptionSet, Hashable, Sendable {

    public let rawValue: Int

    public init(rawValue: Int) {
        self.rawValue = rawValue
    }

    public static let isButton = AccessibilityTraits(rawValue: 1 << 0)
    public static let isHeader = AccessibilityTraits(rawValue: 1 << 1)
    public static let isSelected = AccessibilityTraits(rawValue: 1 << 2)
    public static let isLink = AccessibilityTraits(rawValue: 1 << 3)
    public static let isSearchField = AccessibilityTraits(rawValue: 1 << 4)
    public static let isImage = AccessibilityTraits(rawValue: 1 << 5)
    public static let playsSound = AccessibilityTraits(rawValue: 1 << 6)
    public static let isKeyboardKey = AccessibilityTraits(rawValue: 1 << 7)
    public static let isStaticText = AccessibilityTraits(rawValue: 1 << 8)
    public static let isSummaryElement = AccessibilityTraits(rawValue: 1 << 9)
    public static let updatesFrequently = AccessibilityTraits(rawValue: 1 << 10)
    public static let startsMediaSession = AccessibilityTraits(rawValue: 1 << 11)
    public static let allowsDirectInteraction = AccessibilityTraits(rawValue: 1 << 12)
    public static let causesPageTurn = AccessibilityTraits(rawValue: 1 << 13)
    public static let isModal = AccessibilityTraits(rawValue: 1 << 14)
    public static let isToggle = AccessibilityTraits(rawValue: 1 << 15)
    public static let isTabBar = AccessibilityTraits(rawValue: 1 << 16)
}

/// Defines the behavior for the child elements of the new parent element.
public struct AccessibilityChildBehavior: Hashable, Sendable {

    enum Kind: Hashable, Sendable {
        case ignore
        case contain
        case combine
    }

    let kind: Kind

    /// Any child accessibility elements become hidden.
    public static let ignore = AccessibilityChildBehavior(kind: .ignore)

    /// Any child accessibility elements become children of the new element.
    public static let contain = AccessibilityChildBehavior(kind: .contain)

    /// Combine any child accessibility element's properties for the new element.
    public static let combine = AccessibilityChildBehavior(kind: .combine)
}

/// The structure that defines the kinds of available accessibility actions.
public struct AccessibilityActionKind: Hashable, Sendable {

    let name: String

    /// The value that represents the default accessibility action.
    public static let `default` = AccessibilityActionKind(name: "default")

    /// The value that represents an action that cancels a pending accessibility action.
    public static let escape = AccessibilityActionKind(name: "escape")

    /// A named action.
    public init(named name: Text) {
        self.name = name.plainString
    }

    init(name: String) {
        self.name = name
    }
}

/// What a node tells assistive technologies.
internal struct AccessibilityAttributes {

    var label: String?

    var hint: String?

    var value: String?

    var addedTraits: AccessibilityTraits = []

    var removedTraits: AccessibilityTraits = []

    var isHidden: Bool?

    var children: AccessibilityChildBehavior?

    var actions: [(kind: AccessibilityActionKind, action: () -> Void)] = []

    var sortPriority: Double?

    /// These attributes with `inner`'s set over them.
    func merging(_ inner: AccessibilityAttributes) -> AccessibilityAttributes {
        var result = self
        result.label = inner.label ?? label
        result.hint = inner.hint ?? hint
        result.value = inner.value ?? value
        result.addedTraits.formUnion(inner.addedTraits)
        result.removedTraits.formUnion(inner.removedTraits)
        result.isHidden = inner.isHidden ?? isHidden
        result.children = inner.children ?? children
        result.actions += inner.actions
        result.sortPriority = inner.sortPriority ?? sortPriority
        return result
    }
}

extension View {

    /// Adds a label to the view that describes its contents.
    public func accessibilityLabel(_ label: Text) -> some View {
        accessibility { $0.label = label.plainString }
    }

    /// Adds a label to the view that describes its contents.
    public func accessibilityLabel<S: StringProtocol>(_ label: S) -> some View {
        accessibility { $0.label = String(label) }
    }

    /// Communicates to the user what happens after performing the view's action.
    public func accessibilityHint(_ hint: Text) -> some View {
        accessibility { $0.hint = hint.plainString }
    }

    /// Communicates to the user what happens after performing the view's action.
    public func accessibilityHint<S: StringProtocol>(_ hint: S) -> some View {
        accessibility { $0.hint = String(hint) }
    }

    /// Adds a textual description of the value that the view contains.
    public func accessibilityValue(_ value: Text) -> some View {
        accessibility { $0.value = value.plainString }
    }

    /// Adds a textual description of the value that the view contains.
    public func accessibilityValue<S: StringProtocol>(_ value: S) -> some View {
        accessibility { $0.value = String(value) }
    }

    /// Adds the given traits to the view.
    public func accessibilityAddTraits(_ traits: AccessibilityTraits) -> some View {
        accessibility { $0.addedTraits.formUnion(traits) }
    }

    /// Removes the given traits from this view.
    public func accessibilityRemoveTraits(_ traits: AccessibilityTraits) -> some View {
        accessibility { $0.removedTraits.formUnion(traits) }
    }

    /// Specifies whether to hide this view from system accessibility features.
    public func accessibilityHidden(_ hidden: Bool) -> some View {
        accessibility { $0.isHidden = hidden }
    }

    /// Creates a new accessibility element, or modifies the accessibility
    /// element of an existing view.
    public func accessibilityElement(children: AccessibilityChildBehavior = .ignore) -> some View {
        accessibility { $0.children = children }
    }

    /// Adds an accessibility action to the view.
    public func accessibilityAction(_ actionKind: AccessibilityActionKind = .default, _ handler: @escaping () -> Void) -> some View {
        accessibility { $0.actions.append((actionKind, handler)) }
    }

    /// Adds an accessibility action to the view.
    public func accessibilityAction(named name: Text, _ handler: @escaping () -> Void) -> some View {
        accessibilityAction(AccessibilityActionKind(named: name), handler)
    }

    /// Sets the sort priority order for this view's accessibility element,
    /// relative to other elements at the same level.
    public func accessibilitySortPriority(_ sortPriority: Double) -> some View {
        accessibility { $0.sortPriority = sortPriority }
    }

    private func accessibility(_ update: @escaping (inout AccessibilityAttributes) -> Void) -> some View {
        modifier(_AttributesModifier { attributes in
            var accessibility = attributes.accessibility ?? AccessibilityAttributes()
            update(&accessibility)
            attributes.accessibility = accessibility
        })
    }
}

extension Text {

    /// The text's string, without styling.
    var plainString: String {
        runs.map(\.string).joined()
    }
}

// MARK: - Tree

/// An element of the accessibility tree, as assistive technologies see it.
package struct AccessibilityElement: Equatable, Sendable {

    /// What the element is.
    package enum Role: Equatable, Sendable {
        case group
        case staticText
        case button
        case image
        case textField
        case toggle
        case slider
    }

    package var role: Role

    package var label: String

    package var value: String?

    package var hint: String?

    package var traits: AccessibilityTraits

    /// The element's frame in the window.
    package var frame: CGRect

    package var children: [AccessibilityElement]

    /// The names of the actions it supports.
    package var actions: [String]

    package static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.role == rhs.role && lhs.label == rhs.label && lhs.value == rhs.value && lhs.hint == rhs.hint
            && lhs.traits == rhs.traits && lhs.frame == rhs.frame && lhs.children == rhs.children && lhs.actions == rhs.actions
    }
}

extension ViewGraph {

    /// The window's accessibility elements: what shows, with labels from
    /// text and accessibility modifiers, for an accessibility bridge.
    package func accessibilityTree() -> AccessibilityElement {
        AccessibilityElement(
            role: .group,
            label: "",
            traits: [],
            frame: CGRect(origin: CGPoint(x: 0, y: 0), size: size),
            children: root.accessibilityElements(inherited: AccessibilityAttributes()),
            actions: []
        )
    }

    /// Performs an element's action, by the frame and name the tree gave.
    @discardableResult
    package func performAccessibilityAction(_ name: String, at frame: CGRect) -> Bool {
        var target: ViewNode?
        root.forEachDisplayedNode { node in
            guard target == nil, node.windowFrame == frame,
                  node.attributes.accessibility != nil || node.attributes.tap != nil else { return }
            target = node
        }
        guard let node = target else { return false }
        if let action = node.attributes.accessibility?.actions.first(where: { $0.kind.name == name })?.action {
            action()
            return true
        }
        if name == AccessibilityActionKind.default.name, let tap = node.firstNode(where: { $0.attributes.tap != nil })?.attributes.tap {
            tap.action()
            return true
        }
        return false
    }
}

extension ViewNode {

    /// The accessibility elements of this subtree.
    func accessibilityElements(inherited: AccessibilityAttributes) -> [AccessibilityElement] {
        guard attributes.allowsHitTesting || attributes.accessibility != nil else { return [] }
        var attributes = inherited
        if let own = self.attributes.accessibility {
            attributes = attributes.merging(own)
        }
        if attributes.isHidden == true {
            return []
        }
        let isElement = attributes.children != nil || self.attributes.tap != nil || self.attributes.focus != nil
            || behavior?.displayContent(node: self) != nil
        if isElement || behavior != nil {
            // Attributes apply to the first element below the modifier.
            var children: [AccessibilityElement] = []
            if attributes.children != .ignore || !isElement {
                for child in orderedChildren {
                    children += child.accessibilityElements(inherited: isElement ? AccessibilityAttributes() : attributes)
                }
            }
            guard isElement else {
                return children
            }
            return [element(attributes: attributes, children: children)]
        }
        return orderedChildren.flatMap { $0.accessibilityElements(inherited: attributes) }
    }

    private func element(attributes: AccessibilityAttributes, children: [AccessibilityElement]) -> AccessibilityElement {
        var role: AccessibilityElement.Role = .group
        var label = attributes.label
        if self.attributes.tap != nil || self.attributes.drag != nil {
            role = self.attributes.drag != nil ? .slider : .button
        } else if self.attributes.focus?.acceptsText == true {
            role = .textField
        } else if case let .text(text)? = behavior?.displayContent(node: self) {
            role = .staticText
            label = label ?? text.string
        } else if case .image? = behavior?.displayContent(node: self) {
            role = .image
        }
        var traits = attributes.addedTraits
        switch role {
        case .button: traits.insert(.isButton)
        case .staticText: traits.insert(.isStaticText)
        case .image: traits.insert(.isImage)
        default: break
        }
        traits.subtract(attributes.removedTraits)
        // A button or combined element reads its contents' labels.
        var children = children
        if label == nil, role == .button || attributes.children == .combine {
            label = children.map(\.label).filter { !$0.isEmpty }.joined(separator: ", ")
            children = []
        }
        var actions = attributes.actions.map(\.kind.name)
        if role == .button, !actions.contains(AccessibilityActionKind.default.name) {
            actions.insert(AccessibilityActionKind.default.name, at: 0)
        }
        return AccessibilityElement(
            role: role,
            label: label ?? "",
            value: attributes.value,
            hint: attributes.hint,
            traits: traits,
            frame: windowFrame,
            children: children,
            actions: actions
        )
    }
}

// MARK: - Windows

/// An action that presents a window.
public struct OpenWindowAction: Sendable {

    let handler: @MainActor @Sendable (_ id: String?, _ value: AnyHashable?) -> Void

    package init(handler: @escaping @MainActor @Sendable (_ id: String?, _ value: AnyHashable?) -> Void) {
        self.handler = handler
    }

    /// Opens a window that's associated with the specified identifier.
    @MainActor
    public func callAsFunction(id: String) {
        handler(id, nil)
    }

    /// Opens a window defined by a window group that presents the type of
    /// the specified value.
    @MainActor
    public func callAsFunction<D: Hashable & Codable>(value: D) {
        handler(nil, AnyHashable(value))
    }

    /// Opens a window defined by the window group that presents the
    /// specified value type and that's associated with the specified identifier.
    @MainActor
    public func callAsFunction<D: Hashable & Codable>(id: String, value: D) {
        handler(id, AnyHashable(value))
    }
}

/// An action that dismisses a window associated to a particular scene.
public struct DismissWindowAction: Sendable {

    let handler: @MainActor @Sendable (_ id: String?) -> Void

    package init(handler: @escaping @MainActor @Sendable (_ id: String?) -> Void) {
        self.handler = handler
    }

    /// Dismisses the current window.
    @MainActor
    public func callAsFunction() {
        handler(nil)
    }

    /// Dismisses the window that's associated with the specified identifier.
    @MainActor
    public func callAsFunction(id: String) {
        handler(id)
    }
}

private struct OpenWindowKey: EnvironmentKey {
    static let defaultValue = OpenWindowAction { _, _ in }
}

private struct DismissWindowKey: EnvironmentKey {
    static let defaultValue = DismissWindowAction { _ in }
}

extension EnvironmentValues {

    /// A window presentation action stored in a view's environment.
    public var openWindow: OpenWindowAction {
        get { self[OpenWindowKey.self] }
        set { self[OpenWindowKey.self] = newValue }
    }

    /// A window dismissal action stored in a view's environment.
    public var dismissWindow: DismissWindowAction {
        get { self[DismissWindowKey.self] }
        set { self[DismissWindowKey.self] = newValue }
    }
}
