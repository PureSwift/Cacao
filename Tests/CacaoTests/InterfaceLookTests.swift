import CacaoRender
import CacaoTokens
import Foundation
#if canImport(CoreGraphics)
import CoreGraphics
#endif
import Testing
@testable import Cacao

@MainActor
@Suite struct InterfaceLookTests {

    /// Every color the display list fills with, gradients' stops included.
    func fills(in graph: ViewGraph) -> [Color.Resolved] {
        func collect(_ list: DisplayList) -> [Color.Resolved] {
            list.items.flatMap { item -> [Color.Resolved] in
                switch item.value {
                case let .content(.color(color)): [color]
                case let .content(.roundedRectangle(rectangle)): [rectangle.color]
                case let .content(.shape(shape)): [shape.color] + (shape.gradient?.stops.map(\.color) ?? [])
                case .content: []
                case let .effect(_, nested): collect(nested)
                }
            }
        }
        return collect(graph.displayList())
    }

    /// The corner radii of the rounded rectangles drawn.
    func radii(in graph: ViewGraph) -> [CGFloat] {
        func collect(_ list: DisplayList) -> [CGFloat] {
            list.items.flatMap { item -> [CGFloat] in
                switch item.value {
                case let .content(.roundedRectangle(rectangle)): [rectangle.cornerRadius]
                case .content: []
                case let .effect(_, nested): collect(nested)
                }
            }
        }
        return collect(graph.displayList())
    }

    /// The tokens views get by default, with the platform's accent.
    let light = EnvironmentValues().styleTokens

    /// The dark tokens views get.
    var dark: StyleTokens {
        var environment = EnvironmentValues()
        environment.colorScheme = .dark
        return environment.styleTokens
    }

    @Test func appsDefaultToTheDesktopsLook() {
        #expect(InterfaceLook.appDefault == .desktop)
        // Views outside an app's windows have the stock look.
        #expect(EnvironmentValues().interfaceLook == .stock)
    }

    @Test func buttonsArePushButtons() {
        let desktop = layout(Button("Save") { }.probe("button").interfaceLook(.desktop))
        #expect(desktop.frame("button").height == light.metrics.controlHeight)
        #expect(fills(in: desktop).contains(light.pushButton.fill.top))
        #expect(fills(in: desktop).contains(light.pushButton.fill.bottom))
        // In the stock look, an automatic button is borderless: as tall as
        // its label.
        let stock = layout(Button("Save") { }.probe("button"))
        #expect(stock.frame("button").height < light.metrics.controlHeight)
    }

    @Test func borderedButtonsFollowTheLook() {
        let desktop = layout(Button("Save") { }.buttonStyle(.bordered).probe("button").interfaceLook(.desktop))
        #expect(desktop.frame("button").height == light.metrics.controlHeight)
        let small = layout(Button("Save") { }.buttonStyle(.bordered).controlSize(.small).probe("button").interfaceLook(.desktop))
        #expect(small.frame("button").height == light.metrics.smallControlHeight)
    }

    @Test func prominentButtonsAreFilledWithTheAccent() {
        let graph = layout(Button("Save") { }.buttonStyle(.borderedProminent).interfaceLook(.desktop))
        #expect(fills(in: graph).contains(light.defaultButton.fill.bottom))
        // A tint tints the tokens too.
        let tinted = layout(Button("Save") { }.buttonStyle(.borderedProminent).tint(.orange).interfaceLook(.desktop))
        let orange = StyleTokens(accentColor: Color.orange.resolve(in: EnvironmentValues()))
        #expect(fills(in: tinted).contains(orange.defaultButton.fill.bottom))
    }

    @Test func darkWindowsHaveDarkControls() {
        let graph = layout(
            Button("Save") { }
                .interfaceLook(.desktop)
                .environment(\.colorScheme, .dark)
        )
        #expect(fills(in: graph).contains(dark.pushButton.fill.bottom))
        #expect(!fills(in: graph).contains(light.pushButton.fill.bottom))
    }

