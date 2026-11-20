//
//  Gauge.swift
//  Cacao
//
//  Created by Alsey Coleman Miller on 11/13/26.
//

import CacaoRender
import Foundation
#if canImport(CoreGraphics)
import CoreGraphics
#endif

/// A view that shows a value within a range.
public struct Gauge<Label: View, CurrentValueLabel: View, BoundsLabel: View, MarkedValueLabels: View>: View {

    /// Where the value falls in the range, from 0 to 1.
    internal let fraction: Double

    internal let label: Label

    internal let currentValueLabel: CurrentValueLabel?

    internal let minimumValueLabel: BoundsLabel?

    internal let maximumValueLabel: BoundsLabel?

    @Environment(\.gaugeStyle) private var style

    public var body: some View {
        switch style {
        case .circular, .circularCapacity:
            circular
        default:
            linear
        }
    }

    private var linear: some View {
        VStack(alignment: .leading, spacing: 4) {
            label
            HStack(spacing: 6) {
                if let minimumValueLabel {
                    minimumValueLabel.font(.caption).foregroundStyle(.secondary)
                }
                _FractionLayout(fraction: fraction, trackHeight: style == .linearCapacity ? 6 : 4, thumbSize: 0, idealWidth: 160) {
                    Capsule().fill(Color.controlFill)
                    Capsule().fill(Color.accentColor)
                }
                if let maximumValueLabel {
                    maximumValueLabel.font(.caption).foregroundStyle(.secondary)
                }
            }
            if let currentValueLabel {
                currentValueLabel.font(.caption).foregroundStyle(.secondary)
            }
        }
    }

    /// A ring open at the bottom, filled to the value, with the current
    /// value in the middle and the bounds at the ring's ends.
    private var circular: some View {
        let start = style == .circularCapacity ? 0.0 : -0.375
        let span = style == .circularCapacity ? 1.0 : 0.75
        return ZStack {
            _ArcShape(start: start, end: start + span)
                .stroke(Color.controlFill, style: StrokeStyle(lineWidth: 6, lineCap: .round))
            _ArcShape(start: start, end: start + span * fraction)
                .stroke(Color.accentColor, style: StrokeStyle(lineWidth: 6, lineCap: .round))
            if let currentValueLabel {
                currentValueLabel.font(.caption)
            } else {
                label.font(.caption2)
            }
            if style == .circular {
                VStack {
                    Spacer()
                    HStack {
                        if let minimumValueLabel { minimumValueLabel }
                        Spacer()
                        if let maximumValueLabel { maximumValueLabel }
                    }
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                }
            }
        }
        .frame(width: 58, height: 58)
    }
}

extension Gauge where MarkedValueLabels == EmptyView {

    /// Creates a gauge showing a value within a range, with labels for the
    /// gauge, its current value and its bounds.
    public init<V: BinaryFloatingPoint>(
        value: V,
        in bounds: ClosedRange<V> = 0...1,
        @ViewBuilder label: () -> Label,
        @ViewBuilder currentValueLabel: () -> CurrentValueLabel,
        @ViewBuilder minimumValueLabel: () -> BoundsLabel,
        @ViewBuilder maximumValueLabel: () -> BoundsLabel
    ) {
        self.fraction = Self.fraction(value, in: bounds)
        self.label = label()
        self.currentValueLabel = currentValueLabel()
        self.minimumValueLabel = minimumValueLabel()
        self.maximumValueLabel = maximumValueLabel()
    }

    internal static func fraction<V: BinaryFloatingPoint>(_ value: V, in bounds: ClosedRange<V>) -> Double {
        let span = Double(bounds.upperBound - bounds.lowerBound)
        guard span > 0 else { return 0 }
        return min(max(Double(value - bounds.lowerBound) / span, 0), 1)
    }
}

extension Gauge where BoundsLabel == EmptyView, MarkedValueLabels == EmptyView {

