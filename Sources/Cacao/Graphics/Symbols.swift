//
//  Symbols.swift
//  Cacao
//
//  Created by Alsey Coleman Miller on 11/13/26.
//

import Foundation
#if canImport(CoreGraphics)
import CoreGraphics
#endif

/// Cacao's own drawings for common system symbol names, in a unit square,
/// drawn in the foreground style at the size of the current font.
internal enum Symbols {

    /// One part of a symbol: a stroked or filled path, in the foreground
    /// style or knocked out in white.
    struct Part {
        var path: Path
        var isFilled: Bool
        var isKnockout = false
    }

    /// The parts of a symbol, or nil for a name Cacao doesn't draw.
    static func parts(_ name: String) -> [Part]? {
        var name = name
        var filled = false
        if name.hasSuffix(".fill") {
            filled = true
            name.removeLast(5)
        }
        // A shape enclosing a glyph: the glyph knocked out of a filled shape.
        for (suffix, enclosure) in [(".circle", Path(ellipseIn: unit.insetBy(dx: 0.04, dy: 0.04))),
                                    (".square", Path(roundedRect: unit.insetBy(dx: 0.06, dy: 0.06), cornerRadius: 0.18))]
        where name.hasSuffix(suffix) && name != suffix.dropFirst() {
            let glyph = String(name.dropLast(suffix.count))
            guard let inner = glyphs(glyph, filled: false) else { return nil }
            let scaled = inner.map { part -> Part in
                var part = part
                part.path = part.path.applying(.translation(-0.5, -0.5).concatenating(.scale(0.55, 0.55)).concatenating(.translation(0.5, 0.5)))
                part.isKnockout = filled
                return part
            }
            return [Part(path: enclosure, isFilled: filled)] + scaled
        }
        return glyphs(name, filled: filled)
    }

    static let unit = CGRect(x: 0, y: 0, width: 1, height: 1)

    private static func point(_ x: CGFloat, _ y: CGFloat) -> CGPoint { CGPoint(x: x, y: y) }

    private static func lines(_ points: [(CGFloat, CGFloat)], closed: Bool = false) -> Path {
        Path { path in
            path.addLines(points.map { point($0.0, $0.1) })
            if closed { path.closeSubpath() }
        }
    }

    /// An arc around a center, in turns clockwise from the top.
    private static func arc(center: CGPoint, radius: CGFloat, from start: Double, to end: Double, path: inout Path, move: Bool = true) {
        let steps = max(Int(abs(end - start) * 64), 2)
        for step in 0...steps {
            let turn = start + (end - start) * Double(step) / Double(steps)
            let angle = turn * 2 * .pi - .pi / 2
            let p = point(center.x + radius * CGFloat(cos(angle)), center.y + radius * CGFloat(sin(angle)))
            if step == 0 && move { path.move(to: p) } else { path.addLine(to: p) }
        }
    }

    private static func star() -> Path {
        Path { path in
            for index in 0..<10 {
                let angle = Double(index) * .pi / 5 - .pi / 2
                let radius: CGFloat = index % 2 == 0 ? 0.5 : 0.22
                let p = point(0.5 + radius * CGFloat(cos(angle)), 0.54 + radius * CGFloat(sin(angle)))
                if index == 0 { path.move(to: p) } else { path.addLine(to: p) }
            }
            path.closeSubpath()
        }
    }

    private static func heart() -> Path {
        Path { path in
            path.move(to: point(0.5, 0.9))
            path.addCurve(to: point(0.05, 0.35), control1: point(0.2, 0.68), control2: point(0.05, 0.55))
            path.addCurve(to: point(0.5, 0.22), control1: point(0.05, 0.08), control2: point(0.4, 0.05))
            path.addCurve(to: point(0.95, 0.35), control1: point(0.6, 0.05), control2: point(0.95, 0.08))
            path.addCurve(to: point(0.5, 0.9), control1: point(0.95, 0.55), control2: point(0.8, 0.68))
            path.closeSubpath()
        }
    }

