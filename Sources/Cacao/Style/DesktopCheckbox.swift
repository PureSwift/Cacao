//
//  DesktopCheckbox.swift
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

/// The desktop's checkbox: a rounded square with a border, filled with the
/// accent and checked while on.
internal struct _DesktopCheckbox: View {

    let configuration: ToggleStyleConfiguration

    @Environment(\.styleTokens) private var tokens

    @Environment(\.isEnabled) private var isEnabled

    @Environment(\.labelsHidden) private var labelsHidden

    var body: some View {
        let isOn = configuration.$isOn
        let colors = tokens.checkbox
        let metrics = tokens.metrics
        let box = RoundedRectangle(cornerRadius: tokens.radii.checkbox)
        let checked = isOn.wrappedValue
        HStack(spacing: metrics.checkboxLabelSpacing) {
            ZStack {
                box.fill(Color(!isEnabled ? colors.disabledFill : checked ? colors.checkedFill : colors.fill))
                box.strokeBorder(Color(checked && isEnabled ? colors.checkedBorder : colors.border), lineWidth: metrics.borderWidth)
                if checked {
                    _CheckmarkShape()
                        .stroke(
                            Color(isEnabled ? colors.checkmark : colors.disabledCheckmark),
                            style: StrokeStyle(lineWidth: metrics.checkmarkWidth, lineCap: .round, lineJoin: .round)
                        )
                        .padding(3)
                }
            }
            .frame(width: metrics.checkboxSize, height: metrics.checkboxSize)
            if !labelsHidden {
                configuration.label
                    .foregroundStyle(Color(isEnabled ? tokens.text.primary : tokens.text.disabled))
            }
        }
        .contentShape(Rectangle())
        .onTapGesture { isOn.wrappedValue.toggle() }
    }
}
