//
//  HostMenuAddress.swift
//  CacaoHost
//
//  Created by Alsey Coleman Miller on 11/24/26.
//

/// Where an app's menu is on the session bus: the D-Bus service and object
/// path of its `com.canonical.dbusmenu` object.
public struct HostMenuAddress: Hashable, Sendable {

    /// The bus name of the connection serving the menu, such as `:1.42`.
    public var service: String

    /// The menu's object path, such as `/MenuBar`.
    public var path: String

    public init(service: String, path: String) {
        self.service = service
        self.path = path
    }
}

extension HostRuntime {

    private static var currentMenuAddress: HostMenuAddress?

    /// Where the app's menu is on the session bus. Each window is tied to
    /// it with the compositor's appmenu protocol, where the compositor has
    /// it, so the menu bar shows the menu while the window has focus. `nil`
    /// unties them.
    public static var menuAddress: HostMenuAddress? {
        get { currentMenuAddress }
        set {
            guard newValue != currentMenuAddress else { return }
            currentMenuAddress = newValue
            for window in windows {
                window.applyMenuAddress()
            }
        }
    }

    /// Whether the compositor ties windows to their menus, which means a
    /// menu bar shows them and windows needn't: true where it offers the
    /// appmenu protocol. Asked once SDL's video is started.
    public static var compositorShowsMenus: Bool {
        #if os(Linux)
        WaylandAppMenu.current != nil
        #else
        false
        #endif
    }
}
