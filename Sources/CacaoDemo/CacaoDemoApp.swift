//
//  CacaoDemoApp.swift
//  CacaoDemo
//
//  Created by Alsey Coleman Miller on 11/13/26.
//

import CacaoRender
import Foundation
import CacaoSDL

@main
struct CacaoDemoApp: App {

    init() {
        // Wayland's app_id and X11's window class, for docks.
        SDLHost.appIdentifier = "org.pureswift.CacaoDemo"
    }

    /// Whether to open a bar along the top of the screen instead of the
    /// catalog, from `CACAO_DEMO_LAYER`: a window in the top layer, which
    /// other windows stay below where the compositor has a layer shell.
    private static let showsBar = ProcessInfo.processInfo.environment["CACAO_DEMO_LAYER"] == "1"

    var body: some Scene {
        if Self.showsBar {
            WindowGroup("Cacao Bar", id: "bar") {
                DemoBar()
            }
            .defaultSize(width: 800, height: DemoBar.height)
            .windowLayer(.top, edges: [.top, .leading, .trailing], exclusiveZone: DemoBar.height, namespace: "cacao-demo")
        }
        WindowGroup("Cacao", id: "catalog") {
            ContentView()
        }
        .defaultSize(width: 900, height: 720)
        .commands {
            CommandMenu("Catalog") {
                OpenSettingsButton(title: "Demo Settings")
                    .keyboardShortcut("d", modifiers: [.command, .shift])
            }
        }
        Settings {
            SettingsView()
        }
        MenuBarExtra("Cacao", systemImage: "bolt.fill") {
            OpenSettingsButton(title: "Settings…")
        }
    }
}

/// A bar along the top of the screen, which opens the catalog.
struct DemoBar: View {

    static let height: CGFloat = 32

    @Environment(\.openWindow) private var openWindow

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "bolt.fill")
            Text("Cacao")
                .bold()
            Spacer()
            Button("Catalog") { openWindow(id: "catalog") }
        }
        .padding(.horizontal, 12)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.orange.opacity(0.25))
    }
}

/// A button that opens the settings window.
struct OpenSettingsButton: View {

    let title: String

    @Environment(\.openSettings) private var openSettings

    var body: some View {
        Button(title) { openSettings() }
    }
}

/// The demo's settings window.
struct SettingsView: View {

    @AppStorage("demo.accent") private var accent = 0

    var body: some View {
        Form {
            Picker("Accent", selection: $accent) {
                Text("Blue").tag(0)
                Text("Orange").tag(1)
            }
        }
        .padding()
        .frame(width: 320, height: 120)
    }
}

/// The catalog's screens.
enum Screen: String, CaseIterable, Hashable {
    case controls = "Controls"
    case list = "List"
    case shapes = "Shapes"
    case effects = "Effects"
    case animation = "Animation"
    case gestures = "Gestures"
    case grids = "Grids"
    case navigation = "Navigation"
    case presentations = "Presentations"
    case tabs = "Tabs"
    case external = "External"
}

struct ContentView: View {

    /// The first screen, from `CACAO_DEMO_SCREEN`, for screenshots.
    private let initial = ProcessInfo.processInfo.environment["CACAO_DEMO_SCREEN"].flatMap(Screen.init(rawValue:)) ?? .controls

    @State private var search = ""

    @State private var favorites = 0

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
                // In the desktop's look, the toolbar is the title bar too.
                .toolbar {
                    ToolbarItem(placement: .primaryAction) {
                        Button {
                            favorites += 1
                        } label: {
                            Label("Favorite", systemImage: favorites > 0 ? "star.fill" : "star")
                                .labelStyle(.iconOnly)
                        }
                    }
                }
                .searchable(text: $search, prompt: "Search the catalog")
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
            case .effects: EffectsScreen()
            case .animation: AnimationScreen()
            case .gestures: GesturesScreen()
            case .grids: GridsScreen()
            case .navigation: NavigationScreen()
            case .presentations: PresentationsScreen()
            case .tabs: TabsScreen()
            case .external: ExternalScreen()
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
    @State private var due = Date()
    @State private var tint = Color.orange

