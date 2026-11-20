//
//  PreviewMacro.swift
//  CacaoMacros
//
//  Created by Alsey Coleman Miller on 11/20/26.
//

import SwiftSyntax
import SwiftSyntaxBuilder
import SwiftSyntaxMacros

/// `#Preview { ... }`: in a debug build, a type that registers the preview
/// for Cacao to find and draw; nothing in a release build.
public struct PreviewMacro: DeclarationMacro {

    public static func expansion(
        of node: some FreestandingMacroExpansionSyntax,
        in context: some MacroExpansionContext
    ) throws -> [DeclSyntax] {
        // The view builder: the trailing closure, or the last argument.
        guard let closure = node.trailingClosure
            ?? node.arguments.last?.expression.as(ClosureExprSyntax.self) else {
            return []
        }
        let name: ExprSyntax
        if let first = node.arguments.first, first.label == nil, !first.expression.is(ClosureExprSyntax.self) {
            name = first.expression.trimmed
        } else {
            name = "nil"
        }
        let location = context.location(of: node)
        let file: ExprSyntax = location?.file ?? "\"\""
        let line: ExprSyntax = location?.line ?? "0"
        let type = context.makeUniqueName("_CacaoPreview")
        return [
            """
            #if DEBUG
            struct \(type): _PreviewRegistration {
                static var name: String? { \(name) }
                static var fileID: String { \(file) }
                static var line: Int { \(line) }
                @MainActor @ViewBuilder static var content: some View \(closure.statements.isEmpty ? "{ EmptyView() }" : "{\(closure.statements)}")
                @MainActor static func makeView() -> AnyView { AnyView(content) }
            }
            #endif
            """
        ]
    }
}
