//
//  ViewBuilder.swift
//  Cacao
//
//  Created by Alsey Coleman Miller on 11/13/26.
//

/// A custom parameter attribute that constructs views from closures.
@MainActor
@preconcurrency
@resultBuilder
public struct ViewBuilder {

    /// Builds an expression within the builder.
    public static func buildExpression<Content: View>(_ content: Content) -> Content {
        content
    }

    /// Builds an empty view from a block containing no statements.
    public static func buildBlock() -> EmptyView {
        EmptyView()
    }

    /// Passes a single view written as a child view through unmodified.
    public static func buildBlock<Content: View>(_ content: Content) -> Content {
        content
    }

    /// Combines multiple views into a single tuple view.
    public static func buildBlock<each Content: View>(
        _ content: repeat each Content
    ) -> TupleView<(repeat each Content)> {
        var children: [any View] = []
        for view in repeat each content {
            children.append(view)
        }
        return TupleView((repeat each content), children: children)
    }

    /// Produces an optional view for conditional statements in multi-statement
    /// closures that's only visible when the condition evaluates to `true`.
    public static func buildIf<Content: View>(_ content: Content?) -> Content? {
        content
    }

    /// Produces content for a conditional statement when the condition is true.
    public static func buildEither<TrueContent: View, FalseContent: View>(
        first: TrueContent
    ) -> _ConditionalContent<TrueContent, FalseContent> {
        _ConditionalContent(storage: .trueContent(first))
    }

    /// Produces content for a conditional statement when the condition is false.
    public static func buildEither<TrueContent: View, FalseContent: View>(
        second: FalseContent
    ) -> _ConditionalContent<TrueContent, FalseContent> {
        _ConditionalContent(storage: .falseContent(second))
    }

    /// Processes view content for a conditional compiler-control statement
    /// that performs an availability check.
    public static func buildLimitedAvailability<Content: View>(_ content: Content) -> AnyView {
        AnyView(content)
    }
}