    var body: some View {
        Form {
                Section("Buttons") {
                    HStack {
                        Button("Cancel") { lastAction = "Cancel" }
                        Button("Save") { lastAction = "Save" }
                            .buttonStyle(.borderedProminent)
                        Button("Disabled") { }
                            .disabled(true)
                        Button("Small") { lastAction = "Small" }
                            .controlSize(.small)
                    }
                }
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
                Section("Dates, colors and gauges") {
                    DatePicker("Due", selection: $due)
                    ColorPicker("Tint", selection: $tint)
                    HStack(spacing: 20) {
                        Gauge(value: volume) {
                            Text("Volume")
                        } currentValueLabel: {
                            Text("\(Int(volume * 100))%")
                        } minimumValueLabel: {
                            Text("0")
                        } maximumValueLabel: {
                            Text("100")
                        }
                        Gauge(value: volume) {
                            Text("Volume")
                        } currentValueLabel: {
                            Text("\(Int(volume * 100))")
                        }
                        .gaugeStyle(.accessoryCircular)
                        .tint(tint)
                    }
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

// MARK: - Effects

struct EffectsScreen: View {

    @State private var radius = 4.0

    @State private var saturation = 1.0

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Section("Materials") {
                    ZStack {
                        // Something busy for the materials to blur.
                        LinearGradient(colors: [.orange, .pink, .purple, .blue], startPoint: .topLeading, endPoint: .bottomTrailing)
                        HStack(spacing: 24) {
                            ForEach(["sun.max.fill", "leaf.fill", "flame.fill", "drop.fill", "bolt.fill", "star.fill"], id: \.self) { name in
                                Image(systemName: name)
                                    .font(.system(size: 44))
                                    .foregroundStyle(.white)
                            }
                        }
                        Text("Behind the glass")
                            .font(.largeTitle.bold())
                            .foregroundStyle(.black.opacity(0.7))
                            .offset(y: 46)
                        HStack(spacing: 12) {
                            Text("Ultra thin")
                                .padding(12)
                                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
                            Text("Thin")
                                .padding(12)
                                .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 12))
                            Text("Regular")
                                .padding(12)
                                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
                            Text("Thick")
                                .padding(12)
                                .background(.thickMaterial, in: RoundedRectangle(cornerRadius: 12))
                            Text("Capsule")
                                .padding(.horizontal, 16)
                                .padding(.vertical, 10)
                                .background(.ultraThinMaterial, in: Capsule())
                        }
                        .offset(y: 30)
                    }
                    .frame(height: 180)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                }
                Section("Symbols") {
                    let names = [
                        "chevron.left", "chevron.right.circle", "arrow.up.right", "arrow.clockwise", "arrow.triangle.2.circlepath", "square.and.arrow.up", "tray.and.arrow.down", "paperplane", "link", "paperclip", "magnifyingglass", "slider.horizontal.3", "line.3.horizontal", "list.bullet", "ellipsis.circle",
                        "plus", "minus.circle", "xmark.circle", "checkmark.circle", "exclamationmark.triangle", "info.circle", "questionmark.circle", "nosign", "star", "heart", "bookmark", "tag", "flag", "bell", "bell.slash",
                        "house", "building.2", "map", "mappin", "location", "globe", "person", "person.2", "person.crop.circle", "hand.thumbsup", "trash", "trash.slash", "folder", "doc.text", "doc.on.doc",
                        "envelope", "phone", "message", "bubble.left.and.bubble.right", "calendar", "clock", "alarm", "timer", "photo", "camera", "video", "play", "pause", "backward", "forward",
                        "speaker.wave.2", "mic", "music.note", "headphones", "tv", "laptopcomputer", "iphone", "keyboard", "printer", "gamecontroller", "wifi", "battery.75percent", "lightbulb", "lock", "key",
                        "eye", "gearshape", "wrench", "hammer", "pencil", "paintbrush", "scissors", "cart", "bag", "creditcard", "gift", "sidebar.left", "textformat", "bold", "terminal",
                        "airplane", "car", "bicycle", "cloud.rain", "sun.max", "moon", "snowflake", "bolt", "flame", "drop", "leaf", "pawprint", "chart.bar", "trophy", "puzzlepiece",
                    ]
                    LazyVGrid(columns: Array(repeating: GridItem(.fixed(36)), count: 15), spacing: 10) {
                        ForEach(names, id: \.self) { name in
                            Image(systemName: name).imageScale(.large)
                        }
                    }
                    .foregroundStyle(.tint)
                    // Filled variants, and weights from light to black.
                    HStack(spacing: 14) {
                        ForEach(["house.fill", "heart.fill", "bell.fill", "person.fill", "folder.fill", "star.fill", "checkmark.circle.fill", "trash.circle.fill"], id: \.self) { name in
                            Image(systemName: name).imageScale(.large)
                        }
                        Divider().frame(height: 24)
                        ForEach([Font.Weight.ultraLight, .light, .regular, .semibold, .bold, .black], id: \.self) { weight in
                            Image(systemName: "gearshape").font(.system(size: 22, weight: weight))
                        }
                        Divider().frame(height: 24)
                        Label("Settings", systemImage: "gearshape").fixedSize()
                        Image(systemName: "heart.fill").renderingMode(.original)
                    }
                    .foregroundStyle(.tint)
                }
                Section("Canvas") {
                    Canvas { context, size in
                        // Additive color circles.
                        var circles = context
                        circles.blendMode = .screen
                        for (index, color) in [Color.red, Color.green, Color.blue].enumerated() {
                            let angle = Double(index) * 2 * .pi / 3 - .pi / 2
                            let center = CGPoint(x: 60 + 18 * cos(angle), y: 60 + 18 * sin(angle))
                            circles.fill(Path(ellipseIn: CGRect(x: center.x - 32, y: center.y - 32, width: 64, height: 64)), with: .color(color))
                        }
                        // A symbol with a shadow.
                        var shadowed = context
                        shadowed.addFilter(.shadow(color: .black.opacity(0.6), radius: 4, x: 3, y: 4))
                        shadowed.draw(Image(systemName: "star.fill"), in: CGRect(x: 140, y: 20, width: 80, height: 80))
                        // Tagged views drawn as symbols, rotated.
                        if let badge = context.resolveSymbol(id: 0) {
                            for index in 0..<6 {
                                var rotated = context
                                rotated.translateBy(x: 310, y: 60)
                                rotated.rotate(by: .degrees(Double(index) * 60))
                                rotated.opacity = 0.4 + Double(index) * 0.1
                                rotated.draw(badge, at: CGPoint(x: 0, y: -36))
                            }
                        }
                        // Text cut out of a blurred layer.
                        var layered = context
                        layered.clipToLayer { mask in
                            mask.draw(Text("Canvas").font(.system(size: 40, weight: .heavy)), at: CGPoint(x: 470, y: 60))
                        }
                        layered.addFilter(.blur(radius: 1))
                        layered.fill(Path(CGRect(x: 380, y: 20, width: 180, height: 80)), with: .linearGradient(Gradient(colors: [.orange, .pink]), startPoint: CGPoint(x: 380, y: 0), endPoint: CGPoint(x: 560, y: 0)))
                    } symbols: {
                        Text("Hi")
                            .font(.headline)
                            .padding(6)
                            .background(Capsule().fill(.tint))
                            .foregroundStyle(.white)
                            .tag(0)
                    }
                    .frame(height: 120)
                }
                Section("Gradients") {
                    HStack(spacing: 16) {
                        RoundedRectangle(cornerRadius: 12)
                            .fill(LinearGradient(colors: [.orange, .pink], startPoint: .topLeading, endPoint: .bottomTrailing))
                        Circle()
                            .fill(RadialGradient(colors: [.yellow, .red], center: .center, startRadius: 0, endRadius: 35))
                        Circle()
                            .stroke(AngularGradient(colors: [.blue, .purple, .pink, .blue], center: .center), lineWidth: 8)
                        Capsule()
                            .fill(Color.green.gradient)
                    }
                    .frame(height: 70)
                }
                Section("Shadows") {
                    HStack(spacing: 30) {
                        RoundedRectangle(cornerRadius: 12)
                            .fill(.white)
                            .frame(width: 80, height: 60)
                            .shadow(radius: 6, y: 3)
                        Circle()
                            .fill(.blue)
                            .frame(width: 60, height: 60)
                            .shadow(color: .blue.opacity(0.6), radius: 12)
                        Text("Shadowed")
                            .font(.title)
                            .shadow(color: .red, radius: 2, x: 2, y: 2)
                    }
                    .padding(12)
                }
                Section("Blur") {
                    HStack(spacing: 24) {
                        Swatches()
                            .frame(width: 90, height: 90)
                            .blur(radius: radius)
                        VStack(alignment: .leading) {
                            Text("Radius \(Int(radius))").font(.caption)
                            Slider(value: $radius, in: 0...20)
                        }
                    }
                }
                Section("Masks and text") {
                    HStack(spacing: 20) {
                        Swatches()
                            .frame(width: 70, height: 70)
                            .mask { Text("Ab").font(.system(size: 40, weight: .bold)).fixedSize() }
                        Swatches()
                            .frame(width: 70, height: 70)
                            .clipShape(Star())
                        Text("Gradient text")
                            .font(.title)
                            .foregroundStyle(LinearGradient(colors: [.purple, .orange], startPoint: .leading, endPoint: .trailing))
                        VStack(alignment: .leading) {
                            Text("Truncated at the tail of a long line").lineLimit(1)
                            Text("Truncated in the middle of a long line").lineLimit(1).truncationMode(.middle)
                            Text("Shrinks to fit before truncating").lineLimit(1).minimumScaleFactor(0.5)
                        }
                        .frame(width: 150)
                    }
                }
                Section("Color effects") {
                    HStack(spacing: 12) {
                        Swatches().frame(width: 60, height: 60).saturation(saturation)
                        Swatches().frame(width: 60, height: 60).grayscale(1)
                        Swatches().frame(width: 60, height: 60).hueRotation(.degrees(90))
                        Swatches().frame(width: 60, height: 60).colorInvert()
                        Swatches().frame(width: 60, height: 60).brightness(0.3)
                    }
                    Slider(value: $saturation, in: 0...2)
                }
            }
            .padding()
        }
    }
}

