//
//  WaylandPopups.swift
//  CacaoHost
//
//  Created by Alsey Coleman Miller on 11/24/26.
//

#if os(Linux)
import Foundation
#if canImport(CoreGraphics)
import CoreGraphics
#endif
import SDL3Swift
internal import CacaoWayland

/// The compositor's xdg shell and seat, for popups as surfaces of their
/// own: bound on SDL's Wayland connection when a popup first opens.
@MainActor
enum WaylandPopups {

    private static var popups: OpaquePointer?

    /// Whether the compositor was asked, so a missing shell is asked once.
    private static var didBind = false

    /// The shell, if SDL uses Wayland and the compositor offers one.
    static var current: OpaquePointer? {
        if !didBind {
            didBind = true
            if SDL.currentVideoDriver == "wayland",
               let display = SDL.globalProperties.pointer("SDL.video.wayland.wl_display") {
                popups = cacao_wayland_popups_create(display)
            }
        }
        return popups
    }

    /// Delivers the configure and done events SDL read from the connection.
    static func dispatch() {
        cacao_wayland_popups_dispatch(popups)
    }

    /// After the windows are closed.
    static func stop() {
        cacao_wayland_popups_destroy(popups)
        popups = nil
        didBind = false
    }

    /// Makes an SDL window whose Wayland surface is a popup of `parent`'s,
    /// placed as the compositor says. Returns nil without an xdg shell, or
    /// when the parent isn't one a popup can belong to.
    static func makeWindow(parent: HostWindow, placement: HostPopupPlacement) -> (window: SDLWindow, popup: WaylandPopup)? {
        guard let shell = current else { return nil }
        var parentSpec = CacaoPopupParent(xdg_surface: nil, layer_surface: nil, popup: nil)
        if let popup = parent.waylandPopup {
            parentSpec.popup = popup.pointer
        } else if let layer = parent.waylandLayerSurface {
            parentSpec.layer_surface = layer.pointer
        } else if let surface = parent.window.properties.pointer("SDL.window.wayland.xdg_surface") {
            parentSpec.xdg_surface = surface
        } else {
            return nil
        }
        let size = placement.surfaceSize
        let window: SDLWindow
        do {
            window = try SDLWindow { properties throws(SDLError) in
                try properties.setNumber("SDL.window.create.width", Int64(max(size.width.rounded(.up), 1)))
                try properties.setNumber("SDL.window.create.height", Int64(max(size.height.rounded(.up), 1)))
                try properties.setBoolean("SDL.window.create.high_pixel_density", true)
                try properties.setBoolean("SDL.window.create.transparent", true)
                // A surface with no role, which this gives the popup role.
                try properties.setBoolean("SDL.window.create.wayland.surface_role_custom", true)
                // Made for the renderer from the start: SDL recreates a
                // window to suit a renderer, which would lose the role.
                if let api = HostWindow.renderingAPI {
                    try properties.setBoolean(api, true)
                }
            }
        } catch {
            print("Cacao: popup window not created: \(error)")
            return nil
        }
        guard let wlSurface = window.properties.pointer("SDL.window.wayland.surface"),
              let popup = WaylandPopup(shell: shell, window: window, wlSurface: wlSurface, parent: parentSpec, placement: placement) else {
            print("Cacao: the compositor didn't place the popup")
            return nil
        }
        return (window, popup)
    }
}

/// A window's surface as a popup. SDL doesn't hear of its size changes, so
/// they're applied to the SDL window here.
@MainActor
final class WaylandPopup {

    private(set) var pointer: OpaquePointer?

    private let window: SDLWindow

    /// The margins around the popup in its surface.
    private var margins: HostInsets

    /// Where the compositor placed the popup, in its parent.
    private(set) var frame: CGRect = .zero

    /// Whether the compositor dismissed the popup.
    private(set) var isDone = false

    /// Called when the compositor dismisses the popup.
    var onDone: (() -> Void)?

    init?(shell: OpaquePointer, window: SDLWindow, wlSurface: UnsafeMutableRawPointer, parent: CacaoPopupParent, placement: HostPopupPlacement) {
        self.window = window
        self.margins = placement.margins
        var parent = parent
        var positioner = Self.positioner(for: placement)
        var geometry = Self.geometry(for: placement)
        let context = Unmanaged.passUnretained(self).toOpaque()
        pointer = cacao_wayland_popup_create(
            shell, wlSurface, &parent, &positioner, &geometry, placement.grabsInput,
            popupConfigureCallback, popupDoneCallback, context
        )
        guard pointer != nil else { return nil }
        // Made shorter than asked, its geometry follows.
        applyGeometry()
    }

    /// Places the popup again, for a new size or anchor. Returns false if
    /// the compositor can't: then it's made again.
    func move(to placement: HostPopupPlacement) -> Bool {
        guard let pointer else { return false }
        margins = placement.margins
        var positioner = Self.positioner(for: placement)
        var geometry = Self.geometry(for: placement)
        appliedGeometry = nil
        return cacao_wayland_popup_reposition(pointer, &positioner, &geometry)
    }

