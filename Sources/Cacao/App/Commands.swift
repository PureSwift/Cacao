//
//  Commands.swift
//  Cacao
//
//  Created by Alsey Coleman Miller on 11/13/26.
//

import Foundation
#if canImport(CoreGraphics)
import CoreGraphics
#endif

// MARK: - Commands

/// Conforming types represent a group of related commands that can be
/// exposed to the user via the main menu.
@MainActor
@preconcurrency
public protocol Commands {

    associatedtype Body: Commands

    @CommandsBuilder
    var body: Self.Body { get }
}

extension Never: Commands { }

/// A menu of commands, or a group of commands for a standard menu.
package struct CommandMenuContent {

    /// The menu's name.
    package var name: String

    /// Its items, as views: buttons, toggles, dividers and menus.
    package var content: AnyView
}

/// Commands Cacao describes directly instead of through their body.
@MainActor
internal protocol PrimitiveCommands {

    var menus: [CommandMenuContent] { get }
}

@MainActor
internal func commandMenus<C: Commands>(of commands: C) -> [CommandMenuContent] {
    if let primitive = commands as? any PrimitiveCommands {
        return primitive.menus
    }
    return commandMenus(of: commands.body)
}

/// Constructs command sets from multi-expression closures.
@MainActor
@resultBuilder
public struct CommandsBuilder {

    public static func buildExpression<Content: Commands>(_ content: Content) -> Content {
        content
    }

    public static func buildBlock() -> EmptyCommands {
        EmptyCommands()
    }

    public static func buildBlock<Content: Commands>(_ content: Content) -> Content {
        content
    }

    public static func buildBlock<each Content: Commands>(_ content: repeat each Content) -> _TupleCommands {
        var menus: [CommandMenuContent] = []
        for commands in repeat each content {
            menus += commandMenus(of: commands)
        }
        return _TupleCommands(menus: menus)
    }

    public static func buildOptional<Content: Commands>(_ content: Content?) -> _TupleCommands {
        _TupleCommands(menus: content.map(commandMenus(of:)) ?? [])
    }

    public static func buildEither<First: Commands>(first content: First) -> _TupleCommands {
        _TupleCommands(menus: commandMenus(of: content))
    }

    public static func buildEither<Second: Commands>(second content: Second) -> _TupleCommands {
        _TupleCommands(menus: commandMenus(of: content))
    }
}

/// Several commands together.
public struct _TupleCommands: Commands, PrimitiveCommands {

    internal let menus: [CommandMenuContent]

    public var body: Never { fatalError("_TupleCommands is primitive") }
}

/// An empty group of commands.
public struct EmptyCommands: Commands, PrimitiveCommands {

    public init() { }

    var menus: [CommandMenuContent] { [] }

    public var body: Never { fatalError("EmptyCommands is primitive") }
}

/// Command menus are stand-alone, top-level containers for controls that
/// perform related, app-specific commands.
public struct CommandMenu<Content: View>: Commands, PrimitiveCommands {

    internal let name: String

    internal let content: Content

    public init(_ nameKey: LocalizedStringKey, @ViewBuilder content: () -> Content) {
        self.name = nameKey.key
        self.content = content()
    }

    @_disfavoredOverload
    public init<S: StringProtocol>(_ name: S, @ViewBuilder content: () -> Content) {
        self.name = String(name)
        self.content = content()
    }

    var menus: [CommandMenuContent] {
        [CommandMenuContent(name: name, content: AnyView(content))]
    }

    public var body: Never { fatalError("CommandMenu is primitive") }
}

/// The standard locations that you can place new command groups relative to.
public struct CommandGroupPlacement: Sendable {

    /// The standard menu the placement is in.
    internal let menu: String

    public static let appInfo = CommandGroupPlacement(menu: "")
    public static let appSettings = CommandGroupPlacement(menu: "")
    public static let systemServices = CommandGroupPlacement(menu: "")
    public static let appVisibility = CommandGroupPlacement(menu: "")
    public static let appTermination = CommandGroupPlacement(menu: "")
    public static let newItem = CommandGroupPlacement(menu: "File")
    public static let saveItem = CommandGroupPlacement(menu: "File")
    public static let importExport = CommandGroupPlacement(menu: "File")
    public static let printItem = CommandGroupPlacement(menu: "File")
    public static let undoRedo = CommandGroupPlacement(menu: "Edit")
    public static let pasteboard = CommandGroupPlacement(menu: "Edit")
    public static let textEditing = CommandGroupPlacement(menu: "Edit")
    public static let textFormatting = CommandGroupPlacement(menu: "Format")
    public static let toolbar = CommandGroupPlacement(menu: "View")
    public static let sidebar = CommandGroupPlacement(menu: "View")
    public static let windowSize = CommandGroupPlacement(menu: "Window")
    public static let windowList = CommandGroupPlacement(menu: "Window")
    public static let windowArrangement = CommandGroupPlacement(menu: "Window")
    public static let help = CommandGroupPlacement(menu: "Help")
}

/// Groups of controls that you can add to existing command menus. The
/// app menu's placements have the empty name.
public struct CommandGroup<Content: View>: Commands, PrimitiveCommands {

