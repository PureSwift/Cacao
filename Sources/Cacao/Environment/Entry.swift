//
//  Entry.swift
//  Cacao
//
//  Created by Alsey Coleman Miller on 11/13/26.
//

import CacaoRender

/// Creates an environment values entry: in an extension of
/// `EnvironmentValues`, `@Entry var name: Type = default` declares a key
/// with the default value and a property that reads and writes it.
@attached(accessor)
@attached(peer, names: prefixed(__Key_))
public macro Entry() = #externalMacro(module: "CacaoMacros", type: "EntryMacro")
