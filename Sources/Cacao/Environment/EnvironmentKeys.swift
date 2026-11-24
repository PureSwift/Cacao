//
//  EnvironmentKeys.swift
//  Cacao
//
//  Created by Alsey Coleman Miller on 11/13/26.
//

import CacaoRender
import Foundation
#if canImport(CoreGraphics)
import CoreGraphics
#endif

// MARK: - Keys

private struct FontKey: EnvironmentKey {
    static let defaultValue: Font? = nil
}

private struct ColorSchemeKey: EnvironmentKey {
    static let defaultValue: ColorScheme = .light
}

private struct ColorSchemeContrastKey: EnvironmentKey {
    static let defaultValue: ColorSchemeContrast = .standard
}

private struct LayoutDirectionKey: EnvironmentKey {
    static let defaultValue: LayoutDirection = .leftToRight
}

private struct IsEnabledKey: EnvironmentKey {
    static let defaultValue = true
}

private struct LineLimitKey: EnvironmentKey {
    static let defaultValue: Int? = nil
}

private struct MultilineTextAlignmentKey: EnvironmentKey {
    static let defaultValue: TextAlignment = .leading
}

private struct DisplayScaleKey: EnvironmentKey {
    static let defaultValue: CGFloat = 1
}

private struct ForegroundColorKey: EnvironmentKey {
    static let defaultValue: Color? = nil
}

private struct ForegroundStyleKey: EnvironmentKey {
    static let defaultValue: AnyShapeStyle? = nil
}

private struct StackOrientationKey: EnvironmentKey {
    static let defaultValue: Axis? = nil
}

// MARK: - EnvironmentValues

extension EnvironmentValues {

    /// The default font of this environment.
    public var font: Font? {
        get { self[FontKey.self] }
        set { self[FontKey.self] = newValue }
    }

    /// The color scheme of this environment.
    public var colorScheme: ColorScheme {
        get { self[ColorSchemeKey.self] }
        set { self[ColorSchemeKey.self] = newValue }
    }

    /// The contrast associated with the color scheme of this environment:
    /// increased when the system asks for higher contrast.
    public package(set) var colorSchemeContrast: ColorSchemeContrast {
        get { self[ColorSchemeContrastKey.self] }
        set { self[ColorSchemeContrastKey.self] = newValue }
    }

    /// The layout direction associated with the current environment.
    public var layoutDirection: LayoutDirection {
        get { self[LayoutDirectionKey.self] }
        set { self[LayoutDirectionKey.self] = newValue }
    }

    /// A Boolean value that indicates whether the view associated with this
    /// environment allows user interaction.
    public var isEnabled: Bool {
        get { self[IsEnabledKey.self] }
        set { self[IsEnabledKey.self] = newValue }
    }

    /// The maximum number of lines that text can occupy in a view.
    public var lineLimit: Int? {
        get { self[LineLimitKey.self] }
        set { self[LineLimitKey.self] = newValue }
    }

    /// An environment value that indicates how a text view aligns its lines
    /// when the content wraps or contains newlines.
    public var multilineTextAlignment: TextAlignment {
        get { self[MultilineTextAlignmentKey.self] }
        set { self[MultilineTextAlignmentKey.self] = newValue }
    }

    /// The display scale of this environment.
    public var displayScale: CGFloat {
        get { self[DisplayScaleKey.self] }
        set { self[DisplayScaleKey.self] = newValue }
    }

    internal var foregroundColor: Color? {
        get { self[ForegroundColorKey.self] }
        set { self[ForegroundColorKey.self] = newValue }
    }

    internal var foregroundStyle: AnyShapeStyle? {
        get { self[ForegroundStyleKey.self] }
        set { self[ForegroundStyleKey.self] = newValue }
    }

    /// The axis of the enclosing stack, which spacers and dividers follow.
    internal var stackOrientation: Axis? {
        get { self[StackOrientationKey.self] }
        set { self[StackOrientationKey.self] = newValue }
    }
}

// MARK: - Modifiers

extension View {

    /// Sets the default font for text in this view.
    public func font(_ font: Font?) -> some View {
        environment(\.font, font)
    }

    /// Sets the color of the foreground elements displayed by this view.
    public func foregroundColor(_ color: Color?) -> some View {
        environment(\.foregroundColor, color)
    }

    /// Sets a view's foreground elements to use a given style.
    public func foregroundStyle<S: ShapeStyle>(_ style: S) -> some View {
        environment(\.foregroundStyle, AnyShapeStyle(style))
    }

    /// Sets the maximum number of lines that text can occupy in this view.
    public func lineLimit(_ number: Int?) -> some View {
        environment(\.lineLimit, number)
    }

    /// Sets the alignment of a text view that contains multiple lines of text.
    public func multilineTextAlignment(_ alignment: TextAlignment) -> some View {
        environment(\.multilineTextAlignment, alignment)
    }

    /// Adds a condition that controls whether users can interact with this view.
    public func disabled(_ disabled: Bool) -> some View {
        transformEnvironment(\.isEnabled) { isEnabled in
            isEnabled = isEnabled && !disabled
        }
    }
}
