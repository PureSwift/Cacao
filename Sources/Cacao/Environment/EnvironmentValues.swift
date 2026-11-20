//
//  EnvironmentValues.swift
//  Cacao
//
//  Created by Alsey Coleman Miller on 11/13/26.
//

import CacaoRender

/// A key for accessing values in the environment.
public protocol EnvironmentKey {

    /// The associated type representing the type of the environment key's value.
    associatedtype Value

    /// The default value for the environment key.
    static var defaultValue: Value { get }
}

/// A collection of environment values propagated through a view hierarchy.
public struct EnvironmentValues: CustomStringConvertible {

    internal var storage: [ObjectIdentifier: Any]

    internal var objects: [ObjectIdentifier: AnyObject]

    /// Creates an environment values instance.
    public init() {
        self.storage = [:]
        self.objects = [:]
    }

    /// Accesses the environment value associated with a custom key.
    public subscript<K: EnvironmentKey>(key: K.Type) -> K.Value {
        get {
            if let value = storage[ObjectIdentifier(key)] {
                return value as! K.Value
            }
            return K.defaultValue
        }
        set {
            storage[ObjectIdentifier(key)] = newValue
        }
    }

    /// The observable object of the given type, set with `environment(_:)`.
    internal func object<T: AnyObject>(of type: T.Type) -> T? {
        objects[ObjectIdentifier(type)] as? T
    }

    internal mutating func setObject<T: AnyObject>(_ object: T?, of type: T.Type) {
        objects[ObjectIdentifier(type)] = object
    }

    public var description: String {
        "EnvironmentValues(\(storage.count) values, \(objects.count) objects)"
    }
}
