//
//  Cacao.swift
//  Cacao
//
//  Created by Alsey Coleman Miller on 11/13/26.
//

// The parts of the SwiftUI API that are also what display lists are made of
// live in `CacaoRender`, and are Cacao's API too.
@_exported import struct CacaoRender.Path
@_exported import enum CacaoRender.RoundedCornerStyle
@_exported import struct CacaoRender.ProposedViewSize
@_exported import struct CacaoRender.FillStyle
@_exported import struct CacaoRender.StrokeStyle
@_exported import enum CacaoRender.BlendMode
@_exported import struct CacaoRender.ColorMatrix
@_exported import enum CacaoRender.TextAlignment
@_exported import enum CacaoRender.TruncationMode
@_exported import class CacaoRender.ExternalSurface
#if !canImport(CoreGraphics)
@_exported import enum CacaoRender.CGLineCap
@_exported import enum CacaoRender.CGLineJoin
#endif

/// The SwiftUI API, implemented in Swift, for Linux and macOS.
///
/// This module holds the platform-neutral part of Cacao: views, state,
/// environment and layout, which build `CacaoRender`'s display lists. It has no windowing or GPU
/// dependencies, so it builds and tests headless on any host. Windows, input
/// and rendering come from `CacaoSDL`.
public enum CacaoLibrary {

    /// The version of the SwiftUI API surface Cacao implements.
    public static let version = "0.1.0"
}
