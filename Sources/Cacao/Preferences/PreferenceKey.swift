//
//  PreferenceKey.swift
//  Cacao
//
//  Created by Alsey Coleman Miller on 11/13/26.
//

/// A named value produced by a view.
///
/// A view's preference value is the one set on it, or else the values of
/// its children combined with `reduce(value:nextValue:)` in order.
public protocol PreferenceKey {

    /// The type of value produced by this preference.
    associatedtype Value

    /// The default value of the preference.
    static var defaultValue: Self.Value { get }

    /// Combines a sequence of values by modifying the previously-accumulated
    /// value with the result of a closure that provides the next value.
    static func reduce(value: inout Self.Value, nextValue: () -> Self.Value)
}

/// A preference key's identity and how to read its value from nodes.
@MainActor
internal struct PreferenceKeyInfo {

    let id: ObjectIdentifier

    /// The combined value of a list of sibling nodes, or the default value.
    let value: ([ViewNode]) -> Any

    init<K: PreferenceKey>(_ key: K.Type) {
        self.id = ObjectIdentifier(key)
        self.value = { nodes in
            Self.combinedValue(K.self, of: nodes) ?? K.defaultValue
        }
    }

    /// The value of `K` for `nodes`, or `nil` if none of them sets it.
    private static func combinedValue<K: PreferenceKey>(_ key: K.Type, of nodes: [ViewNode]) -> K.Value? {
        var result: K.Value?
        for node in nodes {
            guard let next = value(key, of: node) else { continue }
            if result == nil {
                result = next
            } else {
                K.reduce(value: &result!, nextValue: { next })
            }
        }
        return result
    }

    private static func value<K: PreferenceKey>(_ key: K.Type, of node: ViewNode) -> K.Value? {
        let id = ObjectIdentifier(key)
        if let preference = node.attributes.preference, preference.keyID == id {
            return preference.value as? K.Value
        }
        var value = combinedValue(key, of: node.children)
        if let transform = node.attributes.preferenceTransform, transform.keyID == id {
            var transformed: Any = value ?? K.defaultValue
            transform.apply(&transformed)
            value = transformed as? K.Value
        }
        return value
    }
}

/// A preference value set by a node.
internal struct PreferenceValue {

    let keyID: ObjectIdentifier

    let value: Any
}

/// A transformation of a preference value from a node's subtree.
internal struct PreferenceTransform {

    let keyID: ObjectIdentifier

    let apply: (inout Any) -> Void
}

/// An action called with a preference's value from a node's subtree.
internal struct PreferenceObserver {

    let key: PreferenceKeyInfo

    let isEqual: (Any, Any) -> Bool

    let action: (Any) -> Void
}

// MARK: - Modifiers

internal struct _PreferenceWritingModifier<Key: PreferenceKey>: ViewModifier, PrimitiveViewModifier {

    let value: Key.Value

    func resolve(content: any View, in context: ResolveContext) -> Resolution {
        var attributes = NodeAttributes()
        attributes.preference = PreferenceValue(keyID: ObjectIdentifier(Key.self), value: value)
        return Resolution(children: [ChildView(key: 0, view: content)], attributes: attributes)
    }

    typealias Body = Never
}

internal struct _PreferenceTransformModifier<Key: PreferenceKey>: ViewModifier, PrimitiveViewModifier {

    let transform: (inout Key.Value) -> Void

    func resolve(content: any View, in context: ResolveContext) -> Resolution {
        var attributes = NodeAttributes()
        let transform = self.transform
        attributes.preferenceTransform = PreferenceTransform(keyID: ObjectIdentifier(Key.self)) { value in
            var typed = value as! Key.Value
            transform(&typed)
            value = typed
        }
        return Resolution(children: [ChildView(key: 0, view: content)], attributes: attributes)
    }

    typealias Body = Never
}

internal struct _PreferenceActionModifier<Key: PreferenceKey>: ViewModifier, PrimitiveViewModifier
where Key.Value: Equatable {

    let action: (Key.Value) -> Void

    func resolve(content: any View, in context: ResolveContext) -> Resolution {
        var attributes = NodeAttributes()
        let action = self.action
        attributes.preferenceObserver = PreferenceObserver(
            key: PreferenceKeyInfo(Key.self),
            isEqual: { ($0 as? Key.Value) == ($1 as? Key.Value) },
            action: { action($0 as! Key.Value) }
        )
        return Resolution(children: [ChildView(key: 0, view: content)], attributes: attributes)
    }

    typealias Body = Never
}

extension View {

    /// Sets a value for the given preference.
    public func preference<K: PreferenceKey>(key: K.Type = K.self, value: K.Value) -> some View {
        modifier(_PreferenceWritingModifier<K>(value: value))
    }

    /// Applies a transformation to a preference value.
    public func transformPreference<K: PreferenceKey>(
        _ key: K.Type = K.self,
        _ callback: @escaping (inout K.Value) -> Void
    ) -> some View {
        modifier(_PreferenceTransformModifier<K>(transform: callback))
    }

    /// Adds an action to perform when the specified preference key's value changes.
    public func onPreferenceChange<K: PreferenceKey>(
        _ key: K.Type = K.self,
        perform action: @escaping (K.Value) -> Void
    ) -> some View where K.Value: Equatable {
        modifier(_PreferenceActionModifier<K>(action: action))
    }
}
