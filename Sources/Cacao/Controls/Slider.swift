//
//  Slider.swift
//  Cacao
//
//  Created by Alsey Coleman Miller on 11/13/26.
//

import Foundation
#if canImport(CoreGraphics)
import CoreGraphics
#endif

/// A control for selecting a value from a bounded linear range of values.
public struct Slider<Label: View, ValueLabel: View>: View {

    internal let fraction: Binding<Double>

    internal let step: Double?

    internal let label: Label

    internal let minimumValueLabel: ValueLabel?

    internal let maximumValueLabel: ValueLabel?

    internal let onEditingChanged: (Bool) -> Void

    public var body: some View {
        _SliderBody(
            fraction: fraction,
            step: step,
            label: AnyView(label),
            minimumValueLabel: minimumValueLabel.map { AnyView($0) },
            maximumValueLabel: maximumValueLabel.map { AnyView($0) },
            onEditingChanged: onEditingChanged
        )
    }
}

extension Slider {

    /// Creates a slider to select a value from a given range, which displays
    /// the provided labels.
    public init<V: BinaryFloatingPoint>(
        value: Binding<V>,
        in bounds: ClosedRange<V> = 0...1,
        step: V.Stride? = nil,
        @ViewBuilder label: () -> Label,
        @ViewBuilder minimumValueLabel: () -> ValueLabel,
        @ViewBuilder maximumValueLabel: () -> ValueLabel,
        onEditingChanged: @escaping (Bool) -> Void = { _ in }
    ) where V.Stride: BinaryFloatingPoint {
        self.fraction = Self.fraction(of: value, in: bounds)
        self.step = step.map { Double($0) / Double(bounds.upperBound - bounds.lowerBound) }
        self.label = label()
        self.minimumValueLabel = minimumValueLabel()
        self.maximumValueLabel = maximumValueLabel()
        self.onEditingChanged = onEditingChanged
    }

    /// A binding to a value's position within bounds, from 0 to 1.
    internal static func fraction<V: BinaryFloatingPoint>(of value: Binding<V>, in bounds: ClosedRange<V>) -> Binding<Double> {
        let span = Double(bounds.upperBound - bounds.lowerBound)
        return Binding(
            get: { span > 0 ? (Double(value.wrappedValue) - Double(bounds.lowerBound)) / span : 0 },
            set: { value.wrappedValue = V(Double(bounds.lowerBound) + $0 * span) }
        )
    }
}

extension Slider where ValueLabel == EmptyView {

    /// Creates a slider to select a value from a given range, which displays
    /// the provided label.
    public init<V: BinaryFloatingPoint>(
        value: Binding<V>,
        in bounds: ClosedRange<V> = 0...1,
        step: V.Stride? = nil,
        @ViewBuilder label: () -> Label,
        onEditingChanged: @escaping (Bool) -> Void = { _ in }
    ) where V.Stride: BinaryFloatingPoint {
        self.fraction = Self.fraction(of: value, in: bounds)
        self.step = step.map { Double($0) / Double(bounds.upperBound - bounds.lowerBound) }
        self.label = label()
        self.minimumValueLabel = nil
        self.maximumValueLabel = nil
        self.onEditingChanged = onEditingChanged
    }
}

extension Slider where Label == EmptyView, ValueLabel == EmptyView {

    /// Creates a slider to select a value from a given range.
    public init<V: BinaryFloatingPoint>(
        value: Binding<V>,
        in bounds: ClosedRange<V> = 0...1,
        step: V.Stride? = nil,
        onEditingChanged: @escaping (Bool) -> Void = { _ in }
    ) where V.Stride: BinaryFloatingPoint {
        self.init(value: value, in: bounds, step: step, label: { EmptyView() }, onEditingChanged: onEditingChanged)
    }
}

private struct _SliderBody: View {

    let fraction: Binding<Double>

    let step: Double?

    let label: AnyView

    let minimumValueLabel: AnyView?

    let maximumValueLabel: AnyView?

    let onEditingChanged: (Bool) -> Void

    static let thumb: CGFloat = 20

    @Environment(\.isEnabled) private var isEnabled

    @Environment(\.labelsHidden) private var labelsHidden

    var body: some View {
        HStack(spacing: 8) {
            if !labelsHidden {
                label
            }
            if let minimumValueLabel {
                minimumValueLabel
            }
            _FractionLayout(fraction: fraction.wrappedValue, trackHeight: 4, thumbSize: Self.thumb, idealWidth: 160) {
                Capsule().fill(Color.controlFill)
                Capsule().fill(isEnabled ? Color.accentColor : Color.gray)
                Circle()
                    .fill(.white)
                    .overlay { Circle().strokeBorder(Color.gray.opacity(0.4), lineWidth: 1) }
            }
            .contentShape(Rectangle())
            .modifier(_DragModifier(handler: DragHandler(
                onChanged: { start, location, frame in
                    if start == location {
                        onEditingChanged(true)
                    }
                    fraction.wrappedValue = value(at: location, in: frame)
                },
                onEnded: { _, location, frame in
                    fraction.wrappedValue = value(at: location, in: frame)
                    onEditingChanged(false)
                }
            )))
            if let maximumValueLabel {
                maximumValueLabel
            }
        }
    }

    /// The fraction under a point, snapped to the step.
    private func value(at location: CGPoint, in frame: CGRect) -> Double {
        let travel = max(frame.width - Self.thumb, 1)
        var value = Double((location.x - frame.minX - Self.thumb / 2) / travel)
        value = min(max(value, 0), 1)
        if let step, step > 0 {
            value = (value / step).rounded() * step
        }
        return value
    }
}
