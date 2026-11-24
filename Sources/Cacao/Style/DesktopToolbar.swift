//
//  DesktopToolbar.swift
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

/// The desktop's toolbar, at the top of a navigation stack: shaded like the
/// title bar it continues, its buttons flat until hovered, the title
/// centered and a search field at its trailing end.
internal struct _DesktopToolbar: View {

    let title: String

    let backTitle: String?

    let back: () -> Void

    let leading: [AnyView]

    let principal: [AnyView]

    let trailing: [AnyView]

    let search: (text: Binding<String>, prompt: Text?)?

    @Environment(\.styleTokens) private var tokens

    var body: some View {
        let colors = tokens.toolbar
        let metrics = tokens.metrics
        // The title sits between the items on either side, truncated
        // rather than over them.
        HStack(spacing: metrics.spacingTight) {
            if let backTitle {
                Button(action: back) {
                    HStack(spacing: metrics.spacingTight) {
                        _ChevronShape(pointsDown: false, pointsLeft: true)
                            .stroke(style: StrokeStyle(lineWidth: 1.75, lineCap: .round, lineJoin: .round))
                            .frame(width: 10, height: 14)
                        Text(backTitle)
                    }
                }
            }
            ForEach(leading.indices, id: \.self) { leading[$0] }
            Spacer(minLength: metrics.spacing)
            if !principal.isEmpty {
                HStack(spacing: metrics.spacing) { ForEach(principal.indices, id: \.self) { principal[$0] } }
            } else if !title.isEmpty {
                Text(title)
                    .font(Font(token: tokens.fonts.windowTitle))
                    .foregroundStyle(Color(tokens.titleBar.text))
                    .lineLimit(1)
            }
            Spacer(minLength: metrics.spacing)
            ForEach(trailing.indices, id: \.self) { trailing[$0] }
            if let search {
                TextField("Search", text: search.text, prompt: search.prompt ?? Text("Search"))
                    .environment(\.isSearchField, true)
                    .frame(minWidth: 120, maxWidth: 200)
                    .padding(.leading, metrics.spacing)
            }
        }
        .environment(\.isInToolbar, true)
        .padding(.horizontal, metrics.spacing)
        .frame(minHeight: metrics.toolbarHeight)
        .background {
            Rectangle().fill(token: colors.background)
        }
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(Color(colors.separator))
                .frame(height: metrics.separatorWidth)
        }
    }
}

/// A split view's sidebar column: in the desktop's look, the sidebar's
/// background, with lists drawn as source lists unless they ask for
/// another style; in the stock look, the bar background.
internal struct _SidebarColumnModifier: ViewModifier {

    @Environment(\.interfaceLook) private var look

    @Environment(\.listStyleKind) private var listStyle

    @Environment(\.colorScheme) private var colorScheme

    @Environment(\.self) private var environment

    func body(content: Content) -> some View {
        let isDesktop = look.value == .desktop
        content
            .environment(\.listStyleKind, isDesktop && listStyle == .automatic ? .sidebar : listStyle)
            .background(isDesktop ? DesktopSidebar.background(in: environment) : Color.barBackground(colorScheme))
    }
}

extension EnvironmentValues {

    /// The color behind a window's views: the desktop's window background
    /// in its look, else white or black.
    package var windowBackgroundColor: Color.Resolved {
        if usesDesktopLook {
            return styleTokens.window.background
        }
        return colorScheme == .dark ? Color.Resolved(red: 0, green: 0, blue: 0) : Color.Resolved(red: 1, green: 1, blue: 1)
    }
}