/// A five-pointed star: a concave shape.
struct Star: Shape {
    func path(in rect: CGRect) -> Path {
        Path { path in
            let center = CGPoint(x: rect.midX, y: rect.midY)
            let outer = min(rect.width, rect.height) / 2, inner = outer * 0.45
            for index in 0..<10 {
                let angle = Double(index) * .pi / 5 - .pi / 2
                let radius = index % 2 == 0 ? outer : inner
                let point = CGPoint(x: center.x + radius * CGFloat(cos(angle)), y: center.y + radius * CGFloat(sin(angle)))
                if index == 0 { path.move(to: point) } else { path.addLine(to: point) }
            }
            path.closeSubpath()
        }
    }
}

// MARK: - Animation

struct AnimationScreen: View {

    @State private var isExpanded = false

    @State private var showsBadge = true

    @State private var isLeading = true

    @State private var spins = 0.0

    @Namespace private var namespace

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Section("Springs") {
                    HStack(spacing: 16) {
                        RoundedRectangle(cornerRadius: isExpanded ? 30 : 8)
                            .fill(isExpanded ? Color.purple : Color.blue)
                            .frame(width: isExpanded ? 220 : 80, height: 80)
                        Button(isExpanded ? "Shrink" : "Grow") {
                            withAnimation(.bouncy) { isExpanded.toggle() }
                        }
                    }
                }
                Section("Transitions") {
                    HStack(spacing: 16) {
                        Button(showsBadge ? "Hide" : "Show") {
                            withAnimation(.smooth) { showsBadge.toggle() }
                        }
                        if showsBadge {
                            Text("New")
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(Capsule().fill(.orange))
                                .transition(.scale.combined(with: .opacity))
                        }
                        Spacer()
                    }
                    .frame(height: 40)
                }
                Section("Matched geometry") {
                    HStack {
                        if isLeading {
                            Circle().fill(.green)
                                .matchedGeometryEffect(id: "dot", in: namespace)
                                .frame(width: 40, height: 40)
                        }
                        Spacer()
                        if !isLeading {
                            Circle().fill(.green)
                                .matchedGeometryEffect(id: "dot", in: namespace)
                                .frame(width: 60, height: 60)
                        }
                    }
                    .frame(height: 60)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        withAnimation(.snappy) { isLeading.toggle() }
                    }
                }
                Section("Rotation") {
                    HStack(spacing: 16) {
                        RoundedRectangle(cornerRadius: 6).fill(.red)
                            .frame(width: 50, height: 50)
                            .rotationEffect(.degrees(spins * 90))
                        Button("Spin") {
                            withAnimation(.easeInOut(duration: 0.6)) { spins += 1 }
                        }
                    }
                }
                Section("Timeline and canvas") {
                    TimelineView(.animation) { context in
                        Clock(date: context.date)
                    }
                    .frame(width: 120, height: 120)
                }
            }
            .padding()
        }
    }
}