    private static func gear(filled: Bool) -> [Part] {
        let outline = Path { path in
            let teeth = 8
            for index in 0..<(teeth * 4) {
                let angle = Double(index) / Double(teeth * 4) * 2 * .pi
                let radius: CGFloat = (index % 4 == 1 || index % 4 == 2) ? 0.48 : 0.38
                let p = point(0.5 + radius * CGFloat(cos(angle)), 0.5 + radius * CGFloat(sin(angle)))
                if index == 0 { path.move(to: p) } else { path.addLine(to: p) }
            }
            path.closeSubpath()
        }
        let hole = Path(ellipseIn: CGRect(x: 0.36, y: 0.36, width: 0.28, height: 0.28))
        return [Part(path: outline, isFilled: filled), Part(path: hole, isFilled: false, isKnockout: filled)]
    }

    /// The glyphs themselves, outlined or filled.
    private static func glyphs(_ name: String, filled: Bool) -> [Part]? {
        func stroke(_ path: Path) -> [Part] { [Part(path: path, isFilled: false)] }
        func shape(_ path: Path) -> [Part] { [Part(path: path, isFilled: filled)] }
        switch name {
        case "chevron.left", "chevron.backward":
            return stroke(lines([(0.68, 0.12), (0.3, 0.5), (0.68, 0.88)]))
        case "chevron.right", "chevron.forward":
            return stroke(lines([(0.32, 0.12), (0.7, 0.5), (0.32, 0.88)]))
        case "chevron.up":
            return stroke(lines([(0.12, 0.68), (0.5, 0.3), (0.88, 0.68)]))
        case "chevron.down":
            return stroke(lines([(0.12, 0.32), (0.5, 0.7), (0.88, 0.32)]))
        case "plus":
            return stroke(Path { $0.addLines([point(0.5, 0.1), point(0.5, 0.9)]); $0.addLines([point(0.1, 0.5), point(0.9, 0.5)]) })
        case "minus":
            return stroke(lines([(0.1, 0.5), (0.9, 0.5)]))
        case "xmark", "multiply":
            return stroke(Path { $0.addLines([point(0.18, 0.18), point(0.82, 0.82)]); $0.addLines([point(0.82, 0.18), point(0.18, 0.82)]) })
        case "checkmark":
            return stroke(lines([(0.12, 0.55), (0.4, 0.82), (0.88, 0.2)]))
        case "circle":
            return shape(Path(ellipseIn: unit.insetBy(dx: 0.06, dy: 0.06)))
        case "square":
            return shape(Path(roundedRect: unit.insetBy(dx: 0.08, dy: 0.08), cornerRadius: 0.14))
        case "star":
            return shape(star())
        case "heart":
            return shape(heart())
        case "magnifyingglass":
            return stroke(Path { path in
                path.addEllipse(in: CGRect(x: 0.08, y: 0.08, width: 0.56, height: 0.56))
                path.addLines([point(0.56, 0.56), point(0.9, 0.9)])
            })
        case "gear", "gearshape":
            return gear(filled: filled)
        case "house":
            return shape(lines([(0.5, 0.08), (0.92, 0.48), (0.8, 0.48), (0.8, 0.9), (0.2, 0.9), (0.2, 0.48), (0.08, 0.48)], closed: true))
        case "person":
            return [
                Part(path: Path(ellipseIn: CGRect(x: 0.3, y: 0.06, width: 0.4, height: 0.4)), isFilled: filled),
                Part(path: Path { path in
                    path.move(to: point(0.1, 0.94))
                    path.addCurve(to: point(0.9, 0.94), control1: point(0.1, 0.5), control2: point(0.9, 0.5))
                    path.closeSubpath()
                }, isFilled: filled),
            ]
        case "trash":
            return [
                Part(path: lines([(0.08, 0.2), (0.92, 0.2)]), isFilled: false),
                Part(path: lines([(0.36, 0.2), (0.4, 0.08), (0.6, 0.08), (0.64, 0.2)]), isFilled: false),
                Part(path: lines([(0.18, 0.2), (0.24, 0.92), (0.76, 0.92), (0.82, 0.2)], closed: true), isFilled: filled),
            ]
        case "folder":
            return shape(lines([(0.06, 0.18), (0.4, 0.18), (0.48, 0.3), (0.94, 0.3), (0.94, 0.86), (0.06, 0.86)], closed: true))
        case "doc":
            return shape(lines([(0.18, 0.06), (0.6, 0.06), (0.84, 0.3), (0.84, 0.94), (0.18, 0.94)], closed: true))
        case "envelope":
            return [
                Part(path: Path(roundedRect: CGRect(x: 0.06, y: 0.2, width: 0.88, height: 0.6), cornerRadius: 0.08), isFilled: filled),
                Part(path: lines([(0.08, 0.24), (0.5, 0.56), (0.92, 0.24)]), isFilled: false, isKnockout: filled),
            ]
        case "bell":
            return shape(Path { path in
                path.move(to: point(0.12, 0.76))
                path.addLine(to: point(0.22, 0.6))
                path.addCurve(to: point(0.5, 0.1), control1: point(0.22, 0.25), control2: point(0.32, 0.1))
                path.addCurve(to: point(0.78, 0.6), control1: point(0.68, 0.1), control2: point(0.78, 0.25))
                path.addLine(to: point(0.88, 0.76))
                path.closeSubpath()
                path.addEllipse(in: CGRect(x: 0.4, y: 0.8, width: 0.2, height: 0.14))
            })
        case "info":
            return [
                Part(path: Path(ellipseIn: CGRect(x: 0.42, y: 0.08, width: 0.16, height: 0.16)), isFilled: true),
                Part(path: lines([(0.5, 0.38), (0.5, 0.92)]), isFilled: false),
            ]
        case "exclamationmark":
            return [
                Part(path: lines([(0.5, 0.08), (0.5, 0.62)]), isFilled: false),
                Part(path: Path(ellipseIn: CGRect(x: 0.42, y: 0.78, width: 0.16, height: 0.16)), isFilled: true),
            ]
        case "questionmark":
            return [
                Part(path: Path { path in
                    arc(center: point(0.5, 0.32), radius: 0.22, from: -0.25, to: 0.3, path: &path)
                    path.addLine(to: point(0.5, 0.6))
                    path.addLine(to: point(0.5, 0.68))
                }, isFilled: false),
                Part(path: Path(ellipseIn: CGRect(x: 0.42, y: 0.8, width: 0.16, height: 0.16)), isFilled: true),
            ]
        case "exclamationmark.triangle":
            return [
                Part(path: lines([(0.5, 0.06), (0.96, 0.9), (0.04, 0.9)], closed: true), isFilled: filled),
                Part(path: lines([(0.5, 0.36), (0.5, 0.62)]), isFilled: false, isKnockout: filled),
                Part(path: Path(ellipseIn: CGRect(x: 0.45, y: 0.7, width: 0.1, height: 0.1)), isFilled: true, isKnockout: filled),
            ]
        case "ellipsis":
            return [Part(path: Path { path in
                for x in [0.1, 0.42, 0.74] as [CGFloat] {
                    path.addEllipse(in: CGRect(x: x, y: 0.42, width: 0.16, height: 0.16))
                }
            }, isFilled: true)]
        case "line.3.horizontal", "line.horizontal.3":
            return stroke(Path { path in
                for y in [0.2, 0.5, 0.8] as [CGFloat] { path.addLines([point(0.1, y), point(0.9, y)]) }
            })
        case "list.bullet":
            return [
                Part(path: Path { path in
                    for y in [0.2, 0.5, 0.8] as [CGFloat] { path.addEllipse(in: CGRect(x: 0.06, y: y - 0.06, width: 0.12, height: 0.12)) }
                }, isFilled: true),
                Part(path: Path { path in
                    for y in [0.2, 0.5, 0.8] as [CGFloat] { path.addLines([point(0.32, y), point(0.94, y)]) }
                }, isFilled: false),
            ]
        case "arrow.left", "arrow.backward":
            return stroke(Path { $0.addLines([point(0.9, 0.5), point(0.1, 0.5)]); $0.addLines([point(0.42, 0.18), point(0.1, 0.5), point(0.42, 0.82)]) })
        case "arrow.right", "arrow.forward":
            return stroke(Path { $0.addLines([point(0.1, 0.5), point(0.9, 0.5)]); $0.addLines([point(0.58, 0.18), point(0.9, 0.5), point(0.58, 0.82)]) })
        case "arrow.up":
            return stroke(Path { $0.addLines([point(0.5, 0.9), point(0.5, 0.1)]); $0.addLines([point(0.18, 0.42), point(0.5, 0.1), point(0.82, 0.42)]) })
        case "arrow.down":
            return stroke(Path { $0.addLines([point(0.5, 0.1), point(0.5, 0.9)]); $0.addLines([point(0.18, 0.58), point(0.5, 0.9), point(0.82, 0.58)]) })
        case "arrow.clockwise", "arrow.counterclockwise":
            let clockwise = name == "arrow.clockwise"
            return stroke(Path { path in
                arc(center: point(0.5, 0.54), radius: 0.36, from: clockwise ? 0.08 : -0.08, to: clockwise ? 0.9 : -0.9, path: &path)
                let tip = clockwise ? point(0.62, 0.2) : point(0.38, 0.2)
                path.addLines([point(tip.x + (clockwise ? -0.16 : 0.16), 0.06), tip, point(tip.x + (clockwise ? -0.14 : 0.14), 0.34)])
            })
        case "play":
            return shape(lines([(0.18, 0.08), (0.9, 0.5), (0.18, 0.92)], closed: true))
        case "pause":
            return shape(Path { $0.addRect(CGRect(x: 0.18, y: 0.1, width: 0.22, height: 0.8)); $0.addRect(CGRect(x: 0.6, y: 0.1, width: 0.22, height: 0.8)) })
        case "stop":
            return shape(Path(roundedRect: CGRect(x: 0.14, y: 0.14, width: 0.72, height: 0.72), cornerRadius: 0.08))
        case "sidebar.left", "sidebar.right":
            let x: CGFloat = name == "sidebar.left" ? 0.38 : 0.62
            return [
                Part(path: Path(roundedRect: CGRect(x: 0.06, y: 0.16, width: 0.88, height: 0.68), cornerRadius: 0.12), isFilled: false),
                Part(path: lines([(x, 0.16), (x, 0.84)]), isFilled: false),
            ]
        case "square.and.arrow.up":
            return [
                Part(path: lines([(0.32, 0.36), (0.16, 0.36), (0.16, 0.94), (0.84, 0.94), (0.84, 0.36), (0.68, 0.36)]), isFilled: false),
                Part(path: Path { $0.addLines([point(0.5, 0.62), point(0.5, 0.06)]); $0.addLines([point(0.3, 0.24), point(0.5, 0.06), point(0.7, 0.24)]) }, isFilled: false),
            ]
        case "calendar":
            return [
                Part(path: Path(roundedRect: CGRect(x: 0.06, y: 0.12, width: 0.88, height: 0.8), cornerRadius: 0.1), isFilled: filled),
                Part(path: lines([(0.06, 0.34), (0.94, 0.34)]), isFilled: false, isKnockout: filled),
            ]
        case "clock":
            return [
                Part(path: Path(ellipseIn: unit.insetBy(dx: 0.06, dy: 0.06)), isFilled: filled),
                Part(path: lines([(0.5, 0.22), (0.5, 0.5), (0.7, 0.62)]), isFilled: false, isKnockout: filled),
            ]
        case "pencil":
            return shape(lines([(0.72, 0.08), (0.92, 0.28), (0.32, 0.88), (0.08, 0.92), (0.12, 0.68)], closed: true))
        case "photo":
            return [
                Part(path: Path(roundedRect: CGRect(x: 0.06, y: 0.14, width: 0.88, height: 0.72), cornerRadius: 0.08), isFilled: filled),
                Part(path: lines([(0.12, 0.8), (0.4, 0.46), (0.6, 0.66), (0.72, 0.54), (0.88, 0.8)]), isFilled: false, isKnockout: filled),
            ]
        case "globe":
            return stroke(Path { path in
                path.addEllipse(in: unit.insetBy(dx: 0.06, dy: 0.06))
                path.addEllipse(in: CGRect(x: 0.3, y: 0.06, width: 0.4, height: 0.88))
                path.addLines([point(0.06, 0.5), point(0.94, 0.5)])
            })
        case "lock":
            return [
                Part(path: Path(roundedRect: CGRect(x: 0.14, y: 0.44, width: 0.72, height: 0.5), cornerRadius: 0.08), isFilled: filled),
                Part(path: Path { path in
                    path.move(to: point(0.28, 0.44))
                    path.addLine(to: point(0.28, 0.3))
                    arc(center: point(0.5, 0.3), radius: 0.22, from: -0.25, to: 0.25, path: &path, move: false)
                    path.addLine(to: point(0.72, 0.44))
                }, isFilled: false),
            ]
        case "sun.max":
            return [
                Part(path: Path(ellipseIn: CGRect(x: 0.3, y: 0.3, width: 0.4, height: 0.4)), isFilled: filled),
                Part(path: Path { path in
                    for index in 0..<8 {
                        let angle = Double(index) * .pi / 4
                        let (c, s) = (CGFloat(cos(angle)), CGFloat(sin(angle)))
                        path.addLines([point(0.5 + 0.32 * c, 0.5 + 0.32 * s), point(0.5 + 0.46 * c, 0.5 + 0.46 * s)])
                    }
                }, isFilled: false),
            ]
        case "moon":
            // A crescent opening to the trailing side.
            return shape(Path { path in
                arc(center: point(0.5, 0.5), radius: 0.42, from: 0, to: -0.5, path: &path)
                path.addQuadCurve(to: point(0.5, 0.08), control: point(0.22, 0.5))
                path.closeSubpath()
            })
        case "bolt":
            return shape(lines([(0.58, 0.04), (0.18, 0.56), (0.48, 0.56), (0.4, 0.96), (0.82, 0.42), (0.52, 0.42)], closed: true))
        case "cart":
            return [
                Part(path: lines([(0.04, 0.14), (0.18, 0.14), (0.3, 0.66), (0.84, 0.66), (0.94, 0.3), (0.24, 0.3)]), isFilled: false),
                Part(path: Path { $0.addEllipse(in: CGRect(x: 0.28, y: 0.76, width: 0.14, height: 0.14)); $0.addEllipse(in: CGRect(x: 0.7, y: 0.76, width: 0.14, height: 0.14)) }, isFilled: true),
            ]
        case "tray":
            return stroke(lines([(0.06, 0.56), (0.06, 0.88), (0.94, 0.88), (0.94, 0.56), (0.66, 0.56), (0.6, 0.68), (0.4, 0.68), (0.34, 0.56), (0.06, 0.56)]))
        case "paperplane":
            return shape(lines([(0.06, 0.46), (0.94, 0.08), (0.62, 0.94), (0.46, 0.58)], closed: true))
        case "bookmark":
            return shape(lines([(0.2, 0.06), (0.8, 0.06), (0.8, 0.94), (0.5, 0.7), (0.2, 0.94)], closed: true))
        case "tag":
            return shape(lines([(0.06, 0.08), (0.5, 0.08), (0.94, 0.52), (0.52, 0.94), (0.06, 0.5)], closed: true))
        case "flag":
            return [
                Part(path: lines([(0.14, 0.94), (0.14, 0.08)]), isFilled: false),
                Part(path: lines([(0.14, 0.1), (0.86, 0.1), (0.72, 0.32), (0.86, 0.54), (0.14, 0.54)], closed: true), isFilled: filled),
            ]
        case "eye":
            return [
                Part(path: Path { path in
                    path.move(to: point(0.04, 0.5))
                    path.addQuadCurve(to: point(0.96, 0.5), control: point(0.5, -0.1))
                    path.addQuadCurve(to: point(0.04, 0.5), control: point(0.5, 1.1))
                    path.closeSubpath()
                }, isFilled: filled),
                Part(path: Path(ellipseIn: CGRect(x: 0.36, y: 0.36, width: 0.28, height: 0.28)), isFilled: true, isKnockout: filled),
            ]
        default:
            return nil
        }
    }

