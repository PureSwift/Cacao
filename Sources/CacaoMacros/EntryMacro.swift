//
//  EntryMacro.swift
//  CacaoMacros
//
//  Created by Alsey Coleman Miller on 11/13/26.
//

import SwiftCompilerPlugin
import SwiftDiagnostics
import SwiftSyntax
import SwiftSyntaxMacros

/// `@Entry`: turns `var name: Type = default` in an extension of
/// `EnvironmentValues` into a computed property backed by a key, which it
/// declares beside the property.
public struct EntryMacro: AccessorMacro, PeerMacro {

    struct Message: DiagnosticMessage {
        let message: String
        var diagnosticID: MessageID { MessageID(domain: "CacaoMacros", id: "Entry") }
        var severity: DiagnosticSeverity { .error }
    }

    /// The property's name, type and default value.
    static func entry(of declaration: some DeclSyntaxProtocol, in context: some MacroExpansionContext) -> (name: String, type: TypeSyntax, value: ExprSyntax?)? {
        guard let variable = declaration.as(VariableDeclSyntax.self),
              variable.bindingSpecifier.tokenKind == .keyword(.var),
              let binding = variable.bindings.first,
              variable.bindings.count == 1,
              let identifier = binding.pattern.as(IdentifierPatternSyntax.self) else {
            context.diagnose(Diagnostic(node: Syntax(declaration), message: Message(message: "'@Entry' applies to a single 'var' declaration")))
            return nil
        }
        guard let type = binding.typeAnnotation?.type else {
            context.diagnose(Diagnostic(node: Syntax(binding), message: Message(message: "'@Entry' needs the property's type")))
            return nil
        }
        let value = binding.initializer?.value
        if value == nil, type.as(OptionalTypeSyntax.self) == nil, type.as(ImplicitlyUnwrappedOptionalTypeSyntax.self) == nil {
            context.diagnose(Diagnostic(node: Syntax(binding), message: Message(message: "'@Entry' needs a default value unless the type is optional")))
            return nil
        }
        return (identifier.identifier.trimmedDescription, type.trimmed, value?.trimmed)
    }

    public static func expansion(
        of node: AttributeSyntax,
        providingAccessorsOf declaration: some DeclSyntaxProtocol,
        in context: some MacroExpansionContext
    ) throws -> [AccessorDeclSyntax] {
        guard let entry = entry(of: declaration, in: context) else { return [] }
        let key = "__Key_\(entry.name)"
        return [
            "get { self[\(raw: key).self] }",
            "set { self[\(raw: key).self] = newValue }",
        ]
    }

    public static func expansion(
        of node: AttributeSyntax,
        providingPeersOf declaration: some DeclSyntaxProtocol,
        in context: some MacroExpansionContext
    ) throws -> [DeclSyntax] {
        guard let entry = entry(of: declaration, in: context) else { return [] }
        let value = entry.value ?? "nil"
        return [
            """
            private struct __Key_\(raw: entry.name): EnvironmentKey {
                static var defaultValue: \(entry.type) { \(value) }
            }
            """
        ]
    }
}

// A plugin executable has an entry point; a plugin library (CMake's build)
// is loaded by the compiler, which finds the macros by name.
#if !CACAO_MACROS_LIBRARY
@main
struct CacaoMacrosPlugin: CompilerPlugin {
    let providingMacros: [Macro.Type] = [EntryMacro.self]
}
#endif
