//
//  DesktopSidebar.swift
//  Cacao
//
//  Created by Alsey Coleman Miller on 11/24/26.
//

import CacaoRender
internal import CacaoTokens
import Foundation
#if canImport(CoreGraphics)
import CoreGraphics
#endif

/// The desktop's source list, along a window's leading edge: a step off
/// the window's background, with the selected row tinted with the accent
/// and quiet section headers.
internal enum DesktopSidebar {

    /// The sidebar's background.
    static func background(in environment: EnvironmentValues) -> Color {
        Color(environment.styleTokens.sidebar.background)
    }

    /// The selected row's fill: tinted with the accent in the key window,
    /// neutral in others.
    static func selection(in environment: EnvironmentValues) -> Color {
        let sidebar = environment.styleTokens.sidebar
        return Color(environment.appearsActive ? sidebar.selection : sidebar.inactiveSelection)
    }

    /// The selected row's label.
    static func selectionText(in environment: EnvironmentValues) -> Color {
        let sidebar = environment.styleTokens.sidebar
        return Color(environment.appearsActive ? sidebar.selectionText : sidebar.inactiveSelectionText)
    }
}

/// A section's header in the desktop's sidebar: small, secondary text,
/// lined up with the rows' labels.
internal struct _DesktopSidebarHeader: View {

    let label: AnyView

    /// The space between the list's sides and its rows' labels.
    let leading: CGFloat

    @Environment(\.styleTokens) private var tokens

    var body: some View {
        let colors = tokens.sidebar
        let font = tokens.fonts.callout
        label
            .font(Font(token: ResolvedFont(size: font.size, weight: 600)))
            .foregroundStyle(Color(colors.secondaryText))
            .lineLimit(1)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.leading, leading)
            .padding(.trailing, tokens.metrics.sidebarSelectionInset)
            .padding(.top, tokens.metrics.spacingLoose)
            .padding(.bottom, tokens.metrics.spacingTight)
    }
}
