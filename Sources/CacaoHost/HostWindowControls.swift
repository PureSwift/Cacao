//
//  HostWindowControls.swift
//  CacaoHost
//
//  Created by Alsey Coleman Miller on 11/24/26.
//

import Foundation
#if canImport(CoreGraphics)
import CoreGraphics
#endif
import SDL3Swift
internal import CSDL3

/// Who draws a window's title bar and borders.
public enum HostWindowDecorations: Hashable, Sendable {

    /// The system: its title bar, window buttons and borders, as the
    /// window manager or a decoration library draws them.
    case system

    /// The scene: the window has no decorations of its own, and the scene
    /// draws its title bar and says where it moves and resizes the window,
    /// with `HostScene.hitTest(at:)`.
    case none
}

/// What a point in a window does when pressed, for the system to move or
/// resize the window from parts the scene draws.
public enum HostHitTestResult: Hashable, Sendable {

    /// The press goes to the scene.
    case normal

    /// The press moves the window, as on a title bar.
    case draggable

    /// The press resizes the window from an edge or corner.
    case resize(HostResizeEdge)
}

/// An edge or corner a window is resized from.
public enum HostResizeEdge: Hashable, Sendable, CaseIterable {
    case top
    case bottom
    case left
    case right
    case topLeft
    case topRight
    case bottomLeft
    case bottomRight
}

extension HostWindow {

    // MARK: State

    /// Whether the window fills the screen's work area, as when its zoom
    /// button was pressed.
    public var isMaximized: Bool {
        has(.maximized)
    }

    /// Whether the window is hidden in the dock or taskbar.
    public var isMinimized: Bool {
        has(.minimized)
    }

    /// Whether the window covers the whole screen.
    public var isFullScreen: Bool {
        has(.fullscreen)
    }

    /// Whether the user can resize the window.
    public var isResizable: Bool {
        has(.resizable)
    }

    private func has(_ option: SDLWindow.Option) -> Bool {
        SDL_GetWindowFlags(sdlWindow) & option.rawValue != 0
    }

    // MARK: Actions

    /// Hides the window in the dock or taskbar.
    public func minimize() {
        _ = SDL_MinimizeWindow(sdlWindow)
    }

    /// Makes the window fill the screen's work area.
    public func maximize() {
        _ = SDL_MaximizeWindow(sdlWindow)
    }

    /// Puts a maximized or minimized window back to its size and place.
    public func restore() {
        _ = SDL_RestoreWindow(sdlWindow)
    }

    /// Maximizes the window, or restores it if it's maximized: what a
    /// title bar's zoom button and a double click on it do.
    public func toggleMaximized() {
        if isMaximized {
            restore()
        } else {
            maximize()
        }
    }

    /// Shows the system's menu for the window, with items like Move,
    /// Resize and Always on Top, at a point in the window: what a
    /// secondary click on a title bar does. Returns whether the system has
    /// one.
    @discardableResult
    public func showSystemMenu(at point: CGPoint) -> Bool {
        SDL_ShowWindowSystemMenu(sdlWindow, Int32(point.x), Int32(point.y))
    }

    // MARK: Hit testing

    /// How far in from the edges of a window without decorations a press
    /// resizes it, in points.
    public static let resizeBorderWidth: CGFloat = 6

    /// Asks the scene, each time the system does, what a point in the
    /// window does when pressed: for windows the scene draws the title bar
    /// of, and for parts of any window that move it.
    func installHitTest() {
        let window = Unmanaged.passUnretained(self).toOpaque()
        _ = SDL_SetWindowHitTest(sdlWindow, { _, area, data in
            guard let area, let data, Thread.isMainThread else {
                return SDL_HITTEST_NORMAL
            }
            let point = CGPoint(x: CGFloat(area.pointee.x), y: CGFloat(area.pointee.y))
            return MainActor.assumeIsolated {
                let window = Unmanaged<HostWindow>.fromOpaque(data).takeUnretainedValue()
                return window.hitTest(at: point).sdlValue
            }
        }, window)
    }

    /// Stops asking the scene, before the window goes.
    func removeHitTest() {
        _ = SDL_SetWindowHitTest(sdlWindow, nil, nil)
    }

    /// What a press at a point does: near the edges of a window without
    /// decorations, resize it; elsewhere, what the scene says.
    func hitTest(at point: CGPoint) -> HostHitTestResult {
        if decorations == .none, isResizable, !isMaximized, !isFullScreen,
           let edge = Self.resizeEdge(at: point, in: size, border: Self.resizeBorderWidth) {
            return .resize(edge)
        }
        return scene?.hitTest(at: point) ?? .normal
    }

    /// The edge or corner a point is within `border` of, if any. Corners
    /// take twice the border along each edge, so they're easier to grab.
    package nonisolated static func resizeEdge(at point: CGPoint, in size: CGSize, border: CGFloat) -> HostResizeEdge? {
        guard size.width > 0, size.height > 0 else { return nil }
        let corner = border * 2
        let left = point.x < border
        let right = point.x >= size.width - border
        let top = point.y < border
        let bottom = point.y >= size.height - border
        let nearLeft = point.x < corner
        let nearRight = point.x >= size.width - corner
        let nearTop = point.y < corner
        let nearBottom = point.y >= size.height - corner
        if (top && nearLeft) || (left && nearTop) { return .topLeft }
        if (top && nearRight) || (right && nearTop) { return .topRight }
        if (bottom && nearLeft) || (left && nearBottom) { return .bottomLeft }
        if (bottom && nearRight) || (right && nearBottom) { return .bottomRight }
        if top { return .top }
        if bottom { return .bottom }
        if left { return .left }
        if right { return .right }
        return nil
    }
}

extension HostHitTestResult {

    /// SDL's value for the result.
    var sdlValue: SDL_HitTestResult {
        switch self {
        case .normal: SDL_HITTEST_NORMAL
        case .draggable: SDL_HITTEST_DRAGGABLE
        case let .resize(edge):
            switch edge {
            case .top: SDL_HITTEST_RESIZE_TOP
            case .bottom: SDL_HITTEST_RESIZE_BOTTOM
            case .left: SDL_HITTEST_RESIZE_LEFT
            case .right: SDL_HITTEST_RESIZE_RIGHT
            case .topLeft: SDL_HITTEST_RESIZE_TOPLEFT
            case .topRight: SDL_HITTEST_RESIZE_TOPRIGHT
            case .bottomLeft: SDL_HITTEST_RESIZE_BOTTOMLEFT
            case .bottomRight: SDL_HITTEST_RESIZE_BOTTOMRIGHT
            }
        }
    }
}
