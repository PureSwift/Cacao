//
//  ControlSupport.swift
//  Cacao
//
//  Created by Alsey Coleman Miller on 11/13/26.
//

import Foundation
#if canImport(CoreGraphics)
import CoreGraphics
#endif

// MARK: - Drag

internal struct _DragModifier: ViewModifier, PrimitiveViewModifier {

    let handler: DragHandler

    func resolve(content: any View, in context: ResolveContext) -> Resolution {
        var attributes = NodeAttributes()
        if context.environment.isEnabled {
            attributes.drag = handler
        }
        return Resolution(children: [ChildView(key: 0, view: content)], attributes: attributes)
    }

    typealias Body = Never
}

// MARK: - Fraction layout

/// Lays out a track, its filled part and a thumb along the horizontal axis,
/// for sliders and progress bars.
internal struct _FractionLayout: Layout {

    /// How much of the track is filled, from 0 to 1.
    let fraction: Double

    /// The track's height.
    let trackHeight: CGFloat

    /// The thumb's diameter, or 0 for none; the thumb's center travels
    /// between the track's ends inset by its radius.
    let thumbSize: CGFloat

    /// The width taken without a proposal.
    let idealWidth: CGFloat

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout Void) -> CGSize {
        let width = proposal.width.flatMap { $0.isFinite ? $0 : nil } ?? idealWidth
        return CGSize(width: width, height: max(trackHeight, thumbSize))
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout Void) {
        let fraction = min(max(fraction, 0), 1)
        let radius = thumbSize / 2
        let travel = max(bounds.width - thumbSize, 0)
        let trackY = bounds.midY - trackHeight / 2
        if subviews.count > 0 {
            subviews[0].place(
                at: CGPoint(x: bounds.minX, y: trackY),
                proposal: ProposedViewSize(width: bounds.width, height: trackHeight)
            )
        }
        if subviews.count > 1 {
            let fill = thumbSize > 0 ? radius + travel * fraction : bounds.width * fraction
            subviews[1].place(
                at: CGPoint(x: bounds.minX, y: trackY),
                proposal: ProposedViewSize(width: fill, height: trackHeight)
            )
        }
        if subviews.count > 2 {
            subviews[2].place(
                at: CGPoint(x: bounds.minX + travel * fraction, y: bounds.midY - radius),
                proposal: ProposedViewSize(width: thumbSize, height: thumbSize)
            )
        }
    }
}

// MARK: - Shapes

/// A check mark, for checkboxes and selected menu items.
internal struct _CheckmarkShape: Shape {

    nonisolated func path(in rect: CGRect) -> Path {
        Path { path in
            path.move(to: CGPoint(x: rect.minX + rect.width * 0.18, y: rect.minY + rect.height * 0.52))
            path.addLine(to: CGPoint(x: rect.minX + rect.width * 0.42, y: rect.minY + rect.height * 0.76))
            path.addLine(to: CGPoint(x: rect.minX + rect.width * 0.84, y: rect.minY + rect.height * 0.26))
        }
    }
}

/// A chevron pointing down, or right when collapsed.
internal struct _ChevronShape: Shape {

    var pointsDown = true

    var pointsLeft = false

    nonisolated func path(in rect: CGRect) -> Path {
        Path { path in
            if pointsLeft {
                path.move(to: CGPoint(x: rect.minX + rect.width * 0.65, y: rect.minY + rect.height * 0.2))
                path.addLine(to: CGPoint(x: rect.minX + rect.width * 0.35, y: rect.midY))
                path.addLine(to: CGPoint(x: rect.minX + rect.width * 0.65, y: rect.maxY - rect.height * 0.2))
            } else if pointsDown {
                path.move(to: CGPoint(x: rect.minX + rect.width * 0.2, y: rect.minY + rect.height * 0.35))
                path.addLine(to: CGPoint(x: rect.midX, y: rect.minY + rect.height * 0.65))
                path.addLine(to: CGPoint(x: rect.maxX - rect.width * 0.2, y: rect.minY + rect.height * 0.35))
            } else {
                path.move(to: CGPoint(x: rect.minX + rect.width * 0.35, y: rect.minY + rect.height * 0.2))
                path.addLine(to: CGPoint(x: rect.minX + rect.width * 0.65, y: rect.midY))
                path.addLine(to: CGPoint(x: rect.minX + rect.width * 0.35, y: rect.maxY - rect.height * 0.2))
            }
        }
    }
}

/// Part of a circle's outline, for spinners.
internal struct _ArcShape: Shape {

    /// The start and end of the arc, as fractions of a turn from the top.
    var start: Double

    var end: Double

