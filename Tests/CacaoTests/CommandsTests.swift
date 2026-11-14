import Foundation
#if canImport(CoreGraphics)
import CoreGraphics
#endif
import Testing
@testable import Cacao

@MainActor
final class CommandLog {
    static var events: [String] = []
}

@MainActor
struct CommandsApp: App {

    init() { }

    var body: some Scene {
        WindowGroup("Main") {
            Text("Content")
        }
        .commands {
            CommandMenu("Tools") {
                Button("Run") { CommandLog.events.append("run") }
                    .keyboardShortcut("r", modifiers: [.command, .shift])
                Divider()
                Button("Stop") { CommandLog.events.append("stop") }
                    .disabled(true)
            }
            CommandGroup(after: .newItem) {
                Button("New Note") { CommandLog.events.append("note") }
            }
        }
        Settings {
            Text("Preferences")
        }
        MenuBarExtra("Status", systemImage: "bolt.fill") {
            Button("Open") { CommandLog.events.append("open") }
            Divider()
            Button("Quit") { CommandLog.events.append("quit") }
        }
    }
}

@MainActor
@Suite struct CommandsTests {

    @Test func scenesDescribeCommandsSettingsAndExtras() {
        let app = CommandsApp()
        let windows = app.body.windowDescriptions()
        #expect(windows.map(\.title) == ["Main", "Settings"])
        #expect(windows.map(\.opensAtLaunch) == [true, false])
        #expect(windows[1].isUnique)
        let extras = app.body.statusItemDescriptions()
        #expect(extras.map(\.title) == ["Status"])
        #expect(extras.first?.systemImage == "bolt.fill")
    }

    @Test func windowsShowTheAppsCommands() {
        CommandLog.events = []
        let app = CommandsApp()
        let window = app.body.windowDescriptions()[0]
        let graph = ViewGraph(rootView: window.rootView)
        graph.layout(in: CGSize(width: 400, height: 300))
        // The commands draw nothing in the window.
        #expect(graph.accessibilityTree().children.map(\.label) == ["Content"])
        let menus = graph.commandMenus()
        #expect(menus.map(\.name) == ["Tools", "File", ""])
        let tools = menus[0].items
        #expect(tools.map(\.kind) == [.button, .separator, .button])
        #expect(tools.map(\.title) == ["Run", "", "Stop"])
        #expect(tools[0].shortcut == KeyboardShortcut("r", modifiers: [.command, .shift]))
        #expect(tools[2].isEnabled == false)
        #expect(menus[2].items.map(\.title) == ["Settings…"])
        tools[0].action()
        #expect(CommandLog.events == ["run"])
    }

    @Test func commandShortcutsWorkInTheWindow() {
        CommandLog.events = []
        let window = CommandsApp().body.windowDescriptions()[0]
        let graph = ViewGraph(rootView: window.rootView)
        graph.layout(in: CGSize(width: 400, height: 300))
        #if os(macOS)
        let modifiers: KeyModifiers = [.command, .shift]
        #else
        let modifiers: KeyModifiers = [.control, .shift]
        #endif
        graph.keyDown(.character("r"), modifiers: modifiers)
        #expect(CommandLog.events == ["run"])
    }

    @Test func menuBarExtraContentBecomesMenuItems() {
        CommandLog.events = []
        let extra = CommandsApp().body.statusItemDescriptions()[0]
        let graph = ViewGraph(rootView: extra.content)
        graph.layout(in: CGSize(width: 320, height: 400))
        let items = graph.menuItems()
        #expect(items.map(\.title) == ["Open", "", "Quit"])
        items[2].action()
        #expect(CommandLog.events == ["quit"])
    }
}
