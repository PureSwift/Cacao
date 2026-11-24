//
//  EnvironmentStyleTokens.swift
//  Cacao
//
//  Created by Alsey Coleman Miller on 11/23/26.
//

package import CacaoTokens

extension EnvironmentValues {

    /// The desktop's style tokens for this environment: its color scheme
    /// and contrast, tinted with the color `Color.accentColor` resolves to
    /// here, so a view's `tint` tints them too. For Cacao's styles.
    package var styleTokens: StyleTokens {
        StyleTokens(
            isDark: colorScheme == .dark,
            accentColor: Color.accentColor.resolve(in: self),
            isHighContrast: colorSchemeContrast == .increased
        )
    }
}
