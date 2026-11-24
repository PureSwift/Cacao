//
//  WindowScene.swift
//  CacaoSDL
//
//  Created by Alsey Coleman Miller on 11/13/26.
//

import CacaoRender
import Foundation
#if canImport(CoreGraphics)
import CoreGraphics
#endif
import Cacao
import CacaoHost
import CacaoTokens
#if os(macOS)
import AppKit
#endif

/// A window's SwiftUI content: the view graph the host's window shows and
/// sends input to.
@MainActor
final class WindowScene: HostScene {

    let graph: ViewGraph

    /// The window showing the scene.
    private(set) weak var window: HostWindow?

    /// The scene the window shows, if it has an identifier.
    let sceneID: String?

    private let scrollController = ScrollController()

    /// The color scheme the views last preferred.
    private var lastPreferredColorScheme: ColorScheme?

    /// Two-finger rotations on touch screens.
    private var touchRotation = TouchRotationTracker()

    /// Two-finger pinches on touch screens, where the system reports the
    /// fingers but not the pinch.
    private var touchPinch = TouchPinchTracker()

    /// Whether the system reports a touch screen's pinches itself, as iOS
    /// and Android do through SDL: elsewhere they're told from the fingers.
    private static var systemReportsTouchPinches: Bool {
        #if os(iOS) || os(tvOS) || os(visionOS) || os(Android)
        true
        #else
        false
        #endif
    }

    /// Whether the next frame must lay out again.
    private var needsLayout = true

    /// The height left for content at the last frame: the window's, less
    /// what the system covers, an on-screen keyboard included.
    private var lastContentHeight: CGFloat?

    /// A finger on a touch screen that isn't on external content: it
    /// presses views, like the pointer the host also reports it as, until
    /// it moves far enough over a scroll view to scroll it instead.
    private struct TouchPan {
        var finger: UInt64
        var start: CGPoint
        var last: CGPoint
        var isScrolling = false
    }

    private var touchPan: TouchPan?

    /// The fingers on a touch screen that aren't on external content.
    private var fingersDown: Set<UInt64> = []

    /// How far a finger moves before it scrolls rather than presses.
    private static let panDistance: CGFloat = 10

    /// Who draws the window's title bar.
    let chrome: WindowChrome

    /// The surfaces of the popups shown outside the window, by presentation.
    var popupWindows: [Int: HostWindow] = [:]

    /// Counts the window's drawings, for its popups to draw when it does.
    private(set) var displayGeneration = 0

    /// The window's title, as the scene describes it.
    private let sceneTitle: String

