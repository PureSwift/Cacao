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
            let resolution = primitive.resolve(content: content, in: context)
            // A modifier that lays out or draws applies to each of several
            // views, as in SwiftUI, rather than to all of them as one.
            if resolution.behavior != nil, let views = ContentViews(content), views.items.count != 1 {
                return Resolution(children: views.items.map { item in
                    ChildView(key: item.id, view: applying(to: item.view))
                })
            }
            return resolution
        }
        // A custom modifier: like a composite view, its dynamic properties
        // live in this node and its body is this node's only child.
        // An animatable modifier evaluates partway through its animation.
        let modifier = context.animatedValue(self.modifier)
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

// MARK: - Views of content

/// The views that content is made of, from its structure: tuples, groups,
/// conditionals, `ForEach` and a modifier's content are flattened.
@MainActor
internal struct ContentViews {

    private(set) var items: [(id: AnyHashable, view: any View)] = []

    /// The views of `content`, or `nil` if it's a single view by its type.
    init?(_ content: any View) {
        guard Self.isStructural(content) else {
            return nil
        }
        append(content, path: "")
    }

    private static func isStructural(_ view: any View) -> Bool {
        if let modified = view as? any _ModifiedViews {
            return modified.isPrimitive && isStructural(modified.modifiedContent)
        }
        return view is any _TupleContent || view is any _StructuralWrapper || view is any LazyRowSource
            || view is any _ModifierContentProtocol || view is EmptyView
    }

    /// Adds the views of `view`, each wrapped by `wrap`: the modifiers
    /// applied over the structure the view was found in.
    private mutating func append(_ view: any View, path: String, wrap: (any View) -> any View = { $0 }) {
        switch view {
        case is EmptyView:
            break
        case let modified as any _ModifiedViews where modified.isPrimitive:
            if Self.isStructural(modified.modifiedContent) {
                append(modified.modifiedContent, path: path) { wrap(modified.applying(to: $0)) }
            } else {
                items.append((AnyHashable(path), wrap(view)))
            }
        case let tuple as any _TupleContent:
            for (index, child) in tuple.tupleChildren.enumerated() {
                append(child, path: path + "/\(index)", wrap: wrap)
            }
        case let content as any _ModifierContentProtocol:
            append(content.wrappedView, path: path, wrap: wrap)
        case let wrapper as any _StructuralWrapper:
            if let inner = wrapper.wrappedContent {
                append(inner, path: path + "/" + wrapper.structuralKey, wrap: wrap)
            }
        case let source as any LazyRowSource:
            for index in 0..<source.rowCount {
                let row = source.row(at: index)
                append(row.view, path: path + "/#\(row.id)", wrap: wrap)
            }
        default:
            items.append((AnyHashable(path), wrap(view)))
        }
    }
}

/// Content with a modifier, which flattening applies to each of the
/// content's views when the modifier is a built-in one.
@MainActor
internal protocol _ModifiedViews {
    var modifiedContent: any View { get }
    var isPrimitive: Bool { get }
    func applying(to view: any View) -> any View
}

extension ModifiedContent: _ModifiedViews where Content: View, Modifier: ViewModifier {

    var modifiedContent: any View { content }

    var isPrimitive: Bool { modifier is any PrimitiveViewModifier }

    func applying(to view: any View) -> any View {
        ModifiedContent<AnyView, Modifier>(content: AnyView(_fromValue: view)!, modifier: modifier)
    }
}

/// A modifier's content, which is flattened through to the views it holds.
@MainActor
internal protocol _ModifierContentProtocol {
    var wrappedView: any View { get }
}

extension _ViewModifier_Content: _ModifierContentProtocol {
    var wrappedView: any View { content }
}

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
