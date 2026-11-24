//
//  DesktopMenus.swift
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

/// The desktop's menu: an opaque, rounded panel with a border and a
/// shadow, its items inset from its edges.
internal struct _DesktopMenuContent: View {

    let content: AnyView

    @Environment(\.styleTokens) private var tokens

    var body: some View {
        let colors = tokens.menu
        let metrics = tokens.metrics
        let shape = RoundedRectangle(cornerRadius: tokens.radii.menu)
        _MenuItems {
            VStack(alignment: .leading, spacing: 0) {
                content
            }
        }
        .buttonStyle(_DesktopMenuItemStyle())
        .padding(metrics.menuInset)
        .frame(minWidth: metrics.menuMinimumWidth, alignment: .leading)
        .background {
            shape
                .fill(Color(colors.background))
                .shadow(token: colors.shadow)
        }
        .overlay {
            shape.strokeBorder(Color(colors.border), lineWidth: metrics.borderWidth)
        }
    }
}

/// A menu item: highlighted with the accent while the pointer is over it,
/// it's pressed or focused, or its submenu is open.
internal struct _DesktopMenuItemStyle: ButtonStyle {

    func makeBody(configuration: Configuration) -> some View {
        _DesktopMenuItem(configuration: configuration)
    }
}

private struct _DesktopMenuItem: View {

    let configuration: ButtonStyleConfiguration

    @Environment(\.styleTokens) private var tokens

    @Environment(\.isEnabled) private var isEnabled

    @Environment(\.isFocused) private var isFocused

    @Environment(\.isMenuItemOpen) private var isOpen

    @State private var isHovered = false

    var body: some View {
        let colors = tokens.menu
        let metrics = tokens.metrics
        let isHighlighted = isEnabled && (isHovered || configuration.isPressed || isFocused || isOpen)
        let text = !isEnabled ? colors.disabledText : isHighlighted ? colors.highlightText : colors.text
        configuration.label
            .font(Font(token: tokens.fonts.menu))
            .foregroundStyle(Color(text))
            .lineLimit(1)
            .padding(.horizontal, metrics.menuItemPadding - metrics.menuInset)
            .frame(maxWidth: .infinity, minHeight: metrics.menuItemHeight, alignment: .leading)
            .background {
                RoundedRectangle(cornerRadius: tokens.radii.menuItem)
                    .fill(isHighlighted ? Color(colors.highlight) : Color.clear)
            }
            .contentShape(Rectangle())
            .onHover { isHovered = $0 }
    }
}