    init(description: WindowDescription, value: AnyHashable? = nil, window: HostWindow, textEngine: any TextEngine) {
        self.window = window
        self.sceneID = description.id
        var environment = EnvironmentValues()
        environment.openURL = OpenURLAction { url in
            HostRuntime.open(url)
        }
        environment.displayScale = window.scale
        environment.colorScheme = HostRuntime.systemAppearance == .dark ? .dark : .light
        environment.systemAccentColor = HostRuntime.systemAccentColor
        environment.colorSchemeContrast = HostRuntime.prefersIncreasedContrast ? .increased : .standard
        // The desktop's look, unless the app chose the stock one.
        environment.interfaceLook = InterfaceLook.appDefault
        environment.openWindow = OpenWindowAction { id, value in
            SDLHost.windowRequests.append(.open(id: id, value: value))
        }
        environment.dismissWindow = DismissWindowAction { [weak window] id in
            if let id {
                SDLHost.windowRequests.append(.closeScene(id))
            } else if let window {
                SDLHost.windowRequests.append(.close(window))
            }
        }
        // A window without the system's decorations draws the desktop's
        // title bar, or its window buttons, unless it's plain.
        let chrome = window.decorations == .none ? description.windowStyle.chrome(for: environment.interfaceLook) : .system
        self.chrome = chrome
        self.sceneTitle = description.title
        if chrome.drawsOwnDecorations {
            environment.windowControls = WindowControls(
                title: description.title,
                buttonLayout: Self.buttonLayout,
                isMaximized: window.isMaximized,
                close: { [weak window] in
                    if let window {
                        SDLHost.windowRequests.append(.close(window))
                    }
                },
                minimize: { [weak window] in window?.minimize() },
                toggleMaximized: { [weak window] in window?.toggleMaximized() }
            )
        }
        var rootView = description.makeRootView?(value) ?? description.rootView
        if chrome == .titleBar || chrome == .buttonsOnly {
            rootView = AnyView(_WindowChrome(content: rootView, chrome: chrome))
        }
        self.graph = ViewGraph(rootView: rootView, environment: environment, textEngine: textEngine)
        // Menus and popovers open outside the window, where the host can.
        graph.opensPopupSurfaces = HostRuntime.opensPopupWindows
        graph.onNeedsDisplay = { [weak window] in
            window?.setNeedsDisplay()
        }
        graph.clipboard = Clipboard(
            read: { HostRuntime.clipboardText },
            write: { HostRuntime.clipboardText = $0 }
        )
        graph.fileDialogs = FileDialogs(
            open: { [weak window] types, allowsMultiple, completion in
                window?.showOpenDialog(filters: Self.filters(for: types), allowsMultiple: allowsMultiple, completion: completion)
            },
            save: { [weak window] defaultName, types, completion in
                window?.showSaveDialog(defaultName: defaultName, filters: Self.filters(for: types), completion: completion)
            }
        )
        #if os(macOS)
        graph.share = { [weak self] request in
            self?.showSharePicker(request) ?? false
        }
        #endif
    }

    /// One dialog filter per type with a known file name extension.
    private static func filters(for types: [UTType]) -> [HostFileFilter] {
        types.compactMap { type in
            filenameExtension(of: type).map { HostFileFilter(name: type.description, extensions: [$0]) }
        }
    }

    var isAnimating: Bool {
        scrollController.isAnimating || graph.hasActiveAnimations
    }

    var windowState: HostWindowState {
        HostWindowState(
            title: graph.windowTitle,
            cursor: Self.cursor(for: graph.pointerStyle?.kind ?? .default),
            acceptsTextInput: graph.acceptsTextInput,
            textInputArea: graph.focusedFrame,
            backgroundColor: graph.environment.windowBackgroundColor
        )
    }

    var statistics: String {
        "resolves \(graph.statistics.resolves)"
    }

    private static func cursor(for kind: PointerStyle.Kind) -> HostCursor {
        switch kind {
        case .default, .zoomIn, .zoomOut: .default
        case .text: .text
        case .link, .grab: .pointer
        case .grabbing, .move: .move
        case .crosshair: .crosshair
        case .columnResize: .horizontalResize
        case .rowResize: .verticalResize
        case .diagonalResize: .diagonalResize
        case .antidiagonalResize: .antidiagonalResize
        }
    }

    // MARK: Events

