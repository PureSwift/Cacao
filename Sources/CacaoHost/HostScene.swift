//
//  HostScene.swift
//  CacaoHost
//
//  Created by Alsey Coleman Miller on 11/19/26.
//

import Foundation
#if canImport(CoreGraphics)
import CoreGraphics
#endif
import CacaoRender

/// What a window shows: the host's client.
///
/// The host owns the window, the frame clock and input. Each frame it asks
/// the scene to update for the window's size, and for a display list when
/// anything changed; between frames it delivers the window's input. A UI
/// framework (Cacao's SwiftUI, or another) implements one scene per window.
@MainActor
public protocol HostScene: AnyObject {

    /// Input for the scene's window, at a time on the host's clock.
    func handle(_ event: HostEvent, time: Double)

    /// Whether the scene needs frames even without events.
    var isAnimating: Bool { get }

    /// Brings the scene to a frame's time and size. Returns whether what it
    /// draws changed.
    func update(_ frame: HostFrame) -> Bool

    /// What to draw, for the last update.
    func displayList() -> DisplayList

    /// What the scene wants of its window, read after each update.
    var windowState: HostWindowState { get }

    /// A frame of the scene was drawn.
    func didRender(time: Double)

    /// Counts of the scene's own, shown after the host's statistics.
    var statistics: String { get }

    /// The window is closing.
    func detach()

    /// What a press at a point does: moves the window, from a title bar
    /// the scene draws, or goes to the scene. Asked whenever the system
    /// asks, which may be on any pointer motion, so it's quick.
    ///
    /// A window without decorations is resized from its edges whatever
    /// the scene says.
    func hitTest(at point: CGPoint) -> HostHitTestResult
}

extension HostScene {

    public func didRender(time: Double) { }

    public var statistics: String { "" }

    public func detach() { }

    public func hitTest(at point: CGPoint) -> HostHitTestResult { .normal }
}

/// The time and geometry of a frame.
public struct HostFrame: Sendable {

    /// Seconds on the host's clock.
    public var time: Double

    /// The window's size, in points.
    public var size: CGSize

    /// Pixels per point.
    public var scale: CGFloat

    /// The parts of the window the system covers.
    public var safeArea: HostInsets

    public init(time: Double, size: CGSize, scale: CGFloat, safeArea: HostInsets = HostInsets()) {
        self.time = time
        self.size = size
        self.scale = scale
        self.safeArea = safeArea
    }
}

/// Distances in from a rectangle's edges.
public struct HostInsets: Equatable, Sendable {

    public var top: CGFloat

    public var left: CGFloat

    public var bottom: CGFloat

    public var right: CGFloat

    public init(top: CGFloat = 0, left: CGFloat = 0, bottom: CGFloat = 0, right: CGFloat = 0) {
        self.top = top
        self.left = left
        self.bottom = bottom
        self.right = right
    }
}

/// What a scene wants of its window.
public struct HostWindowState: Equatable, Sendable {

    /// The window's title, or `nil` to keep the one it has.
    public var title: String?

    public var cursor: HostCursor

    /// Whether typing goes to the scene as text, through an input method.
    public var acceptsTextInput: Bool

    /// Where text is being typed, for the input method's window.
    public var textInputArea: CGRect?

    /// The color behind the scene's drawing.
    public var backgroundColor: ResolvedColor

    public init(
        title: String? = nil,
        cursor: HostCursor = .default,
        acceptsTextInput: Bool = false,
        textInputArea: CGRect? = nil,
        backgroundColor: ResolvedColor = ResolvedColor(red: 1, green: 1, blue: 1)
    ) {
        self.title = title
        self.cursor = cursor
        self.acceptsTextInput = acceptsTextInput
        self.textInputArea = textInputArea
        self.backgroundColor = backgroundColor
    }
}

/// The system's pointers.
public enum HostCursor: Hashable, Sendable {
    case `default`
    case text
    case pointer
    case move
    case crosshair
    case horizontalResize
    case verticalResize
    case diagonalResize
    case antidiagonalResize
}

/// Whether the system shows light or dark windows.
public enum HostAppearance: Hashable, Sendable {
    case light
    case dark
}

// MARK: - Input

