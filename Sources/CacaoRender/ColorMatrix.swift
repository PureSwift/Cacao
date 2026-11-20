//
//  ColorMatrix.swift
//  CacaoRender
//
//  Created by Alsey Coleman Miller on 11/13/26.
//

import Foundation
#if canImport(CoreGraphics)
import CoreGraphics
#endif

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

    package init(rows: [[Float]]) {
        (r1, r2, r3, r4, r5) = (rows[0][0], rows[0][1], rows[0][2], rows[0][3], rows[0][4])
        (g1, g2, g3, g4, g5) = (rows[1][0], rows[1][1], rows[1][2], rows[1][3], rows[1][4])
        (b1, b2, b3, b4, b5) = (rows[2][0], rows[2][1], rows[2][2], rows[2][3], rows[2][4])
        (a1, a2, a3, a4, a5) = (rows[3][0], rows[3][1], rows[3][2], rows[3][3], rows[3][4])
    }

    package var rows: [[Float]] {
        [[r1, r2, r3, r4, r5], [g1, g2, g3, g4, g5], [b1, b2, b3, b4, b5], [a1, a2, a3, a4, a5]]
    }

    /// The matrix that applies `self`, then `other`.
    public func then(_ other: ColorMatrix) -> ColorMatrix {
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
    public func apply(_ color: ResolvedColor) -> ResolvedColor {
        let r = color.red, g = color.green, b = color.blue, a = color.opacity
        func clamp(_ value: Float) -> Float { max(0, min(1, value)) }
        return ResolvedColor(
            red: clamp(r1 * r + r2 * g + r3 * b + r4 * a + r5),
            green: clamp(g1 * r + g2 * g + g3 * b + g4 * a + g5),
            blue: clamp(b1 * r + b2 * g + b3 * b + b4 * a + b5),
            opacity: clamp(a1 * r + a2 * g + a3 * b + a4 * a + a5)
        )
    }

    // Luminance weights (Rec. 709), as in SVG's filter matrices.
    private static let lr: Float = 0.2126, lg: Float = 0.7152, lb: Float = 0.0722

    package static func brightness(_ amount: Double) -> ColorMatrix {
        let value = Float(amount)
        var matrix = ColorMatrix()
        matrix.r5 = value; matrix.g5 = value; matrix.b5 = value
        return matrix
    }

    package static func contrast(_ amount: Double) -> ColorMatrix {
        let value = Float(amount), offset = (1 - Float(amount)) / 2
        return ColorMatrix(rows: [
            [value, 0, 0, 0, offset],
            [0, value, 0, 0, offset],
            [0, 0, value, 0, offset],
            [0, 0, 0, 1, 0],
        ])
    }

    package static func saturation(_ amount: Double) -> ColorMatrix {
        let s = Float(amount), t = 1 - s
        return ColorMatrix(rows: [
            [lr * t + s, lg * t, lb * t, 0, 0],
            [lr * t, lg * t + s, lb * t, 0, 0],
            [lr * t, lg * t, lb * t + s, 0, 0],
            [0, 0, 0, 1, 0],
        ])
    }

    package static var invert: ColorMatrix {
        ColorMatrix(rows: [
            [-1, 0, 0, 0, 1],
            [0, -1, 0, 0, 1],
            [0, 0, -1, 0, 1],
            [0, 0, 0, 1, 0],
        ])
    }

    package static func multiply(_ color: ResolvedColor) -> ColorMatrix {
        ColorMatrix(rows: [
            [color.red, 0, 0, 0, 0],
            [0, color.green, 0, 0, 0],
            [0, 0, color.blue, 0, 0],
            [0, 0, 0, color.opacity, 0],
        ])
    }

    package static var luminanceToAlpha: ColorMatrix {
        ColorMatrix(rows: [
            [0, 0, 0, 0, 0],
            [0, 0, 0, 0, 0],
            [0, 0, 0, 0, 0],
            [lr, lg, lb, 0, 0],
        ])
    }
}

// MARK: - Applying matrices to drawing

extension DisplayList.Item {

    /// The item with its colors, and its nested items' colors, transformed.
    public func applying(_ matrix: ColorMatrix) -> DisplayList.Item {
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

    public func applying(_ matrix: ColorMatrix) -> DisplayList.Content {
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
        case let .drawing(drawing):
            return .drawing(drawing.applying(matrix))
        case .external, .backdrop:
            // Frames drawn elsewhere, and what a backdrop shows of what's
            // behind it, keep their colors.
            return self
        }
    }
}

extension DrawingContent {

    /// The drawing with its colors transformed.
    public func applying(_ matrix: ColorMatrix) -> DrawingContent {
        func image(_ image: ImageContent) -> ImageContent {
            var image = image
            image.colorMatrix = image.colorMatrix.map { $0.then(matrix) } ?? matrix
            return image
        }
        return DrawingContent(operations: operations.map { operation in
            switch operation {
            case .shape(var shape, let state):
                shape.applying(matrix)
                return .shape(shape, state)
            case .text(var text, let rect, let state):
                text.applying(matrix)
                return .text(text, rect, state)
            case let .image(content, rect, state):
                return .image(image(content), rect, state)
            case let .tiledImage(path, isEOFilled, content, origin, scale, state):
                return .tiledImage(path, isEOFilled: isEOFilled, image(content), origin: origin, scale: scale, state)
            case let .items(items, state):
                return .items(items.map { $0.applying(matrix) }, state)
            case let .layer(content, state):
                return .layer(content.applying(matrix), state)
            }
        })
    }
}

extension ResolvedText {

    package mutating func applying(_ matrix: ColorMatrix) {
        for index in runs.indices {
            runs[index].color = matrix.apply(runs[index].color)
        }
    }
}

extension ShapeContent {

    package mutating func applying(_ matrix: ColorMatrix) {
        color = matrix.apply(color)
        if var gradient {
            for index in gradient.stops.indices {
                gradient.stops[index].color = matrix.apply(gradient.stops[index].color)
            }
            self.gradient = gradient
        }
    }
}