    func handle(_ event: HostEvent, time now: Double) {
        switch event {
        case .geometryChanged:
            if let scale = window?.scale, graph.environment.displayScale != scale {
                graph.environment.displayScale = scale
            }
            needsLayout = true
        case let .pointer(phase, button, location, isFromTouch):
            // A finger that's scrolling no longer presses anything.
            if isFromTouch, touchPan?.isScrolling == true {
                break
            }
            // External content takes the presses that start on it.
            if graph.externalPointer(Self.externalPhase(phase), button: Self.button(button), at: location, isFromTouch: isFromTouch) {
                break
            }
            switch (button, phase) {
            case (.primary, _):
                graph.pointer(Self.phase(phase), at: location, time: now)
            case (.secondary, .began):
                // On a title bar the app draws, the system's window menu.
                if chrome.drawsOwnDecorations, graph.movesWindow(at: location), window?.showSystemMenu(at: location) == true {
                    break
                }
                graph.secondaryClick(at: location)
            default:
                break
            }
        case let .hover(location):
            graph.hover(at: location)
            graph.externalHover(at: location)
        case let .magnify(phase, scale, location):
            graph.magnify(Self.phase(phase), scale: scale, at: location, time: now)
        case let .rotate(phase, angle, location):
            graph.rotate(Self.phase(phase), angle: angle, at: location, time: now)
        case let .touch(phase, finger, location):
            if graph.externalTouch(Self.externalPhase(phase), finger: finger, at: location) {
                break
            }
            switch phase {
            case .began:
                fingersDown.insert(finger)
                // A second finger makes it a pinch or a rotation, between
                // the two: the first no longer presses or scrolls.
                if fingersDown.count == 2 {
                    graph.pointer(.cancelled, at: location, time: now)
                    if touchPan?.isScrolling == true {
                        scrollController.endPan(now: now)
                    }
                    touchPan = nil
                }
            case .moved:
                break
            case .ended, .cancelled:
                fingersDown.remove(finger)
            }
            pan(phase, finger: finger, at: location, now: now)
            let update: TouchRotationTracker.Update? = switch phase {
            case .began: touchRotation.fingerDown(finger, at: location)
            case .moved: touchRotation.fingerMoved(finger, to: location)
            case .ended: touchRotation.fingerUp(finger, cancelled: false)
            case .cancelled: touchRotation.fingerUp(finger, cancelled: true)
            }
            if let update {
                graph.rotate(update.phase, angle: update.angle, at: update.location, time: now)
            }
            if !Self.systemReportsTouchPinches {
                let pinch: TouchPinchTracker.Update? = switch phase {
                case .began: touchPinch.fingerDown(finger, at: location)
                case .moved: touchPinch.fingerMoved(finger, to: location)
                case .ended: touchPinch.fingerUp(finger, cancelled: false)
                case .cancelled: touchPinch.fingerUp(finger, cancelled: true)
                }
                if let pinch {
                    graph.magnify(pinch.phase, scale: pinch.scale, at: pinch.location, time: now)
                }
            }
        case let .scroll(x, y, location):
            if graph.externalScroll(x: Double(x), y: Double(y), at: location) {
                break
            }
            scrollController.wheel(x: x, y: y, at: location, graph: graph, now: now)
        case let .key(event):
            let modifiers = KeyModifiers(rawValue: event.modifiers.rawValue)
            // Commands' shortcuts work whatever has focus.
            let isShortcut = event.isDown && modifiers.contains(.shortcut) && event.key != nil
            if !isShortcut, graph.externalKey(ExternalInput.Key(
                isDown: event.isDown,
                isRepeat: event.isRepeat,
                usage: event.usage,
                keyCode: event.keyCode,
                modifiers: EventModifiers(modifiers)
            )) {
                break
            }
            if event.isDown, let key = event.key {
                graph.keyDown(Self.key(key), modifiers: modifiers)
            }
        case let .text(text):
            graph.insertText(text)
        case let .drop(phase, items, location):
            graph.systemDrop(phase == .dropped ? .dropped : .moved, items: items, at: location)
        case let .appearanceChanged(appearance):
            applyColorScheme(system: appearance)
            applySystemAccentAndContrast()
            let layout = Self.buttonLayout
            updateWindowControls { $0.buttonLayout = layout }
        case .windowStateChanged:
            applyWindowState()
        }
    }

    /// The window buttons the desktop asks for: Cacao's when it doesn't say.
    private static var buttonLayout: WindowButtonLayout {
        HostRuntime.windowButtonLayout.map(WindowButtonLayout.init(setting:)) ?? .standard
    }

    /// Shows whether the window is the key window, and maximized, to the
    /// views drawing its title bar and selections.
    private func applyWindowState() {
        guard let window else { return }
        let isActive = window.isKey
        if graph.environment.appearsActive != isActive {
            graph.environment.appearsActive = isActive
        }
        updateWindowControls { $0.isMaximized = window.isMaximized }
    }

