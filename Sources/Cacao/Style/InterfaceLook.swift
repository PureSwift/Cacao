//
//  InterfaceLook.swift
//  Cacao
//
//  Created by Alsey Coleman Miller on 11/24/26.
//

/// Which look Cacao's built-in styles draw: the desktop's own, or the
/// stock look.
///
/// The look changes how the built-in styles draw, not which style a view
/// asks for: under the desktop's look, `.bordered` buttons are the
/// desktop's push buttons, `.segmented` pickers its segmented controls,
/// `.sidebar` lists its source lists, and so on. A style an app writes
/// itself draws the same under either look.
///
/// Every app's windows get the desktop's look unless the app chooses.
/// Any part of an app can ask for the stock look instead:
///
/// ```swift
/// SettingsForm()
///     .interfaceLook(.stock)
/// ```
public struct InterfaceLook: Hashable, Sendable {

    package enum Value: Hashable, Sendable {
        case stock
        case desktop
    }

    package let value: Value

    private init(_ value: Value) {
        self.value = value
    }

    /// The desktop's look, from the style tokens in `CacaoTokens`: shaded
    /// push buttons with the default one in the accent, pill-shaped search
    /// fields, an accent-tinted sidebar, opaque menus, and toolbars that
    /// continue the title bar. Light or dark and tinted with the accent,
    /// following the desktop's appearance as it changes.
    public static let desktop = InterfaceLook(.desktop)

    /// The stock look: Cacao's built-in styles as they draw without the
    /// desktop's, close to SwiftUI's own.
    public static let stock = InterfaceLook(.stock)

    /// The look an app's windows get unless a view asks for another.
    ///
    /// The desktop's, so every Cacao app matches the desktop. For only
    /// the desktop's own apps to look like it, make this `.stock`, and have
    /// those apps set it back to `.desktop` in their `init()`. Views drawn
    /// outside an app's windows, as in tests, have the stock look.
    @MainActor
    public static var appDefault: InterfaceLook = .desktop
}

private struct InterfaceLookKey: EnvironmentKey {
    static let defaultValue = InterfaceLook.stock
}

extension EnvironmentValues {

    /// The look of Cacao's built-in styles in this environment.
    public var interfaceLook: InterfaceLook {
        get { self[InterfaceLookKey.self] }
        set { self[InterfaceLookKey.self] = newValue }
    }

    /// Whether built-in styles draw the desktop's look here.
    internal var usesDesktopLook: Bool {
        interfaceLook.value == .desktop
    }
}

extension View {

    /// Sets the look of Cacao's built-in styles within this view: the
    /// desktop's, or the stock look.
    public func interfaceLook(_ look: InterfaceLook) -> some View {
        environment(\.interfaceLook, look)
    }
}
