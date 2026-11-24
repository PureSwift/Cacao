//
//  DesktopTextFields.swift
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

/// The desktop's text field, behind its text: the content background in a
/// rounded border, which the accent rings while it has focus. A search
/// field is a pill with a magnifier at its leading end.
internal struct _DesktopFieldBezel: View {

    let isFocused: Bool

    let isSearch: Bool

    @Environment(\.styleTokens) private var tokens

    @Environment(\.isEnabled) private var isEnabled

    var body: some View {
        let colors = tokens.searchField
        let metrics = tokens.metrics
        let shape = RoundedRectangle(cornerRadius: isSearch ? tokens.radii.searchField : tokens.radii.control)
        ZStack(alignment: .leading) {
            shape.fill(Color(colors.background))
            if isFocused {
                // The ring is drawn inside the field, which clips what it
                // draws to its frame.
                shape.strokeBorder(Color(tokens.focusRing.color), lineWidth: metrics.focusRingWidth)
                shape.strokeBorder(Color(colors.focusedBorder), lineWidth: metrics.borderWidth)
            } else {
                shape.strokeBorder(Color(colors.border), lineWidth: metrics.borderWidth)
            }
            if isSearch {
                _MagnifierShape()
                    .stroke(Color(colors.icon), style: StrokeStyle(lineWidth: 1.5, lineCap: .round))
                    .frame(width: metrics.searchFieldIconSize, height: metrics.searchFieldIconSize)
                    .padding(.leading, metrics.controlPadding(.small) + 2)
            }
        }
        .opacity(isEnabled ? 1 : 0.6)
    }

    /// The color of a field's placeholder.
    static func placeholderColor(in environment: EnvironmentValues) -> Color {
        Color(environment.styleTokens.searchField.placeholder)
    }

    /// The space between the field's edges and its text.
    static func insets(in environment: EnvironmentValues) -> EdgeInsets {
        let metrics = environment.styleTokens.metrics
        let isSearch = environment.isSearchField
        // A 14-point line is about 18 points: 7 above and below make a
        // regular control's height.
        let vertical: CGFloat = 7
        let leading = isSearch
            ? metrics.controlPadding(.small) + 2 + metrics.searchFieldIconSize + metrics.spacingTight + 2
            : metrics.spacing
        return EdgeInsets(top: vertical, leading: leading, bottom: vertical, trailing: metrics.spacing)
    }
}

/// A magnifying glass: a circle with a handle toward the bottom right.
private struct _MagnifierShape: Shape {

    nonisolated func path(in rect: CGRect) -> Path {
        let side = min(rect.width, rect.height)
        let diameter = side * 0.7
        var path = Path()
        path.addEllipse(in: CGRect(x: rect.minX, y: rect.minY, width: diameter, height: diameter))
        let offset = diameter / 2 + diameter / 2 * 0.7071
        path.move(to: CGPoint(x: rect.minX + offset, y: rect.minY + offset))
        path.addLine(to: CGPoint(x: rect.minX + side, y: rect.minY + side))
        return path
    }
}

private struct IsSearchFieldKey: EnvironmentKey {
    static let defaultValue = false
}

extension EnvironmentValues {

    /// Whether text fields here are search fields, which the desktop's look
    /// draws as pills with a magnifier.
    internal var isSearchField: Bool {
        get { self[IsSearchFieldKey.self] }
        set { self[IsSearchFieldKey.self] = newValue }
    }
}
