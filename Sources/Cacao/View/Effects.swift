//
//  Effects.swift
//  Cacao
//
//  Created by Alsey Coleman Miller on 11/13/26.
//

import Foundation
#if canImport(CoreGraphics)
import CoreGraphics
#endif

// MARK: - Blur

/// A Gaussian blur of a view's drawing.
package struct BlurEffect: Equatable, Sendable {

    /// The blur's radius, in points.
    package var radius: CGFloat

    /// Whether the blur keeps to the view's bounds, without transparency
    /// spreading in at its edges.
    package var isOpaque: Bool

    package init(radius: CGFloat, isOpaque: Bool) {
        self.radius = radius
        self.isOpaque = isOpaque
    }
}

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

/// A transformation of colors: each output component is a weighted sum
/// of the input's red, green, blue and alpha, plus a constant. Colors are
/// straight (not premultiplied), in the sRGB color space.
public struct ColorMatrix: Hashable, Sendable {

    public var r1: Float = 1, r2: Float = 0, r3: Float = 0, r4: Float = 0, r5: Float = 0
    public var g1: Float = 0, g2: Float = 1, g3: Float = 0, g4: Float = 0, g5: Float = 0
    public var b1: Float = 0, b2: Float = 0, b3: Float = 1, b4: Float = 0, b5: Float = 0
    public var a1: Float = 0, a2: Float = 0, a3: Float = 0, a4: Float = 1, a5: Float = 0

    /// The identity matrix.
    public init() { }

    internal init(rows: [[Float]]) {
        (r1, r2, r3, r4, r5) = (rows[0][0], rows[0][1], rows[0][2], rows[0][3], rows[0][4])
        (g1, g2, g3, g4, g5) = (rows[1][0], rows[1][1], rows[1][2], rows[1][3], rows[1][4])
        (b1, b2, b3, b4, b5) = (rows[2][0], rows[2][1], rows[2][2], rows[2][3], rows[2][4])
        (a1, a2, a3, a4, a5) = (rows[3][0], rows[3][1], rows[3][2], rows[3][3], rows[3][4])
    }

    internal var rows: [[Float]] {
        [[r1, r2, r3, r4, r5], [g1, g2, g3, g4, g5], [b1, b2, b3, b4, b5], [a1, a2, a3, a4, a5]]
    }

    /// The matrix that applies `self`, then `other`.
    package func then(_ other: ColorMatrix) -> ColorMatrix {
        let a = other.rows, b = rows
        var result: [[Float]] = []
        for row in 0..<4 {
            var output: [Float] = []
            for column in 0..<5 {
                var sum: Float = column == 4 ? a[row][4] : 0
                for inner in 0..<4 {
                    sum += a[row][inner] * b[inner][column]
                }
                output.append(sum)
            }
            result.append(output)
        }
        return ColorMatrix(rows: result)
    }

    /// A color transformed, clamped to 0 through 1.
    package func apply(_ color: Color.Resolved) -> Color.Resolved {
        let r = color.red, g = color.green, b = color.blue, a = color.opacity
        func clamp(_ value: Float) -> Float { max(0, min(1, value)) }
        return Color.Resolved(
            red: clamp(r1 * r + r2 * g + r3 * b + r4 * a + r5),
            green: clamp(g1 * r + g2 * g + g3 * b + g4 * a + g5),
            blue: clamp(b1 * r + b2 * g + b3 * b + b4 * a + b5),
            opacity: clamp(a1 * r + a2 * g + a3 * b + a4 * a + a5)
        )
    }

    // Luminance weights (Rec. 709), as in SVG's filter matrices.
    private static let lr: Float = 0.2126, lg: Float = 0.7152, lb: Float = 0.0722

    static func brightness(_ amount: Double) -> ColorMatrix {
        let value = Float(amount)
        var matrix = ColorMatrix()
        matrix.r5 = value; matrix.g5 = value; matrix.b5 = value
        return matrix
    }

    static func contrast(_ amount: Double) -> ColorMatrix {
        let value = Float(amount), offset = (1 - Float(amount)) / 2
        return ColorMatrix(rows: [
            [value, 0, 0, 0, offset],
            [0, value, 0, 0, offset],
            [0, 0, value, 0, offset],
            [0, 0, 0, 1, 0],
        ])
    }

