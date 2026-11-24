//
//  StyleTokenValues.swift
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

// The desktop's style tokens as SwiftUI values, for the styles that draw
// with them.

extension Font {

    /// The font a token names: the system font, or its monospaced design,
    /// at the token's size and weight.
    internal init(token: ResolvedFont) {
        self = .system(size: token.size, weight: Font.Weight(value: token.weight), design: token.design)
    }
}

extension LinearGradient {

    /// A token's gradient, from the top of the shape it fills to the
    /// bottom.
    internal init(token: StyleTokens.Gradient) {
        self.init(
            stops: token.stops.map { Gradient.Stop(color: Color($0.color), location: $0.location) },
            startPoint: .top,
            endPoint: .bottom
        )
    }
}

extension Shape {

    /// The shape filled with a token's gradient: with its color, if it's
    /// flat.
    internal func fill(token: StyleTokens.Gradient) -> some View {
        Group {
            if token.isFlat {
                fill(Color(token.top))
            } else {
                fill(LinearGradient(token: token))
            }
        }
    }
}

extension View {

    /// A shadow a token describes, falling straight down.
    internal func shadow(token: StyleTokens.Shadow) -> some View {
        shadow(color: Color(token.color), radius: token.radius, x: 0, y: token.offsetY)
    }
}

extension StyleTokens.Metrics {

    /// The height of a control of a size.
    internal func controlHeight(_ size: ControlSize) -> CGFloat {
        switch size {
        case .mini, .small: smallControlHeight
        case .regular: controlHeight
        case .large, .extraLarge: largeControlHeight
        }
    }

    /// The space before and after the label of a control of a size.
    internal func controlPadding(_ size: ControlSize) -> CGFloat {
        switch size {
        case .mini, .small: smallControlPadding
        case .regular: controlPadding
        case .large, .extraLarge: largeControlPadding
        }
    }
}

extension StyleTokens.Fonts {

    /// The label font of a control of a size.
    internal func control(_ size: ControlSize) -> ResolvedFont {
        switch size {
        case .mini, .small: smallControl
        case .regular, .large, .extraLarge: control
        }
    }
}