    internal let placement: CommandGroupPlacement

    internal let content: Content

    public init(before group: CommandGroupPlacement, @ViewBuilder addition: () -> Content) {
        self.placement = group
        self.content = addition()
    }

    public init(after group: CommandGroupPlacement, @ViewBuilder addition: () -> Content) {
        self.placement = group
        self.content = addition()
    }

    public init(replacing group: CommandGroupPlacement, @ViewBuilder addition: () -> Content) {
        self.placement = group
        self.content = addition()
    }

    var menus: [CommandMenuContent] {
        [CommandMenuContent(name: placement.menu, content: AnyView(content))]
    }

    public var body: Never { fatalError("CommandGroup is primitive") }
}

/// Standard command sets, whose commands Cacao's views handle themselves.
public struct SidebarCommands: Commands, PrimitiveCommands {
    public init() { }
    var menus: [CommandMenuContent] { [] }
    public var body: Never { fatalError() }
}

public struct ToolbarCommands: Commands, PrimitiveCommands {
    public init() { }
    var menus: [CommandMenuContent] { [] }
    public var body: Never { fatalError() }
}

public struct TextEditingCommands: Commands, PrimitiveCommands {
    public init() { }
    var menus: [CommandMenuContent] { [] }
    public var body: Never { fatalError() }
}

public struct TextFormattingCommands: Commands, PrimitiveCommands {
    public init() { }
    var menus: [CommandMenuContent] { [] }
    public var body: Never { fatalError() }
}

public struct InspectorCommands: Commands, PrimitiveCommands {
    public init() { }
    var menus: [CommandMenuContent] { [] }
    public var body: Never { fatalError() }
}

extension Scene {

    /// Adds commands to the scene.
    public func commands<Content: Commands>(@CommandsBuilder content: () -> Content) -> some Scene {
        let menus = commandMenus(of: content())
        return _SceneModifierContent(content: self) { $0.commands += menus }
    }
}

// MARK: - The commands layer

/// Command menus laid out in a window, unseen, so their buttons' keyboard
/// shortcuts work and a host can show them as menus.
internal struct _CommandsLayer: View {

    let menus: [CommandMenuContent]

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(0..<menus.count, id: \.self) { index in
                VStack(alignment: .leading, spacing: 0) {
                    menus[index].content
                }
                .modifier(_CommandMenuMarker(name: menus[index].name))
            }
        }
        .fixedSize()
        .opacity(0)
        .accessibilityHidden(true)
    }
}

internal struct _CommandMenuMarker: ViewModifier, PrimitiveViewModifier {

    let name: String

    func resolve(content: any View, in context: ResolveContext) -> Resolution {
        var attributes = NodeAttributes()
        attributes.commandMenu = name
        return Resolution(children: [ChildView(key: 0, view: content)], attributes: attributes)
    }

    typealias Body = Never
}

/// An item of a command menu, as a host shows it.
package struct CommandItem {

    package enum Kind: Equatable {
        case button
        case separator
    }

    package var kind: Kind

    package var title: String

    package var shortcut: KeyboardShortcut?

    package var isEnabled: Bool

    /// Performs the item's action.
    package var action: @MainActor () -> Void
}

/// A menu of command items, as a host shows it.
package struct CommandMenuItems {

    package var name: String

    package var items: [CommandItem]
}

extension ViewGraph {

    /// The command menus in the window, merged by name, with the items
    /// their views show now.
    package func commandMenus() -> [CommandMenuItems] {
        var menus: [CommandMenuItems] = []
        root.forEachDisplayedNode { node in
            guard let name = node.attributes.commandMenu else { return }
            let items = node.commandItems()
            if let index = menus.firstIndex(where: { $0.name == name }) {
                menus[index].items += [CommandItem(kind: .separator, title: "", shortcut: nil, isEnabled: true, action: { })] + items
            } else {
                menus.append(CommandMenuItems(name: name, items: items))
            }
        }
        return menus
    }
}

extension ViewNode {

    /// The buttons and dividers in this subtree, in order.
    func commandItems() -> [CommandItem] {
        var items: [CommandItem] = []
        var shortcut: KeyboardShortcut?
        func visit(_ node: ViewNode) {
            if node.behavior is DividerBehavior {
                items.append(CommandItem(kind: .separator, title: "", shortcut: nil, isEnabled: true, action: { }))
                return
            }
            if let own = node.attributes.keyboardShortcut {
                shortcut = own
            }
            if let tap = node.attributes.tap ?? node.attributes.disabledTap {
                items.append(CommandItem(
                    kind: .button,
                    title: node.textContent(),
                    shortcut: shortcut,
                    isEnabled: node.attributes.tap != nil,
                    action: tap.action
                ))
                shortcut = nil
                return
            }
            for child in node.orderedChildren {
                visit(child)
            }
            if node.attributes.keyboardShortcut != nil {
                shortcut = nil
            }
        }
        for child in orderedChildren {
            visit(child)
        }
        return items
    }

