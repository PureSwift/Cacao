//
//  DesktopSegmentedControl.swift
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

/// The desktop's segmented control: segments side by side in one shaded
/// track, with lines between them, and the selected one pressed in.
internal struct _DesktopSegmentedControl: View {

    let options: [Option]

    let selected: AnyHashable

    let select: (AnyHashable?) -> Void

    @Environment(\.styleTokens) private var tokens

    @Environment(\.isEnabled) private var isEnabled

    @Environment(\.controlSize) private var controlSize

    var body: some View {
        let colors = tokens.segmentedControl
        let metrics = tokens.metrics
        let radius = tokens.radii.control
        let track = RoundedRectangle(cornerRadius: radius)
        HStack(spacing: 0) {
            ForEach(options.indices, id: \.self) { index in
                let option = options[index]
                let isSelected = option.tag == selected
                if index > 0 {
                    Rectangle()
                        .fill(Color(colors.divider))
                        .frame(width: metrics.separatorWidth)
                }
                Button { select(option.tag) } label: {
                    option.label
                        .font(Font(token: tokens.fonts.control(controlSize)))
                        .foregroundStyle(Color(
                            !isEnabled ? colors.disabledText : isSelected ? colors.selectedText : colors.text
                        ))
                        .lineLimit(1)
                        .padding(.horizontal, metrics.controlPadding(controlSize))
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .background {
                            if isSelected {
                                Rectangle().fill(token: colors.selectedFill)
                            }
                        }
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
        .frame(height: metrics.controlHeight(controlSize))
        .background { track.fill(token: colors.fill) }
        .clipShape(track)
        .overlay { track.strokeBorder(Color(colors.border), lineWidth: metrics.borderWidth) }
    }
}
