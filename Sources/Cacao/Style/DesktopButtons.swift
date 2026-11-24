//
//  DesktopButtons.swift
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

/// The desktop's push button: shaded a step darker toward the bottom, with
/// a border and a light line along its top edge. The prominent one, the
/// default action, is filled with the accent.
internal struct _DesktopPushButton: View {

    let configuration: ButtonStyleConfiguration

    let isProminent: Bool

    @Environment(\.styleTokens) private var tokens

    @Environment(\.isEnabled) private var isEnabled

    @Environment(\.controlSize) private var controlSize

    @Environment(\.font) private var font

    @Environment(\.buttonBorderShape) private var shape

    @State private var isHovered = false

    var body: some View {
        let colors = isProminent ? tokens.defaultButton : tokens.pushButton
        let metrics = tokens.metrics
        let radius = tokens.radii.control
        let fill: StyleTokens.Gradient = if !isEnabled {
            colors.disabledFill
        } else if configuration.isPressed {
            colors.pressedFill
        } else if isHovered {
            colors.hoverFill
        } else {
            colors.fill
        }
        let labelFont = isProminent && controlSize != .small && controlSize != .mini
            ? tokens.fonts.defaultControl
            : tokens.fonts.control(controlSize)
        configuration.label
            .font(font ?? Font(token: labelFont))
            .foregroundStyle(Color(isEnabled ? colors.text : colors.disabledText))
            .lineLimit(1)
            .padding(.horizontal, metrics.controlPadding(controlSize))
            .frame(minHeight: metrics.controlHeight(controlSize))
            .background {
                _DesktopBezel(
                    fill: fill,
                    border: colors.border,
                    // Pressed and disabled buttons are flat.
                    highlight: configuration.isPressed || !isEnabled ? nil : colors.highlight,
                    shape: shape,
                    radius: radius,
                    borderWidth: metrics.borderWidth
                )
            }
            .onHover { isHovered = $0 }
    }
}

/// The desktop's toolbar button: flat until the pointer is over it, then
/// drawn as a push button.
internal struct _DesktopToolbarButton: View {

    let configuration: ButtonStyleConfiguration

    @Environment(\.styleTokens) private var tokens

    @Environment(\.isEnabled) private var isEnabled

    @Environment(\.font) private var font

    @State private var isHovered = false

    var body: some View {
        let colors = tokens.pushButton
        let metrics = tokens.metrics
        let isLit = isEnabled && (isHovered || configuration.isPressed)
        configuration.label
            .font(font ?? Font(token: tokens.fonts.control))
            .foregroundStyle(Color(isEnabled ? colors.text : colors.disabledText))
            .lineLimit(1)
            .padding(.horizontal, metrics.spacing)
            .frame(minWidth: metrics.controlHeight, minHeight: metrics.controlHeight)
            .background {
                if isLit {
                    _DesktopBezel(
                        fill: configuration.isPressed ? colors.pressedFill : colors.hoverFill,
                        border: colors.border,
                        highlight: configuration.isPressed ? nil : colors.highlight,
                        shape: .automatic,
                        radius: tokens.radii.control,
                        borderWidth: metrics.borderWidth
                    )
                }
            }
            .contentShape(Rectangle())
            .onHover { isHovered = $0 }
    }
}

/// A control's shaded fill, border and top highlight.
internal struct _DesktopBezel: View {

    let fill: StyleTokens.Gradient

    let border: ResolvedColor

    let highlight: ResolvedColor?

    let shape: ButtonBorderShape

    let radius: CGFloat

    let borderWidth: CGFloat

    var body: some View {
        switch shape.kind {
        case .capsule:
            bezel(Capsule(), radius: nil)
        case .circle:
            bezel(Circle(), radius: nil)
        case let .roundedRectangle(custom):
            bezel(RoundedRectangle(cornerRadius: custom ?? radius), radius: custom ?? radius)
        }
    }

    private func bezel<S: InsettableShape>(_ shape: S, radius: CGFloat?) -> some View {
        shape.fill(token: fill)
            .overlay(alignment: .top) {
                // A line of light just inside the top edge, clear of the
                // rounded corners.
                if let highlight, let radius {
                    Rectangle()
                        .fill(Color(highlight))
                        .frame(height: borderWidth)
                        .padding(.horizontal, radius)
                        .padding(.top, borderWidth)
                }
            }
            .overlay {
                shape.strokeBorder(Color(border), lineWidth: borderWidth)
            }
    }
}

// MARK: - Automatic

/// What a button with the automatic style draws: in the desktop's look, a
/// push button (or a toolbar button in a toolbar); in the stock look,
/// borderless.
internal struct _AutomaticButton: View {

    let configuration: ButtonStyleConfiguration

    @Environment(\.interfaceLook) private var look

    @Environment(\.isInToolbar) private var isInToolbar

    var body: some View {
        if look.value == .desktop {
            if isInToolbar {
                _DesktopToolbarButton(configuration: configuration)
            } else {
                _DesktopPushButton(configuration: configuration, isProminent: false)
            }
        } else {
            _BorderlessButton(configuration: configuration)
        }
    }
}

private struct IsInToolbarKey: EnvironmentKey {
    static let defaultValue = false
}

extension EnvironmentValues {

    /// Whether views are in a toolbar, where the desktop's buttons are
    /// flat until hovered.
    internal var isInToolbar: Bool {
        get { self[IsInToolbarKey.self] }
        set { self[IsInToolbarKey.self] = newValue }
    }
}