    nonisolated func path(in rect: CGRect) -> Path {
        let radius = min(rect.width, rect.height) / 2
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let steps = max(Int((end - start) * 48), 2)
        return Path { path in
            for step in 0...steps {
                let turn = start + (end - start) * Double(step) / Double(steps)
                let angle = turn * 2 * .pi - .pi / 2
                let point = CGPoint(x: center.x + radius * CGFloat(cos(angle)), y: center.y + radius * CGFloat(sin(angle)))
                if step == 0 { path.move(to: point) } else { path.addLine(to: point) }
            }
        }
    }
}

// MARK: - Colors

extension Color {

    /// The background of controls and popups for a color scheme.
    internal static func controlBackground(_ colorScheme: ColorScheme) -> Color {
        colorScheme == .dark ? Color(white: 0.17) : Color(white: 1)
    }

    /// The raised fill of a selected segment.
    internal static func selectedSegment(_ colorScheme: ColorScheme) -> Color {
        colorScheme == .dark ? Color(white: 0.42) : Color(white: 1)
    }

    /// The fill of tracks and unselected controls.
    internal static var controlFill: Color {
        Color.gray.opacity(0.25)
    }
}

// MARK: - Tags

/// The tag trait, set with `tag(_:)`.
internal enum TagKey: LayoutValueKey {
    static var defaultValue: AnyHashable? { nil }
}

extension View {

    /// Sets the unique tag value of this view, which pickers and lists use
    /// to identify it.
    public func tag<V: Hashable>(_ tag: V) -> some View {
        var traits = LayoutTraits()
        traits[TagKey.self] = AnyHashable(tag)
        return modifier(_TraitWritingModifier(traits: traits))
    }
}

/// A picker or menu option found in content: its tag and label.
internal struct Option {
    var tag: AnyHashable?
    var label: AnyView
    /// Traits set on the option's view, such as a tab item.
    var traits = LayoutTraits()
}

/// Content whose options can be listed without evaluating it.
@MainActor
internal protocol OptionSource {
    func options() -> [Option]
}

/// The tagged options in content, from its structure: tuples, groups,
/// conditionals, `ForEach` (whose identities tag untagged rows) and views
/// with `tag(_:)`. Anything else is one untagged option.
@MainActor
internal func options(in view: any View) -> [Option] {
    if let source = view as? any OptionSource {
        return source.options()
    }
    if let forEach = view as? any LazyRowSource, !(view is any OptionSource) {
        return (0..<forEach.rowCount).flatMap { index -> [Option] in
            let row = forEach.row(at: index)
            return options(in: row.view).map { option in
                Option(tag: option.tag ?? row.id, label: option.label)
            }
        }
    }
    // Other built-in modifiers keep their content's traits, applying to
    // each of several views.
    if let modified = view as? any _ModifiedViews, modified.isPrimitive {
        let inner = options(in: modified.modifiedContent)
        guard inner.count == 1 else {
            return inner.map { option in
                var option = option
                option.label = AnyView(_fromValue: modified.applying(to: option.label))!
                return option
            }
        }
        return [Option(tag: inner[0].tag, label: AnyView(view), traits: inner[0].traits)]
    }
    return [Option(tag: nil, label: AnyView(view))]
}

extension TupleView: OptionSource {
    func options() -> [Option] { children.flatMap { Cacao.options(in: $0) } }
}

extension Group: OptionSource where Content: View {
    func options() -> [Option] { Cacao.options(in: content) }
}

extension AnyView: OptionSource {
    func options() -> [Option] { Cacao.options(in: view) }
}

extension Optional: OptionSource where Wrapped: View {
    func options() -> [Option] { map { Cacao.options(in: $0) } ?? [] }
}

extension _ConditionalContent: OptionSource {
    func options() -> [Option] {
        switch storage {
        case let .trueContent(view): Cacao.options(in: view)
        case let .falseContent(view): Cacao.options(in: view)
        }
    }
}

extension ModifiedContent: OptionSource where Content: View, Modifier == _TraitWritingModifier {
    func options() -> [Option] {
        let inner = Cacao.options(in: content)
        // A single view keeps its traits, merged with those set outside.
        guard inner.count == 1 else {
            return inner.map { option in
                var option = option
                option.traits = option.traits.merging(modifier.traits)
                option.tag = option.traits[TagKey.self] ?? option.tag
                return option
            }
        }
        let traits = inner[0].traits.merging(modifier.traits)
        return [Option(tag: traits[TagKey.self] ?? inner[0].tag, label: AnyView(self), traits: traits)]
    }
}

// MARK: - Labels hidden

private struct LabelsHiddenKey: EnvironmentKey {
    static let defaultValue = false
}

extension EnvironmentValues {

    internal var labelsHidden: Bool {
        get { self[LabelsHiddenKey.self] }
        set { self[LabelsHiddenKey.self] = newValue }
    }
}

extension View {

    /// Hides the labels of any controls contained within this view.
    public func labelsHidden() -> some View {
        environment(\.labelsHidden, true)
    }
}
