//
//  Binding.swift
//  Cacao
//
//  Created by Alsey Coleman Miller on 11/13/26.
//

import CacaoRender

/// A property wrapper type that can read and write a value owned by a source
/// of truth.
@propertyWrapper
@dynamicMemberLookup
public struct Binding<Value> {

    internal let getValue: () -> Value

    internal let setValue: (Value) -> Void

    /// Creates a binding with closures that read and write the binding value.
    public init(get: @escaping () -> Value, set: @escaping (Value) -> Void) {
        self.getValue = get
        self.setValue = set
    }

    /// Creates a binding from the value of another binding.
    public init(projectedValue: Binding<Value>) {
        self = projectedValue
    }

    /// Creates a binding with an immutable value.
    public static func constant(_ value: Value) -> Binding<Value> {
        Binding(get: { value }, set: { _ in })
    }

    /// The underlying value referenced by the binding variable.
    public var wrappedValue: Value {
        get { getValue() }
        nonmutating set { setValue(newValue) }
    }

    /// A projection of the binding value that returns a binding.
    public var projectedValue: Binding<Value> {
        self
    }

    /// Returns a binding to the resulting value of a given key path.
    public subscript<Subject>(
        dynamicMember keyPath: WritableKeyPath<Value, Subject>
    ) -> Binding<Subject> {
        let get = getValue
        let set = setValue
        return Binding<Subject>(
            get: { get()[keyPath: keyPath] },
            set: { newValue in
                var value = get()
                value[keyPath: keyPath] = newValue
                set(value)
            }
        )
    }
}

extension Binding {

    /// Creates a binding by projecting the base value to an optional value.
    public init<V>(_ base: Binding<V>) where Value == V? {
        self.init(
            get: { base.wrappedValue },
            set: { newValue in
                if let newValue {
                    base.wrappedValue = newValue
                }
            }
        )
    }

    /// Creates a binding by projecting the base value to an unwrapped value,
    /// or `nil` if the base value is currently `nil`.
    public init?(_ base: Binding<Value?>) {
        guard let value = base.wrappedValue else {
            return nil
        }
        var last = value
        self.init(
            get: {
                if let current = base.wrappedValue {
                    last = current
                }
                return last
            },
            set: { base.wrappedValue = $0 }
        )
    }

    /// Creates a binding by projecting the base value to a hashable value.
    public init<V: Hashable>(_ base: Binding<V>) where Value == AnyHashable {
        self.init(
            get: { AnyHashable(base.wrappedValue) },
            set: { newValue in
                if let value = newValue.base as? V {
                    base.wrappedValue = value
                }
            }
        )
    }
}

extension Binding: Identifiable where Value: Identifiable {

    public var id: Value.ID {
        wrappedValue.id
    }
}

extension Binding: DynamicProperty { }
