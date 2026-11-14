//
//  ColorPicker.swift
//  Cacao
//
//  Created by Alsey Coleman Miller on 11/13/26.
//

import Foundation
#if canImport(CoreGraphics)
import CoreGraphics
#endif

/// A control used to select a color.
public struct ColorPicker<Label: View>: View {

    internal let selection: Binding<Color>

    internal let supportsOpacity: Bool

    internal let label: Label

    @Environment(\.labelsHidden) private var labelsHidden

    @Environment(\.colorScheme) private var colorScheme

    @State private var isEditing = false

    /// Creates a color picker that selects a color.
    public init(selection: Binding<Color>, supportsOpacity: Bool = true, @ViewBuilder label: () -> Label) {
        self.selection = selection
        self.supportsOpacity = supportsOpacity
        self.label = label()
    }

    public var body: some View {
        HStack(spacing: 8) {
            if !labelsHidden {
                label
                Spacer(minLength: 8)
            }
            Button {
                isEditing = true
            } label: {
                RoundedRectangle(cornerRadius: 4)
                    .fill(selection.wrappedValue)
                    .frame(width: 36, height: 20)
                    .overlay(RoundedRectangle(cornerRadius: 4).strokeBorder(Color.gray.opacity(0.5), lineWidth: 1))
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Color")
            .popover(isPresented: $isEditing) {
                _ColorEditor(selection: selection, supportsOpacity: supportsOpacity).padding(12)
            }
        }
    }
}

extension ColorPicker where Label == Text {

    /// Creates a color picker with a text label generated from a title
    /// string key.
    public init(_ titleKey: LocalizedStringKey, selection: Binding<Color>, supportsOpacity: Bool = true) {
        self.init(selection: selection, supportsOpacity: supportsOpacity) { Text(titleKey) }
    }

    /// Creates a color picker with a text label generated from a title string.
    @_disfavoredOverload
    public init<S: StringProtocol>(_ title: S, selection: Binding<Color>, supportsOpacity: Bool = true) {
        self.init(selection: selection, supportsOpacity: supportsOpacity) { Text(title) }
    }
}

/// Hue, saturation and brightness, with opacity.
internal struct HSBColor: Equatable {

    var hue: Double

    var saturation: Double

    var brightness: Double

    var opacity: Double

    init(hue: Double, saturation: Double, brightness: Double, opacity: Double) {
        self.hue = hue
        self.saturation = saturation
        self.brightness = brightness
        self.opacity = opacity
    }

    init(_ color: Color.Resolved) {
        let r = Double(color.red), g = Double(color.green), b = Double(color.blue)
        let maximum = max(r, g, b), minimum = min(r, g, b)
        let delta = maximum - minimum
        var hue = 0.0
        if delta > 0 {
            if maximum == r {
                hue = (g - b) / delta
            } else if maximum == g {
                hue = 2 + (b - r) / delta
            } else {
                hue = 4 + (r - g) / delta
            }
            hue /= 6
            if hue < 0 { hue += 1 }
        }
        self.init(hue: hue, saturation: maximum > 0 ? delta / maximum : 0, brightness: maximum, opacity: Double(color.opacity))
    }

    var color: Color {
        Color(hue: hue, saturation: saturation, brightness: brightness, opacity: opacity)
    }
}

/// A palette of colors to choose from, and sliders for hue, saturation,
/// brightness and opacity.
internal struct _ColorEditor: View {

    let selection: Binding<Color>

    let supportsOpacity: Bool

    @Environment(\.self) private var environment

    /// The palette: a row of grays, then rows of hues getting darker.
    static let palette: [[Color]] = {
        let grays = (0..<8).map { Color(white: Double(7 - $0) / 7) }
        let rows = [(0.35, 1.0), (0.7, 1.0), (1.0, 1.0), (1.0, 0.7), (1.0, 0.45)].map { saturation, brightness in
            (0..<8).map { Color(hue: Double($0) / 8, saturation: saturation, brightness: brightness) }
        }
        return [grays] + rows
    }()

    var body: some View {
        let current = HSBColor(selection.wrappedValue.resolve(in: environment))
        VStack(alignment: .leading, spacing: 8) {
            Grid(horizontalSpacing: 3, verticalSpacing: 3) {
                ForEach(0..<Self.palette.count, id: \.self) { row in
                    GridRow {
                        ForEach(0..<Self.palette[row].count, id: \.self) { column in
                            let color = Self.palette[row][column]
                            Button {
                                selection.wrappedValue = color.opacity(current.opacity)
                            } label: {
                                Rectangle().fill(color).frame(width: 22, height: 22)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
            slider("Hue", value: current.hue) { $0.hue = $1 }
            slider("Saturation", value: current.saturation) { $0.saturation = $1 }
            slider("Brightness", value: current.brightness) { $0.brightness = $1 }
            if supportsOpacity {
                slider("Opacity", value: current.opacity) { $0.opacity = $1 }
            }
        }
        .frame(width: 200)
    }

    private func slider(_ title: String, value: Double, update: @escaping (inout HSBColor, Double) -> Void) -> some View {
        let selection = self.selection
        let environment = self.environment
        return VStack(alignment: .leading, spacing: 2) {
            Text(title).font(.caption).foregroundStyle(.secondary)
            Slider(value: Binding(
                get: { value },
                set: { newValue in
                    var color = HSBColor(selection.wrappedValue.resolve(in: environment))
                    update(&color, newValue)
                    selection.wrappedValue = color.color
                }
            ))
        }
    }
}