/// A clock face drawn in a canvas.
struct Clock: View {

    let date: Date

    var body: some View {
        Canvas { context, size in
            let radius = min(size.width, size.height) / 2
            let center = CGPoint(x: size.width / 2, y: size.height / 2)
            context.stroke(
                Path(ellipseIn: CGRect(x: center.x - radius + 2, y: center.y - radius + 2, width: radius * 2 - 4, height: radius * 2 - 4)),
                with: .color(.gray),
                lineWidth: 3
            )
            let seconds = date.timeIntervalSinceReferenceDate.truncatingRemainder(dividingBy: 60)
            var hand = context
            hand.translateBy(x: center.x, y: center.y)
            hand.rotate(by: .degrees(seconds * 6))
            var path = Path()
            path.move(to: CGPoint(x: 0, y: 6))
            path.addLine(to: CGPoint(x: 0, y: -radius + 12))
            hand.stroke(path, with: .color(.red), style: StrokeStyle(lineWidth: 2, lineCap: .round))
            context.fill(
                Path(ellipseIn: CGRect(x: center.x - 4, y: center.y - 4, width: 8, height: 8)),
                with: .color(.primary)
            )
        }
    }
}

// MARK: - Gestures

struct GesturesScreen: View {

    @GestureState private var dragOffset = CGSize.zero

