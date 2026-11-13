//
//  ViewModifier.swift
//  Cacao
//
//  Created by Alsey Coleman Miller on 11/13/26.
//

/// A modifier that you apply to a view or another view modifier, producing
/// a different version of the original value.
@MainActor
@preconcurrency
public protocol ViewModifier {

    /// The type of view representing the body.
    associatedtype Body: View

    /// The content view type passed to `body()`.
    typealias Content = _ViewModifier_Content<Self>

    /// Gets the current body of the caller.
    @ViewBuilder
    func body(content: Self.Content) -> Self.Body
}

extension ViewModifier where Body == Never {

    public func body(content: Self.Content) -> Never {
        fatalError("\(Self.self) is a primitive modifier and has no body")
    }
}

/// A built-in modifier that Cacao resolves directly.
@MainActor
internal protocol PrimitiveViewModifier {

    func resolve(content: any View, in context: ResolveContext) -> Resolution
}

/// The content view passed to a view modifier's `body(content:)`.
public struct _ViewModifier_Content<Modifier: ViewModifier>: View {

    internal let content: any View

    internal init(content: any View) {
        self.content = content
    }

    public typealias Body = Never
}

extension _ViewModifier_Content: PrimitiveView {

    func resolve(in context: ResolveContext) -> Resolution {
        Resolution(children: [ChildView(key: 0, view: content)])
    }
}

// MARK: - ModifiedContent

/// A value with a modifier applied to it.
public struct ModifiedContent<Content, Modifier> {

    /// The content that the modifier transforms into a new view or new
    /// view modifier.
    public var content: Content

    /// The view modifier.
    public var modifier: Modifier

    /// A structure that the defines the content and modifier needed to
    /// produce a new view or view modifier.
    public init(content: Content, modifier: Modifier) {
        self.content = content
        self.modifier = modifier
    }
}

extension ModifiedContent: View where Content: View, Modifier: ViewModifier {

    public typealias Body = Never
}

extension ModifiedContent: PrimitiveView where Content: View, Modifier: ViewModifier {

    func resolve(in context: ResolveContext) -> Resolution {
        if let primitive = modifier as? any PrimitiveViewModifier {
            return primitive.resolve(content: content, in: context)
        }
        // A custom modifier: like a composite view, its dynamic properties
        // live in this node and its body is this node's only child.
        let body = context.evaluate {
            modifier.body(content: _ViewModifier_Content(content: content))
        } installing: {
            modifier
        }
        return Resolution(children: [ChildView(key: 0, view: body)])
    }
}

extension ModifiedContent: ViewModifier where Content: ViewModifier, Modifier: ViewModifier {

    public func body(content: _ViewModifier_Content<Self>) -> some View {
        content
            .modifier(self.content)
            .modifier(self.modifier)
    }
}

extension ModifiedContent: Equatable where Content: Equatable, Modifier: Equatable { }

// MARK: - EmptyModifier

/// An empty, or identity, modifier, used during development to switch
/// modifiers at compile time.
public struct EmptyModifier: ViewModifier {

    public static let identity = EmptyModifier()

    public init() { }

    public typealias Body = Never
}

extension EmptyModifier: PrimitiveViewModifier {

    func resolve(content: any View, in context: ResolveContext) -> Resolution {
        Resolution(children: [ChildView(key: 0, view: content)])
    }
}

// MARK: - View

extension View {

    /// Applies a modifier to a view and returns a new view.
    public func modifier<T>(_ modifier: T) -> ModifiedContent<Self, T> {
        ModifiedContent(content: self, modifier: modifier)
    }
}

extension ViewModifier {

    /// Returns a new modifier that is the result of concatenating
    /// `self` with `modifier`.
    public func concat<T>(_ modifier: T) -> ModifiedContent<Self, T> {
        ModifiedContent(content: self, modifier: modifier)
    }
}
