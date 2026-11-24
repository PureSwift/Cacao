import CacaoRender
import CacaoTokens
import Foundation
#if canImport(CoreGraphics)
import CoreGraphics
#endif
import Testing
@testable import Cacao

@MainActor
@Suite struct WindowChromeTests {

    final class Log {
        var actions: [String] = []
    }

    let metrics = StyleTokens.Metrics()

    /// A window's chrome around content, in the desktop's look.
    func window(
        _ content: some View,
        chrome: WindowChrome = .titleBar,
        buttons: WindowButtonLayout = .standard,
        log: Log = Log()
    ) -> ViewGraph {
        let controls = WindowControls(
            title: "Window",
            buttonLayout: buttons,
            close: { log.actions.append("close") },
            minimize: { log.actions.append("minimize") },
            toggleMaximized: { log.actions.append("maximize") }
        )
        let graph = layout(
            _WindowChrome(content: AnyView(content), chrome: chrome)
                .environment(\.windowControls, controls)
                .interfaceLook(.desktop),
            width: 600,
            height: 400
        )
        graph.settle()
        return graph
    }

    /// The center of a window button: the first at an end is the window
    /// button inset in from its edge.
    func button(_ index: Int, trailing: Bool = false, barHeight: CGFloat? = nil, width: CGFloat = 600) -> CGPoint {
        let offset = metrics.windowButtonInset + CGFloat(index) * (metrics.windowButtonSize + metrics.windowButtonSpacing)
            + metrics.windowButtonSize / 2
        return CGPoint(x: trailing ? width - offset : offset, y: (barHeight ?? metrics.titleBarHeight) / 2)
    }

    func click(_ graph: ViewGraph, at point: CGPoint) {
        graph.pointer(.began, at: point)
        graph.pointer(.ended, at: point)
    }

    @Test func theDesktopsLookDrawsTitleBarsOnLinux() {
        let automatic = WindowStyleKind(.automatic)
        #if os(Linux)
        #expect(automatic.chrome(for: .desktop) == .titleBar)
        #else
        #expect(automatic.chrome(for: .desktop) == .system)
        #endif
        #expect(automatic.chrome(for: .stock) == .system)
        // A scene can still ask for the system's title bar.
        #expect(WindowStyleKind(.titleBar).chrome(for: .desktop) == .system)
        #expect(WindowStyleKind(.hiddenTitleBar).chrome(for: .desktop) == .buttonsOnly)
        #expect(WindowStyleKind(.plain).chrome(for: .desktop) == .none)
        #expect(!WindowChrome.system.drawsOwnDecorations)
        #expect(WindowChrome.titleBar.drawsOwnDecorations)
    }

    @Test func theTitleBarShowsTheTitleAndMovesTheWindow() {
        let graph = window(Text("Body").probe("body"))
        #expect(graph.texts.contains("Window"))
        #expect(graph.frame("body").minY >= metrics.titleBarHeight)
        // The middle of the title bar, on the title, moves the window.
        #expect(graph.movesWindow(at: CGPoint(x: 300, y: metrics.titleBarHeight / 2)))
        #expect(graph.movesWindow(at: CGPoint(x: 500, y: 4)))
        // The content doesn't.
        #expect(!graph.movesWindow(at: CGPoint(x: 300, y: 200)))
    }

    @Test func windowButtonsCloseMinimizeAndMaximize() {
        let log = Log()
        let graph = window(Color.clear, log: log)
        for index in 0..<3 {
            // A press on a window button is the button's, not a move.
            #expect(!graph.movesWindow(at: button(index)))
            click(graph, at: button(index))
        }
        #expect(log.actions == ["close", "minimize", "maximize"])
    }

    @Test func buttonsGoWhereTheDesktopAsks() {
        let log = Log()
        let graph = window(Color.clear, buttons: WindowButtonLayout(setting: "appmenu:minimize,close"), log: log)
        // Toward the trailing edge: close is outermost.
        click(graph, at: button(0, trailing: true))
        click(graph, at: button(1, trailing: true))
        // Nothing at the leading end but the title bar.
        click(graph, at: button(0))
        #expect(log.actions == ["close", "minimize"])
        #expect(graph.movesWindow(at: button(0)))
    }

    @Test func aToolbarAtTheTopJoinsTheTitleBar() {
        let graph = window(
            NavigationStack {
                Color.white
                    .probe("body")
                    .navigationTitle("Notes")
                    .toolbar {
                        Button("Share") { }
                            .probe("share")
                    }
            }
        )
        // The toolbar is the title bar: one bar, its height, with the
        // window buttons on it.
        #expect(!graph.texts.contains("Window"))
        #expect(graph.texts.contains("Notes"))
        let body = graph.frame("body")
        #expect(body.minY == metrics.unifiedToolbarHeight)
        // It moves the window, but its buttons, and the window's, take
        // their presses.
        #expect(graph.movesWindow(at: CGPoint(x: 300, y: 10)))
        let share = graph.frame("share")
        #expect(!graph.movesWindow(at: CGPoint(x: share.midX, y: share.midY)))
        #expect(!graph.movesWindow(at: button(0, barHeight: metrics.unifiedToolbarHeight)))
        // The toolbar leaves room for the window buttons.
        #expect(share.maxX <= 600)
    }

    @Test func stacksInsideAScreenDontJoinTheTitleBar() {
        let graph = window(
            VStack(spacing: 0) {
                Text("Header").frame(height: 60)
                NavigationStack {
                    Text("Body").navigationTitle("Inner")
                }
            }
        )
        // A stack lower in the window has its own toolbar, below the title
        // bar.
        #expect(graph.texts.contains("Window"))
        #expect(graph.texts.contains("Inner"))
    }

    @Test func withoutATitleBarOnlyTheButtonsShow() {
        let log = Log()
        let graph = window(
            VStack(spacing: 0) {
                Text("Body").probe("body")
                Spacer()
            },
            chrome: .buttonsOnly,
            log: log
        )
        #expect(!graph.texts.contains("Window"))
        #expect(graph.frame("body").minY < metrics.titleBarHeight)
        click(graph, at: button(0))
        #expect(log.actions == ["close"])
        // The window moves from where the content draws nothing.
        #expect(graph.movesWindow(at: CGPoint(x: 590, y: 390)))
    }

    @Test func otherWindowsQuietTheirTitleBars() {
        var environment = EnvironmentValues()
        #expect(environment.appearsActive)
        environment.appearsActive = false
        #expect(!environment.appearsActive)
        let tokens = EnvironmentValues().styleTokens
        let graph = layout(
            _DesktopTitleBar(title: "Window", insets: TitleBarInsets(leading: 0, trailing: 0))
                .environment(\.appearsActive, false)
                .interfaceLook(.desktop)
        )
        var colors: [Color.Resolved] = []
        func collect(_ list: DisplayList) {
            for item in list.items {
                switch item.value {
                case let .content(.color(color)): colors.append(color)
                case let .content(.shape(shape)): colors.append(shape.color)
                case .content: break
                case let .effect(_, nested): collect(nested)
                }
            }
        }
        collect(graph.displayList())
        #expect(colors.contains(tokens.titleBar.inactiveBackground.top))
    }
}