    /// Changes what the window's title bar shows, if the scene draws one.
    private func updateWindowControls(_ change: (inout WindowControls) -> Void) {
        guard var controls = graph.environment.windowControls else { return }
        let old = (controls.title, controls.buttonLayout, controls.isMaximized)
        change(&controls)
        if old != (controls.title, controls.buttonLayout, controls.isMaximized) {
            graph.environment.windowControls = controls
        }
    }

    /// Presses on views with a `WindowDragGesture` move the window.
    func hitTest(at point: CGPoint) -> HostHitTestResult {
        graph.movesWindow(at: point) ? .draggable : .normal
    }

    /// Scrolls with a finger: the first one down, once it has moved far
    /// enough over a scroll view that can move that way.
    private func pan(_ phase: HostPhase, finger: UInt64, at location: CGPoint, now: Double) {
        switch phase {
        case .began:
            if touchPan == nil, fingersDown.count == 1 {
                touchPan = TouchPan(finger: finger, start: location, last: location)
                scrollController.catchMotion()
            }
        case .moved:
            guard var pan = touchPan, pan.finger == finger else { return }
            if !pan.isScrolling {
                let movement = CGSize(width: location.x - pan.start.x, height: location.y - pan.start.y)
                // A scroll view scrolls when the finger mostly goes a way it
                // can move: not when a drag across it wanders that way.
                guard let direction = ScrollController.panDirection(of: movement, beyond: Self.panDistance),
                      scrollController.beginPan(toward: direction, at: pan.start, graph: graph, now: now) else {
                    return
                }
                pan.isScrolling = true
                pan.last = location
                touchPan = pan
                // The press the finger began is over.
                graph.pointer(.cancelled, at: location, time: now)
                return
            }
            scrollController.pan(
                by: CGSize(width: location.x - pan.last.x, height: location.y - pan.last.y),
                at: pan.start, graph: graph, now: now
            )
            pan.last = location
            touchPan = pan
        case .ended, .cancelled:
            guard let pan = touchPan, pan.finger == finger else { return }
            touchPan = nil
            if pan.isScrolling {
                scrollController.endPan(now: now)
            }
        }
    }

    private static func phase(_ phase: HostPhase) -> PointerPhase {
        switch phase {
        case .began: .began
        case .moved: .moved
        case .ended: .ended
        case .cancelled: .cancelled
        }
    }

    private static func externalPhase(_ phase: HostPhase) -> ExternalInput.Phase {
        switch phase {
        case .began: .began
        case .moved: .moved
        case .ended: .ended
        case .cancelled: .cancelled
        }
    }

    private static func button(_ button: HostPointerButton) -> ExternalInput.Button {
        switch button {
        case .primary: .primary
        case .secondary: .secondary
        case .middle: .middle
        }
    }

    private static func key(_ key: HostKey) -> KeyCode {
        switch key {
        case .left: .left
        case .right: .right
        case .up: .up
        case .down: .down
        case .home: .home
        case .end: .end
        case .pageUp: .pageUp
        case .pageDown: .pageDown
        case .backspace: .backspace
        case .delete: .delete
        case .returnKey: .returnKey
        case .escape: .escape
        case .tab: .tab
        case let .character(character): .character(character)
        }
    }

    /// Shows the system's color scheme, unless views prefer one over it.
    private func applyColorScheme(system: HostAppearance) {
        let colorScheme = graph.preferredColorScheme ?? (system == .dark ? .dark : .light)
        if graph.environment.colorScheme != colorScheme {
            graph.environment.colorScheme = colorScheme
        }
    }

    /// Shows the system's accent color and contrast.
    private func applySystemAccentAndContrast() {
        let accent = HostRuntime.systemAccentColor
        if graph.environment.systemAccentColor != accent {
            graph.environment.systemAccentColor = accent
        }
        let contrast: ColorSchemeContrast = HostRuntime.prefersIncreasedContrast ? .increased : .standard
        if graph.environment.colorSchemeContrast != contrast {
            graph.environment.colorSchemeContrast = contrast
        }
    }

    // MARK: Frames

