//
//  Environment.swift
//  Cacao
//
//  Created by Alsey Coleman Miller on 11/13/26.
//

import CacaoRender
import Observation

/// A property wrapper that reads a value from a view's environment.
@propertyWrapper
public struct Environment<Value>: DynamicProperty {

    internal enum Content {
        case keyPath(KeyPath<EnvironmentValues, Value>)
        case object((EnvironmentValues) -> Value)
    }

    internal let content: Content

    internal let box: EnvironmentBox

    /// Creates an environment property to read the specified key path.
    public init(_ keyPath: KeyPath<EnvironmentValues, Value>) {
        self.content = .keyPath(keyPath)
        self.box = EnvironmentBox()
    }

    /// The current value of the environment property.
    public var wrappedValue: Value {
        let values = box.values ?? EnvironmentValues()
        switch content {
        case let .keyPath(keyPath):
            return values[keyPath: keyPath]
        case let .object(read):
            return read(values)
        }
    }
}

extension Environment where Value: AnyObject & Observable {

    /// Creates an environment property to read an observable object, set
    /// with `environment(_:)` on an ancestor view.
    public init(_ objectType: Value.Type) {
        self.content = .object { values in
            guard let object = values.object(of: objectType) else {
                fatalError("No Observable object of type \(objectType) found. A View.environment(_:) for \(objectType) may be missing as an ancestor of this view.")
            }
            return object
        }
        self.box = EnvironmentBox()
    }
}

extension Environment {

    /// Creates an environment property to read an observable object, or
    /// `nil` if no ancestor set one.
    public init<T: AnyObject & Observable>(_ objectType: T.Type) where Value == T? {
        self.content = .object { $0.object(of: objectType) }
        self.box = EnvironmentBox()
    }
}

extension Environment: DynamicPropertyInstaller {

    func install(in node: ViewNode, label: String) {
        box.values = node.environment
    }
}

/// The environment of the node evaluating a view, read by `@Environment`.
internal final class EnvironmentBox: @unchecked Sendable {

    var values: EnvironmentValues?
}

// MARK: - Modifiers

extension View {

    /// Sets the environment value of the specified key path to the given value.
    public func environment<V>(
        _ keyPath: WritableKeyPath<EnvironmentValues, V>,
        _ value: V
    ) -> some View {
        modifier(_EnvironmentKeyWritingModifier(keyPath: keyPath, value: value))
    }

    /// Transforms the environment value of the specified key path with the
    /// given function.
    public func transformEnvironment<V>(
        _ keyPath: WritableKeyPath<EnvironmentValues, V>,
        transform: @escaping (inout V) -> Void
    ) -> some View {
        modifier(_EnvironmentKeyTransformModifier(keyPath: keyPath, transform: transform))
    }

    /// Places an observable object in the view's environment.
    public func environment<T: AnyObject & Observable>(_ object: T?) -> some View {
        modifier(_EnvironmentObjectWritingModifier(object: object))
    }
}

/// A modifier that sets a value for an environment keyPath.
public struct _EnvironmentKeyWritingModifier<Value>: ViewModifier, _EnvironmentModifier {

    public var keyPath: WritableKeyPath<EnvironmentValues, Value>

    public var value: Value

    public init(keyPath: WritableKeyPath<EnvironmentValues, Value>, value: Value) {
        self.keyPath = keyPath
        self.value = value
    }

    func modify(_ environment: inout EnvironmentValues) {
        environment[keyPath: keyPath] = value
    }

    public typealias Body = Never
}

/// A modifier that transforms the value for an environment keyPath.
public struct _EnvironmentKeyTransformModifier<Value>: ViewModifier, _EnvironmentModifier {

    public var keyPath: WritableKeyPath<EnvironmentValues, Value>

    public var transform: (inout Value) -> Void

    public init(keyPath: WritableKeyPath<EnvironmentValues, Value>, transform: @escaping (inout Value) -> Void) {
        self.keyPath = keyPath
        self.transform = transform
    }

    func modify(_ environment: inout EnvironmentValues) {
        transform(&environment[keyPath: keyPath])
    }

    public typealias Body = Never
}

/// A modifier that places an observable object in the environment.
internal struct _EnvironmentObjectWritingModifier<T: AnyObject & Observable>: ViewModifier, _EnvironmentModifier {

    let object: T?

    func modify(_ environment: inout EnvironmentValues) {
        environment.setObject(object, of: T.self)
    }

    typealias Body = Never
}

/// A built-in modifier that only changes the environment of its content.
@MainActor
internal protocol _EnvironmentModifier: PrimitiveViewModifier {

    func modify(_ environment: inout EnvironmentValues)
}

extension _EnvironmentModifier {

    func resolve(content: any View, in context: ResolveContext) -> Resolution {
        var environment = context.environment
        modify(&environment)
        return Resolution(children: [ChildView(key: 0, view: content, environment: environment)])
    }
}
