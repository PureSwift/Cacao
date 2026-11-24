//
//  MenuStyle.swift
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

/// The styles of menus.
public struct MenuStyleKind: Equatable, Sendable {
    internal let name: String
    static let automatic = MenuStyleKind(name: "automatic")
    static let button = MenuStyleKind(name: "button")
    static let borderlessButton = MenuStyleKind(name: "borderlessButton")
}

/// A type that applies a custom appearance to all menus within a view
/// hierarchy.
public protocol MenuStyle {
    var _kind: MenuStyleKind { get }
}

/// The default menu style: a bordered button with a chevron.
public struct DefaultMenuStyle: MenuStyle {
    public init() { }
    public var _kind: MenuStyleKind { .automatic }
}

/// A menu style that shows the menu's label as a bordered button.
public struct ButtonMenuStyle: MenuStyle {
    public init() { }
    public var _kind: MenuStyleKind { .button }
}

/// A menu style that shows the menu's label as plain text, highlighted
/// while the menu is open, as the titles of a menu bar are.
public struct BorderlessButtonMenuStyle: MenuStyle {
    public init() { }
    public var _kind: MenuStyleKind { .borderlessButton }
}

extension MenuStyle where Self == DefaultMenuStyle {
    public static var automatic: DefaultMenuStyle { DefaultMenuStyle() }
}

extension MenuStyle where Self == ButtonMenuStyle {
    public static var button: ButtonMenuStyle { ButtonMenuStyle() }
}

extension MenuStyle where Self == BorderlessButtonMenuStyle {
    public static var borderlessButton: BorderlessButtonMenuStyle { BorderlessButtonMenuStyle() }
}

private struct MenuStyleKey: EnvironmentKey {
    static let defaultValue = MenuStyleKind.automatic
}

private struct MenuIndicatorKey: EnvironmentKey {
    static let defaultValue = Visibility.automatic
}

extension EnvironmentValues {

    internal var menuStyle: MenuStyleKind {
        get { self[MenuStyleKey.self] }
        set { self[MenuStyleKey.self] = newValue }
    }

    /// Whether menus show the chevron that says they open a menu.
    public var menuIndicatorVisibility: Visibility {
        get { self[MenuIndicatorKey.self] }
        set { self[MenuIndicatorKey.self] = newValue }
    }
}

extension View {

    /// Sets the style for menus within this view.
    public func menuStyle<S: MenuStyle>(_ style: S) -> some View {
        environment(\.menuStyle, style._kind)
    }

    /// Sets the visibility of the chevron menus show after their label.
    public func menuIndicator(_ visibility: Visibility) -> some View {
        environment(\.menuIndicatorVisibility, visibility)
    }
}

// MARK: - Borderless

/// A borderless menu's label: its title as plain text, on a highlight while
/// the menu is open or pressed. In the desktop's look, a menu bar title.
internal struct _BorderlessMenuButtonStyle: ButtonStyle {

    let isOpen: Bool

    let showsIndicator: Bool

    func makeBody(configuration: Configuration) -> some View {
        _BorderlessMenuLabel(configuration: configuration, isOpen: isOpen, showsIndicator: showsIndicator)
    }
}

private struct _BorderlessMenuLabel: View {

    let configuration: ButtonStyleConfiguration

    let isOpen: Bool

    let showsIndicator: Bool

    @Environment(\.styleTokens) private var tokens

    @Environment(\.interfaceLook) private var look

    @Environment(\.isEnabled) private var isEnabled

    var body: some View {
        let isHighlighted = isEnabled && (isOpen || configuration.isPressed)
        if look.value == .desktop {
            let colors = tokens.menuBar
            label(spacing: 4)
                .font(Font(token: tokens.fonts.menuBar))
                .foregroundStyle(Color(isHighlighted ? colors.highlightText : colors.text))
                .opacity(isEnabled ? 1 : 0.5)
                .padding(.horizontal, tokens.metrics.menuBarItemPadding)
                .padding(.vertical, 3)
                .background {
                    RoundedRectangle(cornerRadius: tokens.radii.menuBarItem)
                        .fill(isHighlighted ? Color(colors.highlight) : Color.clear)
                }
                .contentShape(Rectangle())
        } else {
            label(spacing: 4)
                .foregroundStyle(isEnabled ? Color.primary : Color.secondary)
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background {
                    RoundedRectangle(cornerRadius: 5)
                        .fill(isHighlighted ? Color.primary.opacity(0.12) : Color.clear)
                }
                .contentShape(Rectangle())
        }
    }

    private func label(spacing: CGFloat) -> some View {
        HStack(spacing: spacing) {
            configuration.label
                .lineLimit(1)
            if showsIndicator {
                _ChevronShape()
                    .stroke(style: StrokeStyle(lineWidth: 1.5, lineCap: .round, lineJoin: .round))
                    .frame(width: 8, height: 8)
                    .opacity(0.7)
            }
        }
    }
}
