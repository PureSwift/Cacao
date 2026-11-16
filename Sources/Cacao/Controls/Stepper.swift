//
//  Stepper.swift
//  Cacao
//
//  Created by Alsey Coleman Miller on 11/13/26.
//

import Foundation
#if canImport(CoreGraphics)
import CoreGraphics
#endif

/// A control that performs increment and decrement actions.
public struct Stepper<Label: View>: View {

    internal let label: Label

    internal let onIncrement: (() -> Void)?

    internal let onDecrement: (() -> Void)?

    /// Creates a stepper instance that performs the closures you provide
    /// when the user increments or decrements the stepper.
    public init(
        @ViewBuilder label: () -> Label,
        onIncrement: (() -> Void)?,
        onDecrement: (() -> Void)?,
        onEditingChanged: @escaping (Bool) -> Void = { _ in }
    ) {
        self.label = label()
        self.onIncrement = onIncrement
        self.onDecrement = onDecrement
    }

    /// Creates a stepper instance that performs the closures you provide
    /// when the user increments or decrements the stepper.
    public init(
        onIncrement: (() -> Void)?,
        onDecrement: (() -> Void)?,
        onEditingChanged: @escaping (Bool) -> Void = { _ in },
        @ViewBuilder label: () -> Label
    ) {
        self.label = label()
        self.onIncrement = onIncrement
        self.onDecrement = onDecrement
    }

    /// Creates a stepper configured to increment or decrement a binding to a
    /// value using a step value and within a range of values.
    public init<V: Strideable>(
        value: Binding<V>,
        in bounds: ClosedRange<V>,
        step: V.Stride = 1,
        @ViewBuilder label: () -> Label,
        onEditingChanged: @escaping (Bool) -> Void = { _ in }
    ) {
        self.label = label()
        self.onIncrement = value.wrappedValue < bounds.upperBound ? {
            value.wrappedValue = min(value.wrappedValue.advanced(by: step), bounds.upperBound)
        } : nil
        self.onDecrement = value.wrappedValue > bounds.lowerBound ? {
            value.wrappedValue = max(value.wrappedValue.advanced(by: -step), bounds.lowerBound)
        } : nil
    }

    /// Creates a stepper configured to increment or decrement a binding to a
    /// value using a step value.
    public init<V: Strideable>(
        value: Binding<V>,
        step: V.Stride = 1,
        @ViewBuilder label: () -> Label,
        onEditingChanged: @escaping (Bool) -> Void = { _ in }
    ) {
        self.label = label()
        self.onIncrement = { value.wrappedValue = value.wrappedValue.advanced(by: step) }
        self.onDecrement = { value.wrappedValue = value.wrappedValue.advanced(by: -step) }
    }

    public var body: some View {
        _StepperBody(label: AnyView(label), onIncrement: onIncrement, onDecrement: onDecrement)
    }
}

extension Stepper where Label == Text {

    /// Creates a stepper with a title and a binding to a value in a range.
    public init<V: Strideable>(
        _ titleKey: LocalizedStringKey,
        value: Binding<V>,
        in bounds: ClosedRange<V>,
        step: V.Stride = 1,
        onEditingChanged: @escaping (Bool) -> Void = { _ in }
    ) {
        self.init(value: value, in: bounds, step: step, label: { Text(titleKey) }, onEditingChanged: onEditingChanged)
    }

    /// Creates a stepper with a title and a binding to a value.
    public init<V: Strideable>(
        _ titleKey: LocalizedStringKey,
        value: Binding<V>,
        step: V.Stride = 1,
        onEditingChanged: @escaping (Bool) -> Void = { _ in }
    ) {
        self.init(value: value, step: step, label: { Text(titleKey) }, onEditingChanged: onEditingChanged)
    }
}

private struct _StepperBody: View {

    let label: AnyView

    let onIncrement: (() -> Void)?

    let onDecrement: (() -> Void)?

    @Environment(\.labelsHidden) private var labelsHidden

    var body: some View {
        HStack {
            if !labelsHidden {
                label
                Spacer()
            }
            HStack(spacing: 0) {
                segment("−", action: onDecrement)
                Divider().frame(height: 18)
                segment("+", action: onIncrement)
            }
            .background { RoundedRectangle(cornerRadius: 6).fill(Color.controlFill) }
            .fixedSize()
        }
    }

    private func segment(_ title: String, action: (() -> Void)?) -> some View {
        Button(action: { action?() }) {
            Text(title)
                .font(.body.weight(.medium))
                .frame(width: 32, height: 26)
        }
        .buttonStyle(.plain)
        .disabled(action == nil)
        .opacity(action == nil ? 0.4 : 1)
    }
}
