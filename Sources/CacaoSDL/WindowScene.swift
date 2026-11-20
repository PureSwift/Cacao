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

    /// Whether the next frame must lay out again.
    private var needsLayout = true

    init(description: WindowDescription, value: AnyHashable? = nil, window: HostWindow, textEngine: any TextEngine) {
        self.window = window
        self.sceneID = description.id
        var environment = EnvironmentValues()
        environment.openURL = OpenURLAction { url in
            HostRuntime.open(url)
        }
        environment.displayScale = window.scale
        environment.colorScheme = HostRuntime.systemAppearance == .dark ? .dark : .light
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
        let rootView = description.makeRootView?(value) ?? description.rootView
        self.graph = ViewGraph(rootView: rootView, environment: environment, textEngine: textEngine)
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
            backgroundColor: graph.environment.colorScheme == .dark
                ? Color.Resolved(red: 0, green: 0, blue: 0)
                : Color.Resolved(red: 1, green: 1, blue: 1)
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
            // External content takes the presses that start on it.
            if graph.externalPointer(Self.externalPhase(phase), button: Self.button(button), at: location, isFromTouch: isFromTouch) {
                break
            }
            switch (button, phase) {
            case (.primary, _):
                graph.pointer(Self.phase(phase), at: location, time: now)
            case (.secondary, .began):
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
            let update: TouchRotationTracker.Update? = switch phase {
            case .began: touchRotation.fingerDown(finger, at: location)
            case .moved: touchRotation.fingerMoved(finger, to: location)
            case .ended: touchRotation.fingerUp(finger, cancelled: false)
            case .cancelled: touchRotation.fingerUp(finger, cancelled: true)
            }
            if let update {
                graph.rotate(update.phase, angle: update.angle, at: update.location, time: now)
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

    // MARK: Frames

    /// Steps animations, updates and lays out. Returns whether anything
    /// changed to draw.
    func update(_ frame: HostFrame) -> Bool {
        var changed = false
        scrollController.step(now: frame.time)
        // Moves animations to this frame; animatable views re-resolve.
        graph.advanceAnimations(to: frame.time)
        if graph.needsUpdate {
            graph.update()
            needsLayout = true
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
        if graph.needsDisplay {
            changed = true
        }
        return changed
    }

    func displayList() -> DisplayList {
        graph.displayList()
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
