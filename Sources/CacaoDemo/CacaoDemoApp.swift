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
        .defaultSize(width: 900, height: 720)
    }
}

/// The catalog's screens.
enum Screen: String, CaseIterable, Hashable {
    case controls = "Controls"
    case list = "List"
    case shapes = "Shapes"
    case grids = "Grids"
    case navigation = "Navigation"
    case presentations = "Presentations"
    case tabs = "Tabs"
}

struct ContentView: View {

    /// The first screen, from `CACAO_DEMO_SCREEN`, for screenshots.
    private let initial = ProcessInfo.processInfo.environment["CACAO_DEMO_SCREEN"].flatMap(Screen.init(rawValue:)) ?? .controls

    var body: some View {
        NavigationSplitView {
            List {
                Section("Catalog") {
                    ForEach(Screen.allCases, id: \.self) { screen in
                        NavigationLink(screen.rawValue, value: screen)
                    }
                }
            }
            .navigationTitle("Cacao")
            .navigationDestination(for: Screen.self) { ScreenView(screen: $0) }
        } detail: {
            ScreenView(screen: initial)
        }
    }
}

struct ScreenView: View {

    let screen: Screen

    var body: some View {
        Group {
            switch screen {
            case .controls: ControlsScreen()
            case .list: ListScreen()
            case .shapes: ShapesScreen()
            case .grids: GridsScreen()
            case .navigation: NavigationScreen()
            case .presentations: PresentationsScreen()
            case .tabs: TabsScreen()
            }
        }
        .navigationTitle(screen.rawValue)
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
        Form {
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
                    Text(name.isEmpty ? "Type a name below and press Return." : "Hello, \(name)!")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Section("Text") {
                    TextField("Name", text: $name)
                        .onSubmit { lastAction = "Submitted \(name)" }
                    SecureField("Password", text: $password)
                    TextEditor(text: $notes)
                        .frame(height: 70)
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

// MARK: - Grids

struct GridsScreen: View {

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("Grid").font(.headline)
                Grid(alignment: .leading, horizontalSpacing: 16, verticalSpacing: 8) {
                    GridRow {
                        Text("Name").bold()
                        Text("Kind").bold()
                        Text("Size").bold()
                    }
                    Divider()
                    GridRow {
                        Text("Cacao.swift")
                        Text("Swift source")
                        Text("2 KB")
                    }
                    GridRow {
                        Text("README.md")
                        Text("Markdown")
                        Text("4 KB")
                    }
                }
                Text("Lazy grid of 2,000 cells").font(.headline)
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 80))], spacing: 8) {
                    ForEach(0..<2000, id: \.self) { index in
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color(hue: Double(index % 36) / 36, saturation: 0.5, brightness: 0.9))
                            .frame(height: 60)
                            .overlay { Text("\(index)").font(.caption) }
                    }
                }
            }
            .padding()
        }
    }
}

// MARK: - Navigation

struct NavigationScreen: View {

    @State private var query = ""

    private let fruits = ["Apple", "Banana", "Cherry", "Grape", "Kiwi", "Lemon", "Mango", "Orange", "Pear", "Plum"]

    var body: some View {
        NavigationStack {
            List {
                ForEach(fruits.filter { query.isEmpty || $0.localizedCaseInsensitiveContains(query) }, id: \.self) { fruit in
                    NavigationLink(fruit, value: fruit)
                }
            }
            .navigationTitle("Fruits")
            .searchable(text: $query, prompt: "Filter fruits")
            .navigationDestination(for: String.self) { fruit in
                VStack(spacing: 12) {
                    Text(fruit).font(.largeTitle)
                    Text("Pushed with a value link; the back button returns to the list.")
                        .foregroundStyle(.secondary)
                }
                .navigationTitle(fruit)
                .toolbar {
                    ToolbarItem(placement: .primaryAction) {
                        Button("Favorite") { }
                    }
                }
            }
        }
    }
}

// MARK: - Presentations

struct PresentationsScreen: View {

    @State private var showSheet = false
    @State private var showAlert = false
    @State private var showDialog = false
    @State private var showPopover = false
    @State private var last = "Nothing yet"

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Button("Show sheet") { showSheet = true }
                .sheet(isPresented: $showSheet) { SheetContent() }
            Button("Show alert") { showAlert = true }
                .alert("Delete the file?", isPresented: $showAlert) {
                    Button("Cancel", role: .cancel) { last = "Cancelled" }
                    Button("Delete", role: .destructive) { last = "Deleted" }
                } message: {
                    Text("This can't be undone.")
                }
            Button("Show confirmation dialog") { showDialog = true }
                .confirmationDialog("Share", isPresented: $showDialog) {
                    Button("Copy link") { last = "Copied link" }
                    Button("Email") { last = "Emailed" }
                    Button("Cancel", role: .cancel) { }
                }
            Button("Show popover") { showPopover = true }
                .popover(isPresented: $showPopover) {
                    Text("Popovers anchor to their view.")
                }
            Text("Right-click for a context menu")
                .padding(12)
                .background { RoundedRectangle(cornerRadius: 8).strokeBorder(Color.gray) }
                .contextMenu {
                    Button("Copy") { last = "Copy" }
                    Button("Paste") { last = "Paste" }
                }
            Text("Last action: \(last)").foregroundStyle(.secondary)
        }
        .buttonStyle(.bordered)
        .padding()
    }
}

struct SheetContent: View {

    @Environment(\.dismiss) private var dismiss

    @State private var name = "Untitled"

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("New Document").font(.title2).bold()
            TextField("Name", text: $name)
            HStack {
                Spacer()
                Button("Cancel") { dismiss() }
                    .buttonStyle(.bordered)
                Button("Create") { dismiss() }
                    .buttonStyle(.borderedProminent)
            }
        }
        .padding(24)
    }
}

// MARK: - Tabs

struct TabsScreen: View {

    var body: some View {
        TabView {
            Tab("Inbox", value: 0) {
                List(0..<20, id: \.self) { Text("Message \($0 + 1)") }
            }
            Tab("Sent", value: 1) {
                Text("No sent messages").foregroundStyle(.secondary)
            }
            Tab("Settings", value: 2) {
                Form {
                    Toggle("Notifications", isOn: .constant(true))
                }
            }
        }
    }
}
