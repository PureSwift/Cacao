//
//  DesktopWindowChrome.swift
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

/// A window's chrome, drawn by the app for a window without the system's
/// decorations: the desktop's title bar, with the window buttons at the
/// ends the desktop asks for, a line around the window, and the content
/// below. A toolbar at the top of the content joins the title bar, so the
/// two are one surface with the buttons at its ends.
///
/// The title bar and the toolbar move the window when dragged; the host
/// resizes it from its edges.
package struct _WindowChrome: View {

    let content: AnyView

    let chrome: WindowChrome

    package init(content: AnyView, chrome: WindowChrome) {
        self.content = content
        self.chrome = chrome
    }

    @Environment(\.windowControls) private var controls

    @Environment(\.styleTokens) private var tokens

    /// Whether a toolbar at the top of the content is the title bar.
    @State private var hasUnifiedToolbar = false

    package var body: some View {
        let tokens = self.tokens
        let metrics = tokens.metrics
        let layout = controls?.buttonLayout ?? .standard
        let insets = TitleBarInsets(
            leading: Self.width(of: layout.leading, metrics: metrics),
            trailing: Self.width(of: layout.trailing, metrics: metrics)
        )
        let showsTitleBar = chrome == .titleBar && !hasUnifiedToolbar
        let barHeight = chrome == .titleBar && hasUnifiedToolbar ? metrics.unifiedToolbarHeight : metrics.titleBarHeight
        VStack(spacing: 0) {
            if showsTitleBar {
                _DesktopTitleBar(title: controls?.title ?? "", insets: insets)
            }
            content
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .coordinateSpace(name: WindowChromeSpace.name)
                .environment(\.titleBarInsets, chrome == .titleBar ? insets : nil)
                .onPreferenceChange(UnifiedToolbarKey.self) { unified in
                    if hasUnifiedToolbar != unified {
                        hasUnifiedToolbar = unified
                    }
                }
        }
        .background {
            // Without a title bar, the window moves from wherever the
            // content draws nothing.
            if chrome == .buttonsOnly {
                Color.clear
                    .contentShape(Rectangle())
                    .windowDragArea()
            }
        }
        .overlay(alignment: .topLeading) {
            _WindowButtons(buttons: layout.leading)
                .frame(height: barHeight)
                .padding(.leading, metrics.windowButtonInset)
        }
        .overlay(alignment: .topTrailing) {
            _WindowButtons(buttons: layout.trailing)
                .frame(height: barHeight)
                .padding(.trailing, metrics.windowButtonInset)
        }
        .overlay {
            // A line around the window keeps it apart from what's behind
            // it, but not when it fills the screen.
            if controls?.isMaximized != true {
                Rectangle()
                    .strokeBorder(Color(tokens.window.border), lineWidth: metrics.windowBorderWidth)
                    .allowsHitTesting(false)
            }
        }
    }

    /// The width window buttons take, with the space from the window's
    /// edge to them and from them to what's beside them.
    static func width(of buttons: [WindowButtonLayout.Button], metrics: StyleTokens.Metrics) -> CGFloat {
        guard !buttons.isEmpty else { return 0 }
        let count = CGFloat(buttons.count)
        return metrics.windowButtonInset * 2 + count * metrics.windowButtonSize + (count - 1) * metrics.windowButtonSpacing
    }
}

/// The desktop's title bar on its own: the title, centered between the
/// window buttons, over a shaded bar with a line along its bottom.
internal struct _DesktopTitleBar: View {

    let title: String

    let insets: TitleBarInsets

    @Environment(\.styleTokens) private var tokens

    @Environment(\.appearsActive) private var isActive

    var body: some View {
        let colors = tokens.titleBar
        let metrics = tokens.metrics
        Text(verbatim: title)
            .font(Font(token: tokens.fonts.windowTitle))
            .foregroundStyle(Color(isActive ? colors.text : colors.inactiveText))
            .lineLimit(1)
            .padding(.horizontal, max(insets.leading, insets.trailing, metrics.spacing))
            .frame(maxWidth: .infinity)
            .frame(height: metrics.titleBarHeight)
            .background {
                Rectangle().fill(token: isActive ? colors.background : colors.inactiveBackground)
            }
            .overlay(alignment: .bottom) {
                Rectangle()
                    .fill(Color(colors.separator))
                    .frame(height: metrics.separatorWidth)
            }
            .windowDragArea()
            .accessibilityAddTraits(.isHeader)
    }
}

// MARK: - Window buttons

/// A row of window buttons.
internal struct _WindowButtons: View {

    let buttons: [WindowButtonLayout.Button]

    @Environment(\.styleTokens) private var tokens

    var body: some View {
        HStack(spacing: tokens.metrics.windowButtonSpacing) {
            ForEach(buttons, id: \.self) { button in
                _WindowButton(button: button)
            }
        }
    }
}

/// A window button: a neutral circle with a glyph, which turns red while
/// the pointer is over the close button.
internal struct _WindowButton: View {