    static func saturation(_ amount: Double) -> ColorMatrix {
        let s = Float(amount), t = 1 - s
        return ColorMatrix(rows: [
            [lr * t + s, lg * t, lb * t, 0, 0],
            [lr * t, lg * t + s, lb * t, 0, 0],
            [lr * t, lg * t, lb * t + s, 0, 0],
            [0, 0, 0, 1, 0],
        ])
    }

    static func hueRotation(_ angle: Angle) -> ColorMatrix {
        let c = Float(cos(angle.radians)), s = Float(sin(angle.radians))
        return ColorMatrix(rows: [
            [0.213 + c * 0.787 - s * 0.213, 0.715 - c * 0.715 - s * 0.715, 0.072 - c * 0.072 + s * 0.928, 0, 0],
            [0.213 - c * 0.213 + s * 0.143, 0.715 + c * 0.285 + s * 0.140, 0.072 - c * 0.072 - s * 0.283, 0, 0],
            [0.213 - c * 0.213 - s * 0.787, 0.715 - c * 0.715 + s * 0.715, 0.072 + c * 0.928 + s * 0.072, 0, 0],
            [0, 0, 0, 1, 0],
        ])
    }

    static var invert: ColorMatrix {
        ColorMatrix(rows: [
            [-1, 0, 0, 0, 1],
            [0, -1, 0, 0, 1],
            [0, 0, -1, 0, 1],
            [0, 0, 0, 1, 0],
        ])
    }

    static func multiply(_ color: Color.Resolved) -> ColorMatrix {
        ColorMatrix(rows: [
            [color.red, 0, 0, 0, 0],
            [0, color.green, 0, 0, 0],
            [0, 0, color.blue, 0, 0],
            [0, 0, 0, color.opacity, 0],
        ])
    }

    static var luminanceToAlpha: ColorMatrix {
        ColorMatrix(rows: [
            [0, 0, 0, 0, 0],
            [0, 0, 0, 0, 0],
            [0, 0, 0, 0, 0],
            [lr, lg, lb, 0, 0],
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

// MARK: - Applying matrices to drawing

extension DisplayList.Item {

    /// The item with its colors, and its nested items' colors, transformed.
    package func applying(_ matrix: ColorMatrix) -> DisplayList.Item {
        var item = self
        switch value {
        case let .content(content):
            item.value = .content(content.applying(matrix))
        case let .effect(.colorMatrix(inner), nested):
            item.value = .effect(.colorMatrix(inner.then(matrix)), nested)
        case let .effect(.shadow(shadow), nested):
            var shadow = shadow
            shadow.color = matrix.apply(shadow.color)
            item.value = .effect(.shadow(shadow), DisplayList(items: nested.items.map { $0.applying(matrix) }))
        case let .effect(effect, nested):
            item.value = .effect(effect, DisplayList(items: nested.items.map { $0.applying(matrix) }))
        }
        return item
    }
}

extension DisplayList.Content {

    package func applying(_ matrix: ColorMatrix) -> DisplayList.Content {
        switch self {
        case let .color(color):
            return .color(matrix.apply(color))
        case var .text(text):
            text.applying(matrix)
            return .text(text)
        case var .shape(shape):
            shape.applying(matrix)
            return .shape(shape)
        case var .image(image):
            image.colorMatrix = image.colorMatrix.map { $0.then(matrix) } ?? matrix
            return .image(image)
        case var .drawing(drawing):
            drawing.operations = drawing.operations.map { operation in
                switch operation {
                case .shape(var shape, let state):
                    shape.applying(matrix)
                    return .shape(shape, state)
                case .text(var text, let rect, let state):
                    text.applying(matrix)
                    return .text(text, rect, state)
                case .image(var image, let rect, let state):
                    image.colorMatrix = image.colorMatrix.map { $0.then(matrix) } ?? matrix
                    return .image(image, rect, state)
                }
            }
            return .drawing(drawing)
        }
    }
}

extension ResolvedText {

    mutating func applying(_ matrix: ColorMatrix) {
        for index in runs.indices {
            runs[index].color = matrix.apply(runs[index].color)
        }
    }
}

extension ShapeContent {

    mutating func applying(_ matrix: ColorMatrix) {
        color = matrix.apply(color)
        if var gradient {
            for index in gradient.stops.indices {
                gradient.stops[index].color = matrix.apply(gradient.stops[index].color)
            }
            self.gradient = gradient
        }
    }
}
