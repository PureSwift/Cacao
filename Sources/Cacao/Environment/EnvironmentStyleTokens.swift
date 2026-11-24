//
//  EnvironmentStyleTokens.swift
//  Cacao
//
//  Created by Alsey Coleman Miller on 11/23/26.
//

package import CacaoTokens
import CacaoRender
import Foundation

extension EnvironmentValues {

    /// The desktop's style tokens for this environment: its color scheme
    /// and contrast, tinted with the color `Color.accentColor` resolves to
    /// here, so a view's `tint` tints them too. For Cacao's styles.
    ///
    /// Resolved once for each appearance: styles read them often.
    package var styleTokens: StyleTokens {
        StyleTokensCache.shared.tokens(
            isDark: colorScheme == .dark,
            accentColor: Color.accentColor.resolve(in: self),
            isHighContrast: colorSchemeContrast == .increased
        )
    }
}

/// The tokens of the appearances styles asked for lately.
private final class StyleTokensCache: @unchecked Sendable {

    static let shared = StyleTokensCache()

    private struct Key: Hashable {
        var isDark: Bool
        var accentColor: ResolvedColor
        var isHighContrast: Bool
    }

    private let lock = NSLock()

    private var entries: [Key: StyleTokens] = [:]

    /// More appearances than a running app sees: light and dark, a few
    /// tints.
    private let limit = 32

    func tokens(isDark: Bool, accentColor: ResolvedColor, isHighContrast: Bool) -> StyleTokens {
        let key = Key(isDark: isDark, accentColor: accentColor, isHighContrast: isHighContrast)
        lock.lock()
        defer { lock.unlock() }
        if let tokens = entries[key] {
            return tokens
        }
        let tokens = StyleTokens(isDark: isDark, accentColor: accentColor, isHighContrast: isHighContrast)
        if entries.count >= limit {
            entries.removeAll()
        }
        entries[key] = tokens
        return tokens
    }
}