    @State private var position = CGSize.zero

    @GestureState private var isPressing = false

    @State private var pressCount = 0

    @State private var scale: CGFloat = 1

    @GestureState private var magnification: CGFloat = 1

    @State private var taps = "Tap or double tap"

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Section("Drag") {
                ZStack {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.gray.opacity(0.15))
                    Circle()
                        .fill(.blue)
                        .frame(width: 50, height: 50)
                        .offset(
                            x: position.width + dragOffset.width,
                            y: position.height + dragOffset.height
                        )
                        .gesture(
                            DragGesture()
                                .updating($dragOffset) { value, state, _ in
                                    state = value.translation
                                }
                                .onEnded { value in
                                    withAnimation(.spring) {
                                        position.width += value.translation.width
                                        position.height += value.translation.height
                                    }
                                }
                        )
                }
                .frame(height: 160)
            }
            Section("Long press") {
                HStack(spacing: 16) {
                    Circle()
                        .fill(isPressing ? Color.orange : Color.green)
                        .frame(width: 50, height: 50)
                        .scaleEffect(isPressing ? 1.3 : 1)
                        .animation(.snappy, value: isPressing)
                        .gesture(
                            LongPressGesture(minimumDuration: 0.6)
                                .updating($isPressing) { value, state, _ in state = value }
                                .onEnded { _ in pressCount += 1 }
                        )
                    Text("Held \(pressCount) times")
                }
            }
            Section("Taps") {
                Text(taps)
                    .padding()
                    .background(RoundedRectangle(cornerRadius: 8).fill(Color.gray.opacity(0.15)))
                    .onTapGesture(count: 2) { taps = "Double tap" }
                    .onTapGesture { taps = "Single tap" }
            }
            Section("Pinch") {
                RoundedRectangle(cornerRadius: 10)
                    .fill(.purple)
                    .frame(width: 80, height: 80)
                    .scaleEffect(scale * magnification)
                    .frame(width: 200, height: 120)
                    .contentShape(Rectangle())
                    .gesture(
                        MagnifyGesture()
                            .updating($magnification) { value, state, _ in state = value.magnification }
                            .onEnded { value in scale = min(max(scale * value.magnification, 0.5), 2) }
                    )
            }
            Spacer()
        }
        .padding()
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

// MARK: - External

/// Draws frames on its own thread, as a game or a video decoder would,
/// and publishes each to a surface.
final class PlasmaProducer: @unchecked Sendable {

    let surface = ExternalSurface()

    private let width = 160

    private let height = 120

    private let lock = NSLock()

    private var isRunning = false

    private var center = CGPoint(x: 0.5, y: 0.5)