    /// Creates a gauge showing a value within a range, with labels for the
    /// gauge and its current value.
    public init<V: BinaryFloatingPoint>(
        value: V,
        in bounds: ClosedRange<V> = 0...1,
        @ViewBuilder label: () -> Label,
        @ViewBuilder currentValueLabel: () -> CurrentValueLabel
    ) {
        self.fraction = Gauge<Label, CurrentValueLabel, EmptyView, EmptyView>.fraction(value, in: bounds)
        self.label = label()
        self.currentValueLabel = currentValueLabel()
        self.minimumValueLabel = nil
        self.maximumValueLabel = nil
    }
}

extension Gauge where CurrentValueLabel == EmptyView, BoundsLabel == EmptyView, MarkedValueLabels == EmptyView {

    /// Creates a gauge showing a value within a range, with a label.
    public init<V: BinaryFloatingPoint>(
        value: V,
        in bounds: ClosedRange<V> = 0...1,
        @ViewBuilder label: () -> Label
    ) {
        self.fraction = Gauge<Label, EmptyView, EmptyView, EmptyView>.fraction(value, in: bounds)
        self.label = label()
        self.currentValueLabel = nil
        self.minimumValueLabel = nil
        self.maximumValueLabel = nil
    }
}

// MARK: - Styles

/// The styles of gauges.
public struct GaugeStyleKind: Equatable, Sendable {
    internal let name: String
    static let linear = GaugeStyleKind(name: "linear")
    static let linearCapacity = GaugeStyleKind(name: "linearCapacity")
    static let circular = GaugeStyleKind(name: "circular")
    static let circularCapacity = GaugeStyleKind(name: "circularCapacity")
}

/// A gauge style.
public protocol GaugeStyle {
    var _kind: GaugeStyleKind { get }
}

/// The default gauge style: a horizontal bar.
public struct DefaultGaugeStyle: GaugeStyle {
    public init() { }
    public var _kind: GaugeStyleKind { .linear }
}

/// A gauge style that displays a bar that fills from leading to trailing
/// edges as the gauge's current value increases.
public struct LinearCapacityGaugeStyle: GaugeStyle {
    public init() { }
    public var _kind: GaugeStyleKind { .linearCapacity }
}

/// A gauge style that displays bar with a marker that appears at a point
/// along the bar to indicate the gauge's current value.
public struct AccessoryLinearGaugeStyle: GaugeStyle {
    public init() { }
    public var _kind: GaugeStyleKind { .linear }
}

/// A gauge style that displays an open ring with a marker that appears at
/// a point along the ring to indicate the gauge's current value.
public struct AccessoryCircularGaugeStyle: GaugeStyle {
    public init() { }
    public var _kind: GaugeStyleKind { .circular }
}

/// A gauge style that displays a closed ring that's partially filled in to
/// indicate the gauge's current value.
public struct AccessoryCircularCapacityGaugeStyle: GaugeStyle {
    public init() { }
    public var _kind: GaugeStyleKind { .circularCapacity }
}

extension GaugeStyle where Self == DefaultGaugeStyle {
    public static var automatic: DefaultGaugeStyle { DefaultGaugeStyle() }
}

extension GaugeStyle where Self == LinearCapacityGaugeStyle {
    public static var linearCapacity: LinearCapacityGaugeStyle { LinearCapacityGaugeStyle() }
}

extension GaugeStyle where Self == AccessoryLinearGaugeStyle {
    public static var accessoryLinear: AccessoryLinearGaugeStyle { AccessoryLinearGaugeStyle() }
}

extension GaugeStyle where Self == AccessoryCircularGaugeStyle {
    public static var accessoryCircular: AccessoryCircularGaugeStyle { AccessoryCircularGaugeStyle() }
}

extension GaugeStyle where Self == AccessoryCircularCapacityGaugeStyle {
    public static var accessoryCircularCapacity: AccessoryCircularCapacityGaugeStyle { AccessoryCircularCapacityGaugeStyle() }
}

private struct GaugeStyleKey: EnvironmentKey {
    static let defaultValue = GaugeStyleKind.linear
}

extension EnvironmentValues {

    internal var gaugeStyle: GaugeStyleKind {
        get { self[GaugeStyleKey.self] }
        set { self[GaugeStyleKey.self] = newValue }
    }
}

extension View {

    /// Sets the style for gauges within this view.
    public func gaugeStyle<S: GaugeStyle>(_ style: S) -> some View {
        environment(\.gaugeStyle, style._kind)
    }
}
