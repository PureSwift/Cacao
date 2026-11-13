//
//  CacaoDemoApp.swift
//  CacaoDemo
//
//  Created by Alsey Coleman Miller on 11/13/26.
//

import Foundation
import CacaoSDL

@main
struct CacaoDemoApp: App {

    var body: some Scene {
        WindowGroup("Cacao") {
            ContentView()
        }
        .defaultSize(width: 520, height: 760)
    }
}

enum Tab: String, CaseIterable, Hashable {
    case controls = "Controls"
    case list = "List"
    case shapes = "Shapes"
}

struct ContentView: View {

    /// The first tab, from `CACAO_DEMO_TAB`, for screenshots.
    @State private var tab = ProcessInfo.processInfo.environment["CACAO_DEMO_TAB"].flatMap(Tab.init(rawValue:)) ?? .controls

    var body: some View {
        VStack(spacing: 0) {
            Picker("Section", selection: $tab) {
                ForEach(Tab.allCases, id: \.self) { tab in
                    Text(tab.rawValue).tag(tab)
                }
            }
            .pickerStyle(.segmented)
            .padding()
            Divider()
            switch tab {
            case .controls:
                ControlsScreen()
            case .list:
                ListScreen()
            case .shapes:
                ShapesScreen()
            }
        }
    }
}

// MARK: - Controls

struct ControlsScreen: View {

    @State private var notifications = true
    @State private var agree = false
    @State private var volume = 0.4
    @State private var count = 3
    @State private var name = ""
    @State private var password = ""
    @State private var notes = "Multi-line text wraps and grows.\nPress Return for a new line."
    @State private var flavor = "Vanilla"
    @State private var size = 1
    @State private var shipping = "Standard"
    @State private var lastAction = "None"
    @State private var showDetails = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                Section("Toggles") {
                    Toggle("Notifications", isOn: $notifications)
                    Toggle("I agree to the terms", isOn: $agree)
                        .toggleStyle(.checkbox)
                }
                Section("Values") {
                    HStack {
                        Text("Volume")
                        Slider(value: $volume)
                        Text("\(Int(volume * 100))%")
                            .monospacedDigit()
                            .frame(width: 44, alignment: .trailing)
                    }
                    Stepper("Quantity: \(count)", value: $count, in: 0...10)
                    ProgressView("Downloading", value: volume)
                    HStack(spacing: 12) {
                        ProgressView()
                        ProgressView(value: volume).progressViewStyle(.circular)
                        Text("Spinners")
                    }
                }
                Section("Text") {
                    TextField("Name", text: $name)
                        .onSubmit { lastAction = "Submitted \(name)" }
                    SecureField("Password", text: $password)
                    TextEditor(text: $notes)
                        .frame(height: 70)
                        .padding(4)
                        .overlay { RoundedRectangle(cornerRadius: 6).strokeBorder(Color.gray.opacity(0.5)) }
                    Text(name.isEmpty ? "Type a name and press Return." : "Hello, \(name)!")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Section("Pickers") {
                    Picker("Flavor", selection: $flavor) {
                        ForEach(["Vanilla", "Chocolate", "Strawberry"], id: \.self) { Text($0) }
                    }
                    Picker("Size", selection: $size) {
                        Text("Small").tag(0)
                        Text("Medium").tag(1)
                        Text("Large").tag(2)
                    }
                    .pickerStyle(.segmented)
                    Picker("Shipping", selection: $shipping) {
                        ForEach(["Standard", "Express"], id: \.self) { Text($0) }
                    }
                    .pickerStyle(.inline)
                }
                Section("Menus and links") {
                    HStack {
                        Menu("Actions") {
                            Button("Duplicate") { lastAction = "Duplicate" }
                            Button("Rename") { lastAction = "Rename" }
                            Divider()
                            Button("Delete", role: .destructive) { lastAction = "Delete" }
                        }
                        Text("Last action: \(lastAction)")
                            .foregroundStyle(.secondary)
                    }
                    Link("Swift.org", destination: URL(string: "https://swift.org")!)
                    Label("Settings", systemImage: "gear")
                    DisclosureGroup("More details", isExpanded: $showDetails) {
                        Text("Disclosure groups show and hide their content.")
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .padding()
        }
    }
}

/// A titled group of controls.
struct Section<Content: View>: View {

    let title: String

    let content: Content

    init(_ title: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.headline)
                .foregroundStyle(.secondary)
            content
        }
    }
}

// MARK: - List

struct ListScreen: View {

    @State private var selection: Int?

    var body: some View {
        VStack(spacing: 0) {
            List(0..<10_000, id: \.self, selection: $selection) { index in
                HStack {
                    Circle()
                        .fill(Color(hue: Double(index % 24) / 24, saturation: 0.6, brightness: 0.9))
                        .frame(width: 24, height: 24)
                    Text("Row \(index + 1)")
                    Spacer()
                    Text(selection == index ? "Selected" : "")
                        .font(.caption)
                        .foregroundStyle(.blue)
                }
            }
            Divider()
            Text(selection.map { "Selected row \($0 + 1) of 10,000" } ?? "10,000 rows; created as they scroll into view")
                .font(.caption)
                .foregroundStyle(.secondary)
                .padding(8)
        }
    }
}

// MARK: - Shapes

struct ShapesScreen: View {

    @State private var opacity = 0.6

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Section("Shapes") {
                    HStack(spacing: 16) {
                        Circle().fill(.orange)
                        RoundedRectangle(cornerRadius: 12).fill(.blue)
                        Capsule().stroke(.green, lineWidth: 4)
                        Ellipse().strokeBorder(.purple, lineWidth: 3)
                    }
                    .frame(height: 60)
                }
                Section("Clipping") {
                    HStack(spacing: 16) {
                        Swatches().frame(width: 90, height: 90).clipShape(Circle())
                        Swatches().frame(width: 90, height: 90).clipShape(RoundedRectangle(cornerRadius: 20))
                        Swatches().frame(width: 90, height: 90).clipShape(Capsule())
                    }
                }
                Section("Group opacity") {
                    HStack(spacing: 24) {
                        Overlapping().opacity(opacity)
                        VStack(alignment: .leading) {
                            Text("Overlapping circles fade as one group.")
                                .font(.caption)
                            Slider(value: $opacity)
                        }
                    }
                }
            }
            .padding()
        }
    }
}

/// Stripes of color, to show clipping.
struct Swatches: View {

    var body: some View {
        VStack(spacing: 0) {
            Color.red
            Color.orange
            Color.yellow
            Color.green
            Color.blue
        }
    }
}

/// Two overlapping circles.
struct Overlapping: View {

    var body: some View {
        ZStack {
            Circle().fill(.red).frame(width: 70, height: 70).offset(x: -18)
            Circle().fill(.blue).frame(width: 70, height: 70).offset(x: 18)
        }
        .frame(width: 110, height: 70)
    }
}