    /// Where the waves spread from, in the frame's unit square: the demo
    /// moves it with the pointer.
    func setCenter(_ point: CGPoint) {
        lock.lock()
        center = point
        lock.unlock()
    }

    /// Publishes one frame now, and then thirty a second.
    func start() {
        lock.lock()
        let wasRunning = isRunning
        isRunning = true
        lock.unlock()
        guard !wasRunning else { return }
        publish(time: 0)
        let thread = Thread { [self] in
            var time = 0.0
            while running {
                Thread.sleep(forTimeInterval: 1.0 / 30)
                time += 1.0 / 30
                publish(time: time)
            }
        }
        thread.name = "Plasma"
        thread.start()
    }

    func stop() {
        lock.lock()
        isRunning = false
        lock.unlock()
    }

    private var running: Bool {
        lock.lock()
        defer { lock.unlock() }
        return isRunning
    }

    private func publish(time: Double) {
        lock.lock()
        let center = self.center
        lock.unlock()
        var pixels = [UInt8](repeating: 255, count: width * height * 4)
        for y in 0..<height {
            for x in 0..<width {
                let u = Double(x) / Double(width), v = Double(y) / Double(height)
                let du = u - Double(center.x), dv = v - Double(center.y)
                let ripple = sin((du * du + dv * dv).squareRoot() * 30 - time * 4)
                let wave = sin(u * 10 + time * 2) + sin(v * 8 - time * 1.5) + sin((u + v) * 6 + time) + ripple
                let index = (y * width + x) * 4
                pixels[index] = UInt8(127 + 127 * sin(wave * 1.3))
                pixels[index + 1] = UInt8(127 + 127 * sin(wave * 1.3 + 2.1))
                pixels[index + 2] = UInt8(127 + 127 * sin(wave * 1.3 + 4.2))
            }
        }
        pixels.withUnsafeBytes {
            surface.publish(pixels: $0, width: width, height: height, isOpaque: true)
        }
    }
}

struct ExternalScreen: View {

    @State private var producer = PlasmaProducer()

    @State private var lastInput = "Click the large surface, then move, scroll or type."

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("Frames drawn on another thread, published to an ExternalSurface and composited like any other view.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                GeometryReader { geometry in
                    ExternalSurfaceView(producer.surface)
                        .onInput(acceptsText: true) { input in
                            handle(input, size: geometry.size)
                        }
                }
                .frame(height: 240)
                .clipShape(RoundedRectangle(cornerRadius: 16))
                Text(lastInput)
                    .font(.footnote)
                    .monospacedDigit()
                HStack(spacing: 16) {
                    ExternalSurfaceView(producer.surface)
                        .frame(width: 160, height: 120)
                        .opacity(0.5)
                    ExternalSurfaceView(producer.surface, isSmooth: false)
                        .frame(width: 160, height: 120)
                        .rotationEffect(.degrees(8))
                }
            }
            .padding()
        }
        .onAppear { producer.start() }
        .onDisappear { producer.stop() }
    }

    /// Input the surface's producer would take: here, the pointer moves the
    /// ripple, and everything is described.
    private func handle(_ input: ExternalInput, size: CGSize) {
        func move(_ location: CGPoint) {
            guard size.width > 0, size.height > 0 else { return }
            producer.setCenter(CGPoint(x: location.x / size.width, y: location.y / size.height))
        }
        switch input {
        case let .pointer(phase, button, location):
            move(location)
            lastInput = "pointer \(phase) \(button) at \(Int(location.x)), \(Int(location.y))"
        case let .hover(location):
            if let location {
                move(location)
                lastInput = "hover at \(Int(location.x)), \(Int(location.y))"
            } else {
                lastInput = "hover left"
            }
        case let .scroll(x, y, _):
            lastInput = "scroll \(x), \(y)"
        case let .touch(phase, finger, location):
            move(location)
            lastInput = "touch \(phase) finger \(finger) at \(Int(location.x)), \(Int(location.y))"
        case let .key(key):
            lastInput = "key \(key.isDown ? "down" : "up") usage \(key.usage) code \(key.keyCode)"
        case let .text(text):
            lastInput = "text \"\(text)\""
        case let .focus(focused):
            lastInput = focused ? "focused" : "lost focus"
        }
    }
}
