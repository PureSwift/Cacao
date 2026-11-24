//
//  WindowStyle.swift
//  Cacao
//
//  Created by Alsey Coleman Miller on 11/24/26.
//

/// A specification for the appearance and interaction of a window: who
/// draws its title bar.
public protocol WindowStyle {

    /// Which of Cacao's window styles this is.
    var _kind: WindowStyleKind { get }
}

/// The window styles Cacao has.
public struct WindowStyleKind: Hashable, Sendable {

    package enum Value: Hashable, Sendable {
        case automatic
        case titleBar
        case hiddenTitleBar
        case plain
    }

    package let value: Value

    package init(_ value: Value) {
        self.value = value
    }

    /// Whether windows of this style have no decorations from the system,
    /// so the app draws their title bar, if they have one.
    package var drawsOwnDecorations: Bool {
        value == .hiddenTitleBar || value == .plain
    }

    /// The chrome a window of this style gets under a look: the automatic
    /// style is the desktop's own title bar in the desktop's look on Linux,
    /// whose desktop Cacao draws, and the system's elsewhere.
    package func chrome(for look: InterfaceLook) -> WindowChrome {
        switch value {
        case .titleBar: .system
        case .hiddenTitleBar: .buttonsOnly
        case .plain: .none
        case .automatic: look.value == .desktop && Self.desktopDrawsTitleBars ? .titleBar : .system
        }
    }

    /// Whether the desktop's look includes its title bars, rather than the
    /// system's: where Cacao's look is the desktop's.
    private static var desktopDrawsTitleBars: Bool {
        #if os(Linux)
        true
        #else
        false
        #endif
    }
}

/// Who draws a window's title bar and window buttons.
package enum WindowChrome: Hashable, Sendable {

    /// The system, with its decorations.
    case system

    /// The app: the desktop's title bar, with the window buttons, which a
    /// toolbar at the top of the window joins.
    case titleBar

    /// The app: only the window buttons, over the content.
    case buttonsOnly

    /// The app, which draws nothing for the window but its content.
    case none

    /// Whether the window has no decorations from the system.
    package var drawsOwnDecorations: Bool {
        self != .system
    }
}

/// The default window style: a title bar, with the window buttons. In the
/// desktop's look on Linux, the desktop's own title bar, drawn by the app
/// and joined by a toolbar at the top of the window; elsewhere the
/// system's.
public struct DefaultWindowStyle: WindowStyle {
    public init() { }
    public var _kind: WindowStyleKind { WindowStyleKind(.automatic) }
}

/// A window style with the system's title bar and borders.
public struct TitleBarWindowStyle: WindowStyle {
    public init() { }
    public var _kind: WindowStyleKind { WindowStyleKind(.titleBar) }
}

/// A window style with no title bar: the content fills the window, with
/// the window buttons over it, and the window moves from where views say
/// with `WindowDragGesture`.
public struct HiddenTitleBarWindowStyle: WindowStyle {
    public init() { }
    public var _kind: WindowStyleKind { WindowStyleKind(.hiddenTitleBar) }
}

/// A window style with no decorations at all: no title bar, borders or
/// window buttons. The window moves from where views say with
/// `WindowDragGesture`, and resizes from its edges.
public struct PlainWindowStyle: WindowStyle {
    public init() { }
    public var _kind: WindowStyleKind { WindowStyleKind(.plain) }
}

extension WindowStyle where Self == DefaultWindowStyle {

    /// The default window style.
    public static var automatic: DefaultWindowStyle { DefaultWindowStyle() }
}

extension WindowStyle where Self == TitleBarWindowStyle {

    /// A window style with the system's title bar.
    public static var titleBar: TitleBarWindowStyle { TitleBarWindowStyle() }
}

extension WindowStyle where Self == HiddenTitleBarWindowStyle {

    /// A window style with no title bar.
    public static var hiddenTitleBar: HiddenTitleBarWindowStyle { HiddenTitleBarWindowStyle() }
}

extension WindowStyle where Self == PlainWindowStyle {

    /// A window style with no decorations.
    public static var plain: PlainWindowStyle { PlainWindowStyle() }
}

extension Scene {

    /// Sets the style of the scene's windows: whether the system draws
    /// their title bar and borders, or the app does.
    ///
    /// A window without the system's decorations moves from the views
    /// that have a `WindowDragGesture`, and resizes from its edges:
    ///
    /// ```swift
    /// WindowGroup {
    ///     VStack(spacing: 0) {
    ///         MyTitleBar()
    ///             .gesture(WindowDragGesture())
    ///         Content()
    ///     }
    /// }
    /// .windowStyle(.plain)
    /// ```
    public func windowStyle<S: WindowStyle>(_ style: S) -> some Scene {
        let kind = style._kind
        return _SceneModifierContent(content: self) { $0.windowStyle = kind }
    }
}
