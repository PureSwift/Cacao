//
//  View.swift
//  Cacao
//
//  Created by Alsey Coleman Miller on 11/13/26.
//

import Foundation
#if canImport(CoreGraphics)
import CoreGraphics
#endif

// MARK: - View

/// A type that represents part of your app's user interface and provides
/// modifiers that you use to configure views.
@MainActor
@preconcurrency
public protocol View {

    /// The type of view representing the body of this view.
    associatedtype Body: View

    /// The content and behavior of the view.
    @ViewBuilder
    var body: Self.Body { get }
}

extension Never: View {

    public typealias Body = Never

    public var body: Never {
        fatalError("Never has no body")
    }
}

extension View where Body == Never {

    /// Primitive views have no body; Cacao resolves them directly.
    public var body: Never {
        fatalError("\(Self.self) is a primitive view and has no body")
    }
}

// MARK: - PrimitiveView

/// A view that Cacao resolves directly instead of through its body.
@MainActor
internal protocol PrimitiveView {

    /// Describes the node for this view: its behavior and its child views.
    func resolve(in context: ResolveContext) -> Resolution
}

// MARK: - EmptyView

/// A view that doesn't contain any content.
public struct EmptyView: View {

    public init() { }

    public typealias Body = Never
}

extension EmptyView: PrimitiveView {

    func resolve(in context: ResolveContext) -> Resolution {
        Resolution()
    }
}

// MARK: - AnyView

/// A type-erased view.
///
/// Changing the type of the wrapped view replaces its subtree, resetting
/// its state, as in SwiftUI.
public struct AnyView: View {

    internal let view: any View

    /// Create an instance that type-erases `view`.
    public init<V: View>(_ view: V) {
        if let view = view as? AnyView {
            self.view = view.view
        } else {
            self.view = view
        }
    }

    /// Creates a type-erased view from a value of any type, or `nil` if it
    /// isn't a view.
    public init?(_fromValue value: Any) {
        guard let view = value as? any View else {
            return nil
        }
        self.view = view
    }

    public init<V: View>(erasing view: V) {
        self.init(view)
    }

    public typealias Body = Never
}

extension AnyView: PrimitiveView {

    func resolve(in context: ResolveContext) -> Resolution {
        Resolution(children: [ChildView(key: ObjectIdentifier(type(of: view)), view: view)])
    }
}

// MARK: - TupleView

/// A view created from a swift tuple of view values.
public struct TupleView<T>: View {

    public var value: T

    internal let children: [any View]

    public init(_ value: T) {
        self.value = value
        self.children = Mirror(reflecting: value).children.compactMap { $0.value as? any View }
    }

    internal init(_ value: T, children: [any View]) {
        self.value = value
        self.children = children
    }

    public typealias Body = Never
}

extension TupleView: PrimitiveView {

    func resolve(in context: ResolveContext) -> Resolution {
        Resolution(children: children.enumerated().map { ChildView(key: $0.offset, view: $0.element) })
    }
}

// MARK: - _ConditionalContent

/// View content that shows one of two possible children.
public struct _ConditionalContent<TrueContent, FalseContent>: View
where TrueContent: View, FalseContent: View {

    @usableFromInline
    internal enum Storage {
        case trueContent(TrueContent)
        case falseContent(FalseContent)
    }

    @usableFromInline
    internal let storage: Storage

    @usableFromInline
    internal init(storage: Storage) {
        self.storage = storage
    }

    public typealias Body = Never
}

extension _ConditionalContent: PrimitiveView {

    func resolve(in context: ResolveContext) -> Resolution {
        switch storage {
        case let .trueContent(view):
            Resolution(children: [ChildView(key: true, view: view)])
        case let .falseContent(view):
            Resolution(children: [ChildView(key: false, view: view)])
        }
    }
}

// MARK: - Optional

extension Optional: View where Wrapped: View {

    public typealias Body = Never
}

extension Optional: PrimitiveView where Wrapped: View {

    func resolve(in context: ResolveContext) -> Resolution {
        switch self {
        case let .some(view):
            Resolution(children: [ChildView(key: "some", view: view)])
        case .none:
            Resolution()
        }
    }
}

// MARK: - Group

/// A type that collects multiple instances of a content type into a single unit.
public struct Group<Content> {

    @usableFromInline
    internal var content: Content
}

extension Group: View where Content: View {

    public typealias Body = Never

    /// Creates a group of views.
    public init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }
}

extension Group: PrimitiveView where Content: View {

    func resolve(in context: ResolveContext) -> Resolution {
        Resolution(children: [ChildView(key: 0, view: content)])
    }
}
