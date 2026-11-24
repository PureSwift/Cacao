//
//  WindowControls.swift
//  Cacao
//
//  Created by Alsey Coleman Miller on 11/24/26.
//

package import CacaoTokens

/// What the title bar of a window that draws its own shows and does: set
/// by the host for each such window.
package struct WindowControls {

    /// The window's title.
    package var title: String

    /// The window buttons the desktop asks for, and at which end.
    package var buttonLayout: WindowButtonLayout

    /// Whether the window fills the screen's work area.
    package var isMaximized: Bool

    /// Closes the window.
    package var close: @MainActor () -> Void

    /// Hides the window in the dock.
    package var minimize: @MainActor () -> Void

    /// Maximizes the window, or puts a maximized one back.
    package var toggleMaximized: @MainActor () -> Void

    package init(
        title: String,
        buttonLayout: WindowButtonLayout = .standard,
        isMaximized: Bool = false,
        close: @escaping @MainActor () -> Void,
        minimize: @escaping @MainActor () -> Void,
        toggleMaximized: @escaping @MainActor () -> Void
    ) {
        self.title = title
        self.buttonLayout = buttonLayout
        self.isMaximized = isMaximized
        self.close = close
        self.minimize = minimize
        self.toggleMaximized = toggleMaximized
    }
}

private struct WindowControlsKey: EnvironmentKey {
    static var defaultValue: WindowControls? { nil }
}

private struct AppearsActiveKey: EnvironmentKey {
    static let defaultValue = true
}

extension EnvironmentValues {

    /// The controls of the window, if it draws its own title bar.
    package var windowControls: WindowControls? {
        get { self[WindowControlsKey.self] }
        set { self[WindowControlsKey.self] = newValue }
    }

    /// Whether the window the views are in is the key window, the one
    /// typing goes to: other windows draw their title bars and selections
    /// quieter.
    public var appearsActive: Bool {
        get { self[AppearsActiveKey.self] }
        set { self[AppearsActiveKey.self] = newValue }
    }
}