    /// Removes the popup role, before SDL destroys the surface.
    func destroy() {
        cacao_wayland_popup_destroy(pointer)
        pointer = nil
    }

    fileprivate func configure(x: Int32, y: Int32, width: Int32, height: Int32) {
        frame = CGRect(x: CGFloat(x), y: CGFloat(y), width: CGFloat(width), height: CGFloat(height))
        guard width > 0, height > 0 else { return }
        let size = (
            width: Int((CGFloat(width) + margins.left + margins.right).rounded(.up)),
            height: Int((CGFloat(height) + margins.top + margins.bottom).rounded(.up))
        )
        if size != window.size {
            window.size = size
        }
        applyGeometry()
    }

    /// The geometry applied last.
    private var appliedGeometry: CGRect?

    /// Makes the popup's geometry the size the compositor gave it.
    private func applyGeometry() {
        guard pointer != nil, frame.width > 0, frame.height > 0 else { return }
        let rect = CGRect(x: margins.left.rounded(), y: margins.top.rounded(), width: frame.width, height: frame.height)
        guard rect != appliedGeometry else { return }
        appliedGeometry = rect
        var geometry = CacaoPopupGeometry(
            x: Int32(rect.minX), y: Int32(rect.minY),
            width: Int32(rect.width), height: Int32(rect.height)
        )
        cacao_wayland_popup_set_geometry(pointer, &geometry)
    }

    fileprivate func done() {
        guard !isDone else { return }
        isDone = true
        onDone?()
    }

    /// The positioner for a placement: on the edge it asks for, and moved
    /// along it, flipped to the other side or made shorter by the
    /// compositor to keep it on the screen.
    private static func positioner(for placement: HostPopupPlacement) -> CacaoPopupPositioner {
        let anchorPoint: xdg_anchor
        let gravity: xdg_gravity
        let adjustment: UInt32
        let slideX: UInt32 = 1, slideY: UInt32 = 2, flipX: UInt32 = 4, flipY: UInt32 = 8, resizeY: UInt32 = 32
        switch placement.edge {
        case .bottom:
            anchorPoint = .bottomLeft
            gravity = .bottomRight
            adjustment = slideX | flipY | resizeY
        case .top:
            anchorPoint = .topLeft
            gravity = .topRight
            adjustment = slideX | flipY | resizeY
        case .trailing:
            anchorPoint = .topRight
            gravity = .bottomRight
            adjustment = flipX | slideY | resizeY
        case .leading:
            anchorPoint = .topLeft
            gravity = .bottomLeft
            adjustment = flipX | slideY | resizeY
        }
        let anchor = placement.anchor
        return CacaoPopupPositioner(
            anchor_x: Int32(anchor.minX.rounded(.down)),
            anchor_y: Int32(anchor.minY.rounded(.down)),
            anchor_width: Int32(max(anchor.width.rounded(), 1)),
            anchor_height: Int32(max(anchor.height.rounded(), 1)),
            width: Int32(max(placement.size.width.rounded(.up), 1)),
            height: Int32(max(placement.size.height.rounded(.up), 1)),
            anchor: anchorPoint.rawValue,
            gravity: gravity.rawValue,
            constraint_adjustment: adjustment,
            offset_x: Int32(placement.offset.width.rounded()),
            offset_y: Int32(placement.offset.height.rounded())
        )
    }

    private static func geometry(for placement: HostPopupPlacement) -> CacaoPopupGeometry {
        CacaoPopupGeometry(
            x: Int32(placement.margins.left.rounded()),
            y: Int32(placement.margins.top.rounded()),
            width: Int32(max(placement.size.width.rounded(.up), 1)),
            height: Int32(max(placement.size.height.rounded(.up), 1))
        )
    }
}

/// `xdg_positioner`'s anchor and gravity values.
private enum xdg_anchor: UInt32 {
    case topLeft = 5
    case bottomLeft = 6
    case topRight = 7
}

private enum xdg_gravity: UInt32 {
    case topRight = 7
    case bottomLeft = 6
    case bottomRight = 8
}

/// Called on the main thread, as the host dispatches the queue (or creates
/// the popup).
private let popupConfigureCallback: CacaoPopupConfigureCallback = { context, x, y, width, height in
    guard let context else { return }
    let address = UInt(bitPattern: context)
    MainActor.assumeIsolated {
        let popup = Unmanaged<WaylandPopup>.fromOpaque(UnsafeRawPointer(bitPattern: address)!).takeUnretainedValue()
        popup.configure(x: x, y: y, width: width, height: height)
    }
}

private let popupDoneCallback: CacaoPopupDoneCallback = { context in
    guard let context else { return }
    let address = UInt(bitPattern: context)
    MainActor.assumeIsolated {
        Unmanaged<WaylandPopup>.fromOpaque(UnsafeRawPointer(bitPattern: address)!).takeUnretainedValue().done()
    }
}
#endif