    let button: WindowButtonLayout.Button

    @Environment(\.windowControls) private var controls

    var body: some View {
        let controls = self.controls
        let isMaximized = controls?.isMaximized ?? false
        Button {
            switch button {
            case .close: controls?.close()
            case .minimize: controls?.minimize()
            case .maximize: controls?.toggleMaximized()
            }
        } label: {
            EmptyView()
        }
        .buttonStyle(_WindowButtonStyle(button: button, isMaximized: isMaximized))
        .accessibilityLabel(Self.label(button, isMaximized: isMaximized))
    }

    static func label(_ button: WindowButtonLayout.Button, isMaximized: Bool) -> String {
        switch button {
        case .close: "Close"
        case .minimize: "Minimize"
        case .maximize: isMaximized ? "Restore" : "Maximize"
        }
    }
}

private struct _WindowButtonStyle: ButtonStyle {

    let button: WindowButtonLayout.Button

    let isMaximized: Bool

    func makeBody(configuration: Configuration) -> some View {
        _WindowButtonFace(button: button, isMaximized: isMaximized, isPressed: configuration.isPressed)
    }
}

private struct _WindowButtonFace: View {

    let button: WindowButtonLayout.Button

    let isMaximized: Bool

    let isPressed: Bool

    @Environment(\.styleTokens) private var tokens

    @State private var isHovered = false

    var body: some View {
        let colors = tokens.titleBar.windowButton
        let metrics = tokens.metrics
        let warns = button == .close && (isHovered || isPressed)
        let fill = warns ? colors.closeHoverFill
            : isPressed ? colors.pressedFill
            : isHovered ? colors.hoverFill
            : colors.fill
        ZStack {
            Circle().fill(Color(fill))
            _WindowButtonGlyph(button: button, isMaximized: isMaximized)
                .stroke(
                    Color(warns ? colors.closeHoverGlyph : colors.glyph),
                    style: StrokeStyle(lineWidth: 1.5, lineCap: .round, lineJoin: .round)
                )
                .frame(width: metrics.windowButtonGlyphSize, height: metrics.windowButtonGlyphSize)
        }
        .frame(width: metrics.windowButtonSize, height: metrics.windowButtonSize)
        .contentShape(Circle())
        .onHover { isHovered = $0 }
    }
}

/// A window button's glyph: a cross to close, a line to minimize, a square
/// to maximize and two to restore.
private struct _WindowButtonGlyph: Shape {

    let button: WindowButtonLayout.Button

    let isMaximized: Bool

    nonisolated func path(in rect: CGRect) -> Path {
        var path = Path()
        switch button {
        case .close:
            path.move(to: CGPoint(x: rect.minX, y: rect.minY))
            path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
            path.move(to: CGPoint(x: rect.maxX, y: rect.minY))
            path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        case .minimize:
            path.move(to: CGPoint(x: rect.minX, y: rect.midY))
            path.addLine(to: CGPoint(x: rect.maxX, y: rect.midY))
        case .maximize where isMaximized:
            let side = rect.width * 0.75
            let offset = rect.width - side
            path.addRect(CGRect(x: rect.minX, y: rect.minY + offset, width: side, height: side))
            path.move(to: CGPoint(x: rect.minX + offset, y: rect.minY + offset))
            path.addLine(to: CGPoint(x: rect.minX + offset, y: rect.minY))
            path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
            path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY + side))
            path.addLine(to: CGPoint(x: rect.minX + side, y: rect.minY + side))
        case .maximize:
            path.addRect(rect)
        }
        return path
    }
}

// MARK: - Joining a toolbar

extension View {

    /// Makes dragging the view move the window, as `WindowDragGesture`
    /// does, or not.
    internal func windowDragArea(_ isOn: Bool = true) -> some View {
        modifier(_AttributesModifier { $0.isWindowDragArea = isOn })
    }
}

/// The room a toolbar joined with the title bar leaves for the window
/// buttons at each end.
internal struct TitleBarInsets: Equatable, Sendable {

    var leading: CGFloat

    var trailing: CGFloat
}

private struct TitleBarInsetsKey: EnvironmentKey {
    static var defaultValue: TitleBarInsets? { nil }
}

extension EnvironmentValues {

    /// For a toolbar at the top of a window that draws the desktop's title
    /// bar: the room to leave for the window buttons, as it is the title
    /// bar. `nil` elsewhere.
    internal var titleBarInsets: TitleBarInsets? {
        get { self[TitleBarInsetsKey.self] }
        set { self[TitleBarInsetsKey.self] = newValue }
    }
}

/// The coordinate space of the window's content, below any title bar: a
/// toolbar at its top joins the title bar.
internal enum WindowChromeSpace {
    static let name = "Cacao.windowContent"
}

/// Whether a toolbar at the top of the window took the title bar's place.
internal struct UnifiedToolbarKey: PreferenceKey {

    static let defaultValue = false

    static func reduce(value: inout Bool, nextValue: () -> Bool) {
        value = value || nextValue()
    }
}
