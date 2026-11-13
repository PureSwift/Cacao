//
//  Cacao.swift
//  Cacao
//
//  Created by Alsey Coleman Miller on 11/13/26.
//

/// The SwiftUI API, implemented in Swift, for Linux and macOS.
///
/// This module holds the platform-neutral part of Cacao: views, state,
/// environment, layout and the display list. It has no windowing or GPU
/// dependencies, so it builds and tests headless on any host. Windows, input
/// and rendering come from `CacaoSDL`.
public enum Cacao {

    /// The version of the SwiftUI API surface Cacao implements.
    public static let version = "0.1.0"
}
