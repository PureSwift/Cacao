//
//  WindowLayer.swift
//  Cacao
//
//  Created by Alsey Coleman Miller on 11/23/26.
//

#if canImport(CoreGraphics)
import CoreGraphics
#endif
import Foundation

/// A layer of the screen that a scene's windows can be placed in, instead
/// of among the other windows: for menu bars, docks, panels and desktops.
///
/// On Wayland compositors with the layer shell, such as sway, the window
/// becomes a layer surface anchored to edges of the screen. Other systems
/// open it as an ordinary window.
public enum WindowLayer: Hashable, Sendable {

    /// Below everything, as for a desktop's wallpaper and icons.
    case background

    /// Below the windows.
    case bottom

    /// Above the windows, as for a menu bar or dock.
    case top

    /// Above everything, full-screen windows included.
    case overlay
}

/// Whether a window in a layer of the screen takes keyboard focus.
public enum WindowLayerKeyboardInteractivity: Hashable, Sendable {

    /// Never, as for a dock that's only clicked.
    case none

    /// Always, while it's on the top or overlay layer, as for a lock screen.
    case exclusive

    /// When clicked, like a window.
    case onDemand
}

/// Where a scene's windows go in a layer of the screen.
package struct WindowLayerPlacement: Hashable, Sendable {

    package var layer: WindowLayer

    /// The edges of the screen the window is anchored to.
    package var edges: Edge.Set

    package var exclusiveZone: CGFloat

    package var margins: EdgeInsets

    package var keyboardInteractivity: WindowLayerKeyboardInteractivity

    package var namespace: String
}

extension Scene {

    /// Places the scene's windows in a layer of the screen, anchored to
    /// some of its edges, instead of among the other windows.
    ///
    /// A window anchored to two opposite edges spans the screen between
    /// them; along its other axis it takes the scene's default size. A bar
    /// along the top of the screen, which windows stay below:
    ///
    /// ```swift
    /// WindowGroup {
    ///     MenuBar()
    /// }
    /// .defaultSize(width: 800, height: 28)
    /// .windowLayer(.top, edges: [.top, .leading, .trailing], exclusiveZone: 28)
    /// ```
    ///
    /// Systems without layers open the windows as ordinary windows.
    ///
    /// - Parameters:
    ///   - layer: The layer the windows go in.
    ///   - edges: The edges of the screen they're anchored to. Leading and
    ///     trailing are the screen's left and right.
    ///   - exclusiveZone: How much of the anchored edge, in points, to keep
    ///     other windows out of: 0 for none, or -1 to also cover what other
    ///     layers keep, as a full-screen panel does.
    ///   - margins: Distances from the anchored edges, in points.
    ///   - keyboardInteractivity: Whether the windows take keyboard focus.
    ///   - namespace: What the windows are, such as `dock`, for the
    ///     compositor's rules.
    public func windowLayer(
        _ layer: WindowLayer,
        edges: Edge.Set,
        exclusiveZone: CGFloat = 0,
        margins: EdgeInsets = EdgeInsets(),
        keyboardInteractivity: WindowLayerKeyboardInteractivity = .onDemand,
        namespace: String = ""
    ) -> some Scene {
        let placement = WindowLayerPlacement(
            layer: layer,
            edges: edges,
            exclusiveZone: exclusiveZone,
            margins: margins,
            keyboardInteractivity: keyboardInteractivity,
            namespace: namespace
        )
        return _SceneModifierContent(content: self) { $0.layer = placement }
    }
}
