//
//  State.swift
//  Cacao
//
//  Created by Alsey Coleman Miller on 11/13/26.
//

import CacaoRender
import Foundation
#if canImport(CoreGraphics)
import CoreGraphics
#endif

/// A property wrapper type that can read and write a value managed by Cacao.
///
/// The value lives in the view's node, so it persists across updates for as
/// long as the view keeps its identity. Writing it updates the views that
/// depend on it.
@propertyWrapper
public struct State<Value>: DynamicProperty {

    internal let box: StateBox<Value>

    /// Creates a state property that stores an initial value.
    public init(wrappedValue value: Value) {
        self.box = StateBox(value)
    }

    /// Creates a state property that stores an initial value.
    public init(initialValue value: Value) {
        self.init(wrappedValue: value)
    }

    /// The underlying value referenced by the state variable.
    public var wrappedValue: Value {
        get { box.value }
        nonmutating set { box.value = newValue }
    }

    /// A binding to the state value.
    public var projectedValue: Binding<Value> {
        let box = self.box
        return Binding(get: { box.value }, set: { box.value = $0 })
    }
}

extension State where Value: ExpressibleByNilLiteral {

    /// Creates a state property without an initial value.
    public init() {
        self.init(wrappedValue: nil)
    }
}

extension State: @unchecked Sendable where Value: Sendable { }

extension State: DynamicPropertyInstaller {

    func install(in node: ViewNode, label: String) {
        box.install(in: node, label: label)
    }
}

// MARK: - StateBox

/// Storage for a state value.
///
/// Each view value creates a fresh box. The first box seen at a node and
/// label is kept by the node; later boxes forward to it, so the view value
/// evaluating `body` reads and writes the persisted value.
internal final class StateBox<Value>: @unchecked Sendable {

    private var storedValue: Value

    private var target: StateBox<Value>?

    private weak var node: ViewNode?

    private weak var queue: InvalidationQueue?

    init(_ value: Value) {
        self.storedValue = value
    }

    var value: Value {
        get {
            target?.value ?? storedValue
        }
        set {
            if let target {
                target.value = newValue
            } else {
                storedValue = newValue
                queue?.enqueue(node, transaction: Transaction.current)
            }
        }
    }

    @MainActor
    func install(in node: ViewNode, label: String) {
        if let persisted = node.dynamicStorage[label] as? StateBox<Value> {
            if persisted !== self {
                target = persisted
            }
        } else {
            self.node = node
            self.queue = node.graph.invalidations
            node.dynamicStorage[label] = self
        }
    }
}

/// Carries a non-`Sendable` value across an isolation boundary that is known
/// to be safe, such as hopping to the main actor.
internal struct UncheckedSendable<Value>: @unchecked Sendable {

    let value: Value

    init(_ value: Value) {
        self.value = value
    }
}
