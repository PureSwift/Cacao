//
//  Effects.swift
//  Cacao
//
//  Created by Alsey Coleman Miller on 11/13/26.
//

import CacaoRender
import Foundation
#if canImport(CoreGraphics)
import CoreGraphics
#endif

// MARK: - Blur

internal struct BlurBehavior: UnaryLayoutBehavior, AnimatableBehavior {

    let radius: CGFloat

    let isOpaque: Bool

    var animatableValues: [Double] {
        [Double(radius)]
    }

    func applying(_ values: [Double]) -> any NodeBehavior {
        BlurBehavior(radius: CGFloat(values[0]), isOpaque: isOpaque)
    }

    func sizeThatFits(_ proposal: ProposedViewSize, child: LayoutProxy) -> CGSize {
        child.size(in: proposal)
    }

    func placement(of child: LayoutProxy, size: CGSize, proposal: ProposedViewSize) -> (proposal: ProposedViewSize, origin: CGPoint) {
        (proposal, CGPoint(x: 0, y: 0))
    }

    func displayEffect(node: ViewNode) -> DisplayList.Effect? {
        .blur(BlurEffect(radius: max(0, radius), isOpaque: isOpaque))
    }
}

internal struct _BlurEffect: ViewModifier, PrimitiveViewModifier {

    let radius: CGFloat

    let isOpaque: Bool

    func resolve(content: any View, in context: ResolveContext) -> Resolution {
        Resolution(
            behavior: BlurBehavior(radius: radius, isOpaque: isOpaque),
            children: [ChildView(key: 0, view: content)]
        )
    }

    typealias Body = Never
}

// MARK: - Color matrix

extension ColorMatrix {

    static func hueRotation(_ angle: Angle) -> ColorMatrix {
        let c = Float(cos(angle.radians)), s = Float(sin(angle.radians))
        return ColorMatrix(rows: [
            [0.213 + c * 0.787 - s * 0.213, 0.715 - c * 0.715 - s * 0.715, 0.072 - c * 0.072 + s * 0.928, 0, 0],
            [0.213 - c * 0.213 + s * 0.143, 0.715 + c * 0.285 + s * 0.140, 0.072 - c * 0.072 - s * 0.283, 0, 0],
            [0.213 - c * 0.213 - s * 0.787, 0.715 - c * 0.715 + s * 0.715, 0.072 + c * 0.928 + s * 0.072, 0, 0],
            [0, 0, 0, 1, 0],
        ])
    }
}

internal struct ColorMatrixBehavior: UnaryLayoutBehavior, AnimatableBehavior {

    /// What the matrix is made from, so it can animate.
    enum Kind: Equatable {
        case brightness(Double)
        case contrast(Double)
        case saturation(Double)
        case grayscale(Double)
        case hueRotation(Double)
        case multiply(Color.Resolved)
        case fixed(ColorMatrix)
    }

    let kind: Kind

    var matrix: ColorMatrix {
        switch kind {
        case let .brightness(amount): .brightness(amount)
        case let .contrast(amount): .contrast(amount)
        case let .saturation(amount): .saturation(amount)
        case let .grayscale(amount): .saturation(1 - amount)
        case let .hueRotation(radians): .hueRotation(Angle(radians: radians))
        case let .multiply(color): .multiply(color)
        case let .fixed(matrix): matrix
        }
    }

    var animatableValues: [Double] {
        switch kind {
        case let .brightness(value), let .contrast(value), let .saturation(value), let .grayscale(value), let .hueRotation(value):
            [value]
        case let .multiply(color):
            color.components
        case .fixed:
            []
        }
    }

    func applying(_ values: [Double]) -> any NodeBehavior {
        switch kind {
        case .brightness: ColorMatrixBehavior(kind: .brightness(values[0]))
        case .contrast: ColorMatrixBehavior(kind: .contrast(values[0]))
        case .saturation: ColorMatrixBehavior(kind: .saturation(values[0]))
        case .grayscale: ColorMatrixBehavior(kind: .grayscale(values[0]))
        case .hueRotation: ColorMatrixBehavior(kind: .hueRotation(values[0]))
        case .multiply: ColorMatrixBehavior(kind: .multiply(Color.Resolved(components: values)))
        case .fixed: self
        }
    }

    func sizeThatFits(_ proposal: ProposedViewSize, child: LayoutProxy) -> CGSize {
        child.size(in: proposal)
    }

    func placement(of child: LayoutProxy, size: CGSize, proposal: ProposedViewSize) -> (proposal: ProposedViewSize, origin: CGPoint) {
        (proposal, CGPoint(x: 0, y: 0))
    }

    func displayEffect(node: ViewNode) -> DisplayList.Effect? {
        .colorMatrix(matrix)
    }
}

internal struct _ColorMatrixEffect: ViewModifier, PrimitiveViewModifier {

    let kind: ColorMatrixBehavior.Kind

    func resolve(content: any View, in context: ResolveContext) -> Resolution {
        Resolution(
            behavior: ColorMatrixBehavior(kind: kind),
            children: [ChildView(key: 0, view: content)]
        )
    }

    typealias Body = Never
}

internal struct _ColorMultiplyEffect: ViewModifier, PrimitiveViewModifier {

    let color: Color

    func resolve(content: any View, in context: ResolveContext) -> Resolution {
        Resolution(
            behavior: ColorMatrixBehavior(kind: .multiply(color.resolve(in: context.environment))),
            children: [ChildView(key: 0, view: content)]
        )
    }

    typealias Body = Never
}

extension View {

    /// Applies a Gaussian blur to this view.
    public func blur(radius: CGFloat, opaque: Bool = false) -> some View {
        modifier(_BlurEffect(radius: radius, isOpaque: opaque))
    }

    /// Brightens this view by the specified amount, from -1 to 1.
    public func brightness(_ amount: Double) -> some View {
        modifier(_ColorMatrixEffect(kind: .brightness(amount)))
    }

    /// Sets the contrast and separation between similar colors in this view.
    public func contrast(_ amount: Double) -> some View {
        modifier(_ColorMatrixEffect(kind: .contrast(amount)))
    }

    /// Adjusts the color saturation of this view.
    public func saturation(_ amount: Double) -> some View {
        modifier(_ColorMatrixEffect(kind: .saturation(amount)))
    }

    /// Adds a grayscale effect to this view, from 0 to 1.
    public func grayscale(_ amount: Double) -> some View {
        modifier(_ColorMatrixEffect(kind: .grayscale(amount)))
    }

    /// Applies a hue rotation effect to this view.
    public func hueRotation(_ angle: Angle) -> some View {
        modifier(_ColorMatrixEffect(kind: .hueRotation(angle.radians)))
    }

    /// Inverts the colors in this view.
    public func colorInvert() -> some View {
        modifier(_ColorMatrixEffect(kind: .fixed(.invert)))
    }

    /// Adds a color multiplication effect to this view.
    public func colorMultiply(_ color: Color) -> some View {
        modifier(_ColorMultiplyEffect(color: color))
    }

    /// Adds a luminance to alpha effect to this view.
    public func luminanceToAlpha() -> some View {
        modifier(_ColorMatrixEffect(kind: .fixed(.luminanceToAlpha)))
    }

    /// Applies a color matrix to this view.
    public func colorEffect(_ matrix: ColorMatrix) -> some View {
        modifier(_ColorMatrixEffect(kind: .fixed(matrix)))
    }
}