    /// Steps animations, updates and lays out. Returns whether anything
    /// changed to draw.
    func update(_ frame: HostFrame) -> Bool {
        var changed = false
        scrollController.step(now: frame.time)
        // Moves animations to this frame; animatable views re-resolve.
        graph.advanceAnimations(to: frame.time)
        // A narrow window is compact, as an iPhone or a slim iPad window is.
        graph.applySizeClasses(for: frame.size)
        if graph.needsUpdate {
            graph.update()
            needsLayout = true
            // A document's name is the title its title bar shows.
            let title = graph.windowTitle ?? sceneTitle
            updateWindowControls { $0.title = title }
            if graph.preferredColorScheme != lastPreferredColorScheme {
                lastPreferredColorScheme = graph.preferredColorScheme
                applyColorScheme(system: HostRuntime.systemAppearance)
            }
        }
        // Keeps content out of the parts of the window the system covers.
        let insets = EdgeInsets(
            top: frame.safeArea.top,
            leading: frame.safeArea.left,
            bottom: frame.safeArea.bottom,
            trailing: frame.safeArea.right
        )
        if insets != graph.safeAreaInsets {
            graph.safeAreaInsets = insets
            needsLayout = true
        }
        // An on-screen keyboard takes the bottom of the window, or makes
        // the window shorter: the focused text view scrolls back into view.
        let contentHeight = frame.size.height - insets.top - insets.bottom
        let revealsFocus = lastContentHeight.map { graph.looksLikeKeyboardAppearing(from: $0, to: contentHeight) } ?? false
        lastContentHeight = contentHeight
        if needsLayout || graph.size != frame.size {
            graph.layout(in: frame.size)
            needsLayout = false
            changed = true
        }
        // Layout can invalidate views, as when lazy stacks need rows that
        // came into view: settle them before drawing.
        var passes = 0
        while graph.needsUpdate, passes < 4 {
            graph.layout(in: frame.size)
            passes += 1
        }
        if revealsFocus {
            graph.revealFocusedView()
        }
        if graph.opensPopupSurfaces {
            // About as tall as the screen; the system makes one shorter if
            // it must.
            if let screen = window?.screenSize {
                graph.popupMaximumHeight = max(screen.height - 40, 100)
            }
            syncPopups()
        }
        if graph.needsDisplay {
            changed = true
        }
        return changed
    }

    func displayList() -> DisplayList {
        displayGeneration += 1
        return graph.displayList()
    }

    func detach() {
        closePopups()
    }

    func didRender(time: Double) {
        #if os(macOS)
        updateAccessibility(now: time)
        #endif
    }

    #if os(macOS)

    // MARK: Sharing

    /// The share picker shown, kept while it's open.
    private var sharePicker: NSSharingServicePicker?

    /// Shows the system's share picker below a share link.
    private func showSharePicker(_ request: ShareRequest) -> Bool {
        guard let view = window?.contentView, !request.items.isEmpty else { return false }
        let anchor = request.anchor
        let rect = view.isFlipped
            ? anchor
            : CGRect(x: anchor.minX, y: view.bounds.height - anchor.maxY, width: anchor.width, height: anchor.height)
        let picker = NSSharingServicePicker(items: request.items)
        sharePicker = picker
        picker.show(relativeTo: rect, of: view, preferredEdge: .minY)
        return true
    }

    // MARK: Accessibility

    /// The window's elements for VoiceOver, made when first needed.
    private var accessibility: AccessibilityBridge?

    private var lastAccessibilityUpdate: Double = -1

    /// Shows the accessibility tree to macOS, at most four times a second.
    private func updateAccessibility(now: Double) {
        guard now - lastAccessibilityUpdate >= 0.25 else { return }
        lastAccessibilityUpdate = now
        if accessibility == nil {
            guard let view = window?.contentView else { return }
            let graph = self.graph
            accessibility = AccessibilityBridge(view: view) { [weak self] name, frame in
                let performed = graph.performAccessibilityAction(name, at: frame)
                self?.window?.setNeedsDisplay()
                return performed
            }
        }
        accessibility?.update(graph.accessibilityTree())
    }
    #endif
}