    @Test func aViewCanAskForTheStockLook() {
        let graph = layout(
            VStack {
                Button("Stock") { }.probe("stock").interfaceLook(.stock)
                Button("Desktop") { }.probe("desktop")
            }
            .interfaceLook(.desktop)
        )
        #expect(graph.frame("stock").height < light.metrics.controlHeight)
        #expect(graph.frame("desktop").height == light.metrics.controlHeight)
    }

    @Test func customStylesDrawTheSameInEitherLook() {
        struct Underlined: ButtonStyle {
            func makeBody(configuration: Configuration) -> some View {
                configuration.label.padding(2)
            }
        }
        let desktop = layout(Button("Go") { }.buttonStyle(Underlined()).probe("button").interfaceLook(.desktop))
        let stock = layout(Button("Go") { }.buttonStyle(Underlined()).probe("button"))
        #expect(desktop.frame("button") == stock.frame("button"))
    }

    @Test func segmentedPickersAreOneShadedTrack() {
        struct Sizes: View {
            @State var size = 1
            var body: some View {
                Picker("Size", selection: $size) {
                    Text("Small").tag(0)
                    Text("Medium").tag(1)
                    Text("Large").tag(2)
                }
                .pickerStyle(.segmented)
                .probe("picker")
            }
        }
        let graph = layout(Sizes().interfaceLook(.desktop))
        #expect(graph.frame("picker").height == light.metrics.controlHeight)
        let colors = fills(in: graph)
        #expect(colors.contains(light.segmentedControl.selectedFill.bottom))
        #expect(colors.contains(light.segmentedControl.divider))
    }

    @Test func searchFieldsArePills() {
        struct Search: View {
            @State var text = ""
            var body: some View {
                VStack {
                    TextField("Search", text: $text)
                        .environment(\.isSearchField, true)
                        .probe("search")
                    TextField("Name", text: $text)
                        .probe("name")
                }
            }
        }
        let graph = layout(Search().interfaceLook(.desktop))
        let radii = radii(in: graph)
        #expect(radii.contains(light.radii.searchField))
        #expect(radii.contains(light.radii.control))
        #expect(fills(in: graph).contains(light.searchField.background))
        // The search field's text starts after its magnifier.
        #expect(graph.frame("search").height == graph.frame("name").height)
    }

    @Test func sidebarSelectionIsTintedWithTheAccent() {
        struct Sidebar: View {
            @State var selection: Int? = 1
            var body: some View {
                List(0..<3, id: \.self, selection: $selection) { index in
                    Text("Place \(index)")
                }
                .listStyle(.sidebar)
            }
        }
        let graph = layout(Sidebar().interfaceLook(.desktop), width: 220, height: 300)
        graph.settle()
        let colors = fills(in: graph)
        #expect(colors.contains(light.sidebar.selection))
        #expect(colors.contains(light.sidebar.background))
        // The stock sidebar's highlight is the accent, faded.
        let stock = layout(Sidebar(), width: 220, height: 300)
        stock.settle()
        #expect(!fills(in: stock).contains(light.sidebar.selection))
    }

    @Test func menusAreOpaquePanels() {
        let graph = layout(
            _MenuContent(content: AnyView(Button("Rename") { }))
                .interfaceLook(.desktop)
        )
        #expect(fills(in: graph).contains(light.menu.background))
        #expect(radii(in: graph).contains(light.radii.menu))
    }

    @Test func checkboxesAreFilledWithTheAccentWhenOn() {
        let graph = layout(
            Toggle("Agree", isOn: .constant(true))
                .toggleStyle(.checkbox)
                .interfaceLook(.desktop)
        )
        #expect(fills(in: graph).contains(light.checkbox.checkedFill))
    }

    @Test func windowsHaveTheDesktopsBackground() {
        var environment = EnvironmentValues()
        #expect(environment.windowBackgroundColor == Color.Resolved(red: 1, green: 1, blue: 1))
        environment.interfaceLook = .desktop
        #expect(environment.windowBackgroundColor == light.window.background)
        environment.colorScheme = .dark
        #expect(environment.windowBackgroundColor == dark.window.background)
    }
}