    /// The text this subtree shows, joined.
    func textContent() -> String {
        var strings: [String] = []
        forEachDisplayedNode { node in
            if case let .text(text)? = node.behavior?.displayContent(node: node) {
                strings.append(text.string)
            }
        }
        return strings.joined(separator: " ")
    }
}

// MARK: - Settings

/// The identifier of the settings window.
package let settingsWindowID = "cacao.settings"

/// A scene that presents an interface for viewing and modifying an app's
/// settings, opened from the app menu or with the settings shortcut.
public struct Settings<Content: View>: Scene, PrimitiveScene {

    internal let content: Content

    public init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    public typealias Body = Never

    public var body: Never { fatalError("Settings is a primitive scene") }

    func windows(modifiers: SceneModifiers) -> [WindowDescription] {
        collectedCommands.append(CommandMenuContent(name: "", content: AnyView(_SettingsCommand())))
        return [WindowDescription(
            title: "Settings",
            id: settingsWindowID,
            defaultSize: modifiers.defaultSize,
            rootView: AnyView(content),
            isUnique: true,
            opensAtLaunch: false
        )]
    }
}

private struct _SettingsCommand: View {

    @Environment(\.openWindow) private var openWindow

    var body: some View {
        Button("Settings…") { openWindow(id: settingsWindowID) }
            .keyboardShortcut(",", modifiers: .command)
    }
}

/// An action that presents the settings scene for an app.
public struct OpenSettingsAction: Sendable {

    let openWindow: OpenWindowAction

    @MainActor
    public func callAsFunction() {
        openWindow(id: settingsWindowID)
    }
}

extension EnvironmentValues {

    /// A Settings presentation action stored in a view's environment.
    public var openSettings: OpenSettingsAction {
        OpenSettingsAction(openWindow: openWindow)
    }
}

/// A view that opens the Settings scene defined by an app.
public struct SettingsLink<Label: View>: View {

    internal let label: Label

    @Environment(\.openWindow) private var openWindow

    public init(@ViewBuilder label: () -> Label) {
        self.label = label()
    }

    public var body: some View {
        Button { openWindow(id: settingsWindowID) } label: { label }
    }
}

extension SettingsLink where Label == Text {

    public init() {
        self.init { Text("Settings…") }
    }
}

// MARK: - Menu bar extras

/// A menu bar extra, as a host shows it: an icon or title in the system's
/// status area, with a menu of its content's buttons.
package struct StatusItemDescription {

    package var title: String

    package var systemImage: String?

    /// The menu's items, as views.
    package var content: AnyView
}

/// Status items scenes add, collected while finding their windows.
@MainActor
internal var collectedStatusItems: [StatusItemDescription] = []

/// A scene that renders itself as a persistent control in the system menu
/// bar (the system tray on Linux), showing its content as a menu.
public struct MenuBarExtra<Label: View, Content: View>: Scene, PrimitiveScene {

    internal let title: String

    internal let systemImage: String?

    internal let content: Content

    public typealias Body = Never

    public var body: Never { fatalError("MenuBarExtra is a primitive scene") }

    func windows(modifiers: SceneModifiers) -> [WindowDescription] {
        collectedStatusItems.append(StatusItemDescription(title: title, systemImage: systemImage, content: AnyView(content)))
        return []
    }
}

extension MenuBarExtra where Label == Text {

    public init(_ titleKey: LocalizedStringKey, @ViewBuilder content: () -> Content) {
        self.title = titleKey.key
        self.systemImage = nil
        self.content = content()
    }

    @_disfavoredOverload
    public init<S: StringProtocol>(_ title: S, @ViewBuilder content: () -> Content) {
        self.title = String(title)
        self.systemImage = nil
        self.content = content()
    }

    public init(_ titleKey: LocalizedStringKey, isInserted: Binding<Bool>, @ViewBuilder content: () -> Content) {
        self.init(titleKey, content: content)
    }
}

extension MenuBarExtra where Label == Cacao.Label<Text, Image> {

    public init(_ titleKey: LocalizedStringKey, systemImage: String, @ViewBuilder content: () -> Content) {
        self.title = titleKey.key
        self.systemImage = systemImage
        self.content = content()
    }

    @_disfavoredOverload
    public init<S: StringProtocol>(_ title: S, systemImage: String, @ViewBuilder content: () -> Content) {
        self.title = String(title)
        self.systemImage = systemImage
        self.content = content()
    }

    public init(_ titleKey: LocalizedStringKey, systemImage: String, isInserted: Binding<Bool>, @ViewBuilder content: () -> Content) {
        self.init(titleKey, systemImage: systemImage, content: content)
    }
}

extension Scene {

    /// The menu bar extras of this scene.
    package func statusItemDescriptions() -> [StatusItemDescription] {
        collectedStatusItems = []
        _ = sceneWindows(of: self, modifiers: SceneModifiers())
        defer { collectedStatusItems = [] }
        return collectedStatusItems
    }
}

/// A graph for the content of a menu that isn't in a window, like a menu
/// bar extra's, to read its items from.
extension ViewGraph {

    /// The buttons and dividers the graph's content shows.
    package func menuItems() -> [CommandItem] {
        root.commandItems()
    }
}