/// The phases of a press or gesture.
public enum HostPhase: Hashable, Sendable {
    case began
    case moved
    case ended
    case cancelled
}

/// Input for a window. Locations are in the window, in points.
public enum HostEvent {

    /// A mouse button, pressed, dragged and released. A drag reports the
    /// first button that was pressed.
    ///
    /// A finger on a touch screen is reported twice: as a touch, and as
    /// the primary button with `isFromTouch`, for scenes (or parts of one)
    /// that only know of pointers. A scene uses one or the other.
    case pointer(HostPhase, button: HostPointerButton, at: CGPoint, isFromTouch: Bool)

    /// The pointer moved with no button down, or left the window (`nil`).
    case hover(at: CGPoint?)

    /// A pinch: the total scale since it began.
    case magnify(HostPhase, scale: Double, at: CGPoint)

    /// A trackpad rotation: the total angle since it began, in radians,
    /// clockwise.
    case rotate(HostPhase, angle: Double, at: CGPoint)

    /// A finger on a touch screen.
    case touch(HostPhase, finger: UInt64, at: CGPoint)

    /// A wheel or trackpad scroll. Whole numbers are a wheel's notches;
    /// positive `y` scrolls away from the user.
    case scroll(x: Float, y: Float, at: CGPoint)

    /// A key pressed or released.
    case key(HostKeyEvent)

    /// Text typed, perhaps through an input method.
    case text(String)

    /// Files (`URL`) and text (`String`) dragged in from the system: over
    /// the window, then dropped.
    case drop(HostDropPhase, items: [Any], at: CGPoint)

    /// The window's size or scale changed.
    case geometryChanged

    /// The window became the key window or stopped being it, or was
    /// maximized, minimized or restored: see `HostWindow.isKey`,
    /// `isMaximized` and `isMinimized`.
    case windowStateChanged

    /// The system's appearance changed: it switched between light and
    /// dark, or changed its accent color or contrast
    /// (`HostRuntime.systemAccentColor`, `prefersIncreasedContrast`).
    case appearanceChanged(HostAppearance)
}

/// The buttons of a mouse.
public enum HostPointerButton: Hashable, Sendable {
    case primary
    case secondary
    case middle
}

/// A key going down or up.
public struct HostKeyEvent: Hashable, Sendable {

    /// Whether the key went down, rather than up.
    public var isDown: Bool

    /// Whether the key is repeating as it's held.
    public var isRepeat: Bool

    /// The physical key, whatever the keyboard layout: its usage in the
    /// USB HID keyboard page.
    public var usage: UInt32

    /// What the key means in the keyboard layout: a Unicode scalar for
    /// keys that type a character, and SDL's key code otherwise.
    public var keyCode: UInt32

    public var modifiers: HostKeyModifiers

    /// The key as a UI responds to it, if it's one a UI does. Characters
    /// only count with control or command held; typing arrives as text.
    public var key: HostKey?

    public init(
        isDown: Bool,
        isRepeat: Bool = false,
        usage: UInt32,
        keyCode: UInt32,
        modifiers: HostKeyModifiers = [],
        key: HostKey? = nil
    ) {
        self.isDown = isDown
        self.isRepeat = isRepeat
        self.usage = usage
        self.keyCode = keyCode
        self.modifiers = modifiers
        self.key = key
    }
}

public enum HostDropPhase: Hashable, Sendable {
    case moved
    case dropped
}

/// A key.
public enum HostKey: Hashable, Sendable {
    case left
    case right
    case up
    case down
    case home
    case end
    case pageUp
    case pageDown
    case backspace
    case delete
    case returnKey
    case escape
    case tab
    case character(Character)
}

/// The modifier keys held with a key.
public struct HostKeyModifiers: OptionSet, Hashable, Sendable {

    public let rawValue: Int

    public init(rawValue: Int) {
        self.rawValue = rawValue
    }

    public static let shift = HostKeyModifiers(rawValue: 1 << 0)
    public static let control = HostKeyModifiers(rawValue: 1 << 1)
    public static let option = HostKeyModifiers(rawValue: 1 << 2)
    public static let command = HostKeyModifiers(rawValue: 1 << 3)
}
