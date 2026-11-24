//
//  ColorMath.swift
//  CacaoTokens
//
//  Created by Alsey Coleman Miller on 11/23/26.
//

import CacaoRender
import Foundation

// The arithmetic tokens are derived with: mixing, and the relative
// luminance and contrast ratio of WCAG 2.2 (§1.4.3 and §1.4.11), which is
// how text and accent colors are kept readable for any accent.

package extension ResolvedColor {

    /// An sRGB color from a hex number like `0xF8F7F6`.
    init(rgb: UInt32, opacity: Float = 1) {
        self.init(
            red: Float((rgb >> 16) & 0xFF) / 255,
            green: Float((rgb >> 8) & 0xFF) / 255,
            blue: Float(rgb & 0xFF) / 255,
            opacity: opacity
        )
    }

    /// The color with another opacity.
    func opacity(_ opacity: Float) -> ResolvedColor {
        var color = self
        color.opacity = opacity
        return color
    }

    /// This color moved toward another by `amount`, from 0 (this color)
    /// to 1 (the other), keeping this color's opacity.
    func mixed(with other: ResolvedColor, by amount: Float) -> ResolvedColor {
        let amount = max(0, min(1, amount))
        return ResolvedColor(
            red: red + (other.red - red) * amount,
            green: green + (other.green - green) * amount,
            blue: blue + (other.blue - blue) * amount,
            opacity: opacity
        )
    }

    /// This color drawn over an opaque background.
    func composited(over background: ResolvedColor) -> ResolvedColor {
        background.mixed(with: self.opacity(background.opacity), by: opacity)
    }

    /// The relative luminance WCAG defines: 0 for black, 1 for white.
    var relativeLuminance: Double {
        func linear(_ component: Float) -> Double {
            let value = Double(max(0, min(1, component)))
            return value <= 0.04045 ? value / 12.92 : pow((value + 0.055) / 1.055, 2.4)
        }
        return 0.2126 * linear(red) + 0.7152 * linear(green) + 0.0722 * linear(blue)
    }

    /// The WCAG contrast ratio of this color drawn over `background`, from
    /// 1 to 21. A translucent color is composited over the background first.
    func contrastRatio(on background: ResolvedColor) -> Double {
        let foreground = opacity < 1 ? composited(over: background) : self
        let lighter = max(foreground.relativeLuminance, background.relativeLuminance)
        let darker = min(foreground.relativeLuminance, background.relativeLuminance)
        return (lighter + 0.05) / (darker + 0.05)
    }

    /// This color, moved toward `target` in steps of a tenth until it has
    /// a contrast of at least `minimum` on `background`. The target itself
    /// when no step reaches it.
    func readable(on background: ResolvedColor, minimum: Double, toward target: ResolvedColor) -> ResolvedColor {
        for step in 0 ... 10 {
            let candidate = mixed(with: target, by: Float(step) / 10)
            if candidate.contrastRatio(on: background) >= minimum {
                return candidate
            }
        }
        return target.opacity(opacity)
    }
}
