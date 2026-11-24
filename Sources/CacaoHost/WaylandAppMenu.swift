//
//  WaylandAppMenu.swift
//  CacaoHost
//
//  Created by Alsey Coleman Miller on 11/24/26.
//

#if os(Linux)
import SDL3Swift
internal import CacaoWayland

/// The compositor's appmenu manager, which ties each window to the app's
/// menu on D-Bus: bound on SDL's Wayland connection when first asked.
///
/// The link between windows and menus is all here (and in CacaoWayland's
/// `appmenu.c`), so moving to another protocol, such as an XDG one that
/// replaces KDE's, changes nothing else.
@MainActor
enum WaylandAppMenu {

    private static var manager: OpaquePointer?

    /// Whether the compositor was asked, so a missing manager is asked once.
    private static var didBind = false

    /// The manager, if SDL uses Wayland and the compositor offers one.
    static var current: OpaquePointer? {
        if !didBind {
            didBind = true
            if SDL.currentVideoDriver == "wayland",
               let display = SDL.globalProperties.pointer("SDL.video.wayland.wl_display") {
                manager = cacao_wayland_appmenu_manager_create(display)
            }
        }
        return manager
    }

    /// After the windows are closed.
    static func stop() {
        cacao_wayland_appmenu_manager_destroy(manager)
        manager = nil
        didBind = false
    }
}

/// A window's tie to the app's menu.
@MainActor
final class WaylandWindowMenu {

    private var menu: OpaquePointer?

    /// The address last given.
    private var address: HostMenuAddress

    /// Ties a window's surface to the menu at an address. Returns nil
    /// without an appmenu manager.
    init?(surface: UnsafeMutableRawPointer, address: HostMenuAddress) {
        guard let manager = WaylandAppMenu.current,
              let menu = cacao_wayland_appmenu_create(manager, surface, address.service, address.path) else {
            return nil
        }
        self.menu = menu
        self.address = address
    }

    /// Moves the window's menu to another address.
    func setAddress(_ address: HostMenuAddress) {
        guard address != self.address else { return }
        self.address = address
        cacao_wayland_appmenu_set_address(menu, address.service, address.path)
    }

    /// Unties the window, before SDL destroys its surface.
    func destroy() {
        cacao_wayland_appmenu_destroy(menu)
        menu = nil
    }
}
#endif