    /// The symbol drawn in a rectangle: its parts, scaled, in a color or
    /// gradient, with strokes of a weight.
    static func drawing(_ parts: [Part], in rect: CGRect, color: Color.Resolved, gradient: GradientPaint?, weight: Int) -> DrawingContent {
        let lineWidth = 0.085 * (0.7 + CGFloat(weight) / 1000)
        var state = DrawingState()
        state.transform = Transform2D.scale(rect.width, rect.height).concatenating(.translation(rect.minX, rect.minY))
        let white = Color.Resolved(red: 1, green: 1, blue: 1)
        // Gradients are in the rectangle's space; parts are in the unit square.
        let unitGradient = gradient.map { GradientPaint(stops: $0.stops, geometry: $0.geometry.unscaled(from: rect)) }
        return DrawingContent(operations: parts.map { part in
            let style = StrokeStyle(lineWidth: lineWidth, lineCap: .round, lineJoin: .round)
            let content = ShapeContent(
                path: part.path,
                color: part.isKnockout ? white : color,
                drawing: part.isFilled ? .fill(FillStyle()) : .stroke(style),
                gradient: part.isKnockout ? nil : unitGradient
            )
            return .shape(content, state)
        })
    }
}

extension GradientPaint.Geometry {

    /// The geometry in a unit square drawn stretched over `rect`.
    func unscaled(from rect: CGRect) -> GradientPaint.Geometry {
        func map(_ point: CGPoint) -> CGPoint {
            CGPoint(x: (point.x - rect.minX) / max(rect.width, 0.001), y: (point.y - rect.minY) / max(rect.height, 0.001))
        }
        switch self {
        case let .axial(start, end):
            return .axial(start: map(start), end: map(end))
        case let .radial(center, startRadius, endRadius, scaleY):
            let width = max(rect.width, 0.001)
            return .radial(center: map(center), startRadius: startRadius / width, endRadius: endRadius / width, scaleY: scaleY * rect.height / width)
        case let .conic(center, startAngle, endAngle):
            return .conic(center: map(center), startAngle: startAngle, endAngle: endAngle)
        }
    }
}

/// Draws a system symbol in its frame.
internal struct SymbolBehavior: NodeBehavior {

    let parts: [Symbols.Part]?

    let isResizable: Bool

    let size: CGFloat

    let color: Color.Resolved

    let gradient: GradientStyle?

    let weight: Int

    func sizeThatFits(_ proposal: ProposedViewSize, node: ViewNode) -> CGSize {
        let natural = CGSize(width: size, height: size)
        return isResizable ? proposal.replacingUnspecifiedDimensions(by: natural) : natural
    }

    func displayContent(node: ViewNode) -> DisplayList.Content? {
        guard let parts else { return nil }
        let bounds = CGRect(origin: CGPoint(x: 0, y: 0), size: node.graph.presentationFrame(of: node).size)
        return .drawing(Symbols.drawing(parts, in: bounds, color: color, gradient: gradient?.paint(in: bounds), weight: weight))
    }
}
