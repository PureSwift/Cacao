//
//  HostPopup.swift
//  CacaoHost
//
//  Created by Alsey Coleman Miller on 11/24/26.
//

#if canImport(CoreGraphics)
import CoreGraphics
#endif
import Foundation
import SDL3Swift

/// Where a popup (a menu, picker or popover) opens: next to a rectangle in
/// the window it belongs to, as a surface of its own that can extend past
/// the window's edges.
///
/// The system keeps the popup on the screen: it moves it along the edge it
/// opens from, flips it to the other side of the anchor, or makes it
/// shorter. `HostWindow.popupFrame` says where it went.
public struct HostPopupPlacement: Equatable, Sendable {

    /// The side of the anchor a popup opens on.
    public enum Edge: Hashable, Sendable {
        /// Below the anchor, its leading edges lined up: a menu from a
        /// button.
        case bottom
        /// Above the anchor, its leading edges lined up.
        case top
        /// After the anchor, their tops lined up: a submenu.
        case trailing
        /// Before the anchor, their tops lined up.
        case leading
    }

    /// The rectangle the popup opens next to, in the parent's points: the
    /// parent window's, or the parent popup's, from its top left corner.
    public var anchor: CGRect

    public var edge: Edge

    /// Moves the popup from where the edge puts it, as for a gap between
    /// a button and its menu.
    public var offset: CGSize

    /// The popup's size, in points, without its margins.
    public var size: CGSize

    /// Space around the popup in its surface, for a shadow, that isn't part
    /// of it: it's placed by the rectangle inside them, and they don't take
    /// input.
    public var margins: HostInsets

    /// Whether the popup takes the keyboard and dismisses itself when the
    /// user clicks outside the app, as a menu does.
    public var grabsInput: Bool

    public init(
        anchor: CGRect,
        edge: Edge = .bottom,
        offset: CGSize = .zero,
        size: CGSize,
        margins: HostInsets = HostInsets(),
        grabsInput: Bool = true
    ) {
        self.anchor = anchor
        self.edge = edge
        self.offset = offset
        self.size = size
        self.margins = margins
        self.grabsInput = grabsInput
    }

    /// Where the popup goes in its parent with no screen edge in the way.
    public var frame: CGRect {
        var origin: CGPoint
        switch edge {
        case .bottom: origin = CGPoint(x: anchor.minX, y: anchor.maxY)
        case .top: origin = CGPoint(x: anchor.minX, y: anchor.minY - size.height)
        case .trailing: origin = CGPoint(x: anchor.maxX, y: anchor.minY)
        case .leading: origin = CGPoint(x: anchor.minX - size.width, y: anchor.minY)
        }
        origin.x += offset.width
        origin.y += offset.height
        return CGRect(origin: origin, size: size)
    }

    /// The size of the popup's surface: the popup and its margins.
    var surfaceSize: CGSize {
        CGSize(
            width: size.width + margins.left + margins.right,
            height: size.height + margins.top + margins.bottom
        )
    }
}

extension HostRuntime {

    /// Whether popups open as surfaces of their own, outside their window,
    /// rather than drawn inside it: with Wayland. Elsewhere they're drawn
    /// in the window unless `CACAO_POPUP_WINDOWS` is `1`, which opens them
    /// as SDL's popup windows; `0` draws them in the window everywhere.
    ///
    /// SDL's popup windows aren't the default: with X11 (Xwayland) a
    /// popup's button release arrives at the wrong position, so its items
    /// can't be chosen, and on macOS they're untried.
    public static var opensPopupWindows: Bool {
        switch ProcessInfo.processInfo.environment["CACAO_POPUP_WINDOWS"] {
        case "0": return false
        case "1": return true
        default: return SDL.currentVideoDriver == "wayland"
        }
    }
}
