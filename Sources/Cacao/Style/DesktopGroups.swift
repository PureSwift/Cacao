//
//  DesktopGroups.swift
//  Cacao
//
//  Created by Alsey Coleman Miller on 11/24/26.
//

import CacaoRender
internal import CacaoTokens
import Foundation

/// Forms' and grouped lists' colors: in the desktop's look, its rows sit
/// on the content background over the window's; in the stock look, on
/// white or dark gray cards over a grouped background.
internal enum GroupedColors {

    /// Behind the groups.
    static func background(in environment: EnvironmentValues) -> Color {
        guard environment.usesDesktopLook else {
            return Color.groupedBackground(environment.colorScheme)
        }
        return Color(environment.styleTokens.window.background)
    }

    /// A group's card, behind its rows.
    static func card(in environment: EnvironmentValues) -> Color {
        guard environment.usesDesktopLook else {
            return Color.controlBackground(environment.colorScheme)
        }
        return Color(environment.styleTokens.window.contentBackground)
    }

    /// A switch's track while it's on: the accent in the desktop's look,
    /// green in the stock look.
    static func switchOn(in environment: EnvironmentValues) -> Color {
        environment.usesDesktopLook ? Color.accentColor : Color.green
    }
}
