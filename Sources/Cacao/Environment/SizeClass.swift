//
//  SizeClass.swift
//  Cacao
//
//  Created by Alsey Coleman Miller on 11/20/26.
//

import CacaoRender
import Foundation
#if canImport(CoreGraphics)
import CoreGraphics
#endif

/// A set of values that indicate the visual size available to the view.
public enum UserInterfaceSizeClass: Hashable, Sendable {

    /// The compact size class: an iPhone's width, or a narrow window.
    case compact

    /// The regular size class.
    case regular
}

private struct HorizontalSizeClassKey: EnvironmentKey {
    static let defaultValue: UserInterfaceSizeClass? = .regular
}

private struct VerticalSizeClassKey: EnvironmentKey {
    static let defaultValue: UserInterfaceSizeClass? = .regular
}

extension EnvironmentValues {

    /// The horizontal size class of this environment.
    public var horizontalSizeClass: UserInterfaceSizeClass? {
        get { self[HorizontalSizeClassKey.self] }
        set { self[HorizontalSizeClassKey.self] = newValue }
    }

    /// The vertical size class of this environment.
    public var verticalSizeClass: UserInterfaceSizeClass? {
        get { self[VerticalSizeClassKey.self] }
        set { self[VerticalSizeClassKey.self] = newValue }
    }
}

/// Which size classes a window has, from its size.
///
/// By default a window is compact in a dimension as an iPad's is when it
/// shares the screen: narrower than 678 points, the narrowest width at
/// which iPadOS keeps a split view's columns side by side, or shorter than
/// 480, as only a phone on its side is.
///
/// Two environment variables override the width: `CACAO_SIZE_CLASS`
/// (`compact` or `regular`) forces the horizontal size class whatever the
/// width, and `CACAO_COMPACT_WIDTH` sets the width, in points, below which
/// a window is compact.
package enum SizeClassPolicy {

    /// The width, in points, below which a window is compact.
    package static let compactWidth: CGFloat = 678

    /// The height, in points, below which a window is compact.
    package static let compactHeight: CGFloat = 480

    package static func horizontal(
        width: CGFloat,
        environment: [String: String] = ProcessInfo.processInfo.environment
    ) -> UserInterfaceSizeClass {
        switch environment["CACAO_SIZE_CLASS"]?.lowercased() {
        case "compact": return .compact
        case "regular": return .regular
        default: break
        }
        let threshold = environment["CACAO_COMPACT_WIDTH"].flatMap(Double.init).map { CGFloat($0) } ?? compactWidth
        return width < threshold ? .compact : .regular
    }

    package static func vertical(height: CGFloat) -> UserInterfaceSizeClass {
        height < compactHeight ? .compact : .regular
    }
}

extension ViewGraph {

    /// Sets the environment's size classes for a window of a size, if
    /// they changed. A host calls this before updating.
    package func applySizeClasses(
        for size: CGSize,
        environment variables: [String: String] = ProcessInfo.processInfo.environment
    ) {
        let horizontal = SizeClassPolicy.horizontal(width: size.width, environment: variables)
        let vertical = SizeClassPolicy.vertical(height: size.height)
        guard environment.horizontalSizeClass != horizontal || environment.verticalSizeClass != vertical else {
            return
        }
        var values = environment
        values.horizontalSizeClass = horizontal
        values.verticalSizeClass = vertical
        environment = values
    }
}
