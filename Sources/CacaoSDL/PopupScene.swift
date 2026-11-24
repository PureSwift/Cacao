//
//  PopupScene.swift
//  CacaoSDL
//
//  Created by Alsey Coleman Miller on 11/24/26.
//

import CacaoRender
import Foundation
#if canImport(CoreGraphics)
import CoreGraphics
#endif
import Cacao
import CacaoHost

/// A popup in a surface of its own: it draws the popup's views, which stay
/// in the window's view graph, and sends its input to that graph where the
/// popup's views are.
@MainActor
final class PopupScene: HostScene {

    /// The popup's presentation.
    let id: Int

    private weak var owner: WindowScene?

    /// Space around the popup, for its shadow.
    let margins: HostInsets

    /// The owner's drawing this scene last drew.
    private var drawnGeneration = -1

    private var drawnSize: CGSize?

    init(id: Int, owner: WindowScene, margins: HostInsets) {
        self.id = id
        self.owner = owner
        self.margins = margins
    }

    // MARK: Events

    func handle(_ event: HostEvent, time: Double) {
        guard let owner else { return }
        switch event {
        case .geometryChanged:
            // Drawn again at its new size.
            drawnSize = nil
        case .windowStateChanged, .appearanceChanged:
            // The window has its own.
            break
        case let .pointer(phase, button, location, isFromTouch):
            owner.handle(.pointer(phase, button: button, at: graphPoint(location), isFromTouch: isFromTouch), time: time)
        case let .hover(location):
            owner.handle(.hover(at: location.map(graphPoint)), time: time)
        case let .magnify(phase, scale, location):
            owner.handle(.magnify(phase, scale: scale, at: graphPoint(location)), time: time)
        case let .rotate(phase, angle, location):
            owner.handle(.rotate(phase, angle: angle, at: graphPoint(location)), time: time)
        case let .touch(phase, finger, location):
            owner.handle(.touch(phase, finger: finger, at: graphPoint(location)), time: time)
        case let .scroll(x, y, location):
            owner.handle(.scroll(x: x, y: y, at: graphPoint(location)), time: time)
        case let .drop(phase, items, location):
            owner.handle(.drop(phase, items: items, at: graphPoint(location)), time: time)
        case .key, .text:
            owner.handle(event, time: time)
        }
    }

    /// Where a point in the surface is in the graph.
    private func graphPoint(_ point: CGPoint) -> CGPoint {
        owner?.graph.point(CGPoint(x: point.x - margins.left, y: point.y - margins.top), inPopup: id) ?? point
    }

    // MARK: Frames

    var isAnimating: Bool {
        false
    }

    func update(_ frame: HostFrame) -> Bool {
        guard let owner else { return false }
        return owner.displayGeneration != drawnGeneration || frame.size != drawnSize
    }

    func displayList() -> DisplayList {
        guard let owner, let window = owner.popupWindow(for: id) else { return DisplayList(items: []) }
        drawnGeneration = owner.displayGeneration
        drawnSize = window.size
        return owner.graph.popupDisplayList(id, at: CGPoint(x: margins.left, y: margins.top))
    }

    var windowState: HostWindowState {
        HostWindowState(
            cursor: owner?.windowState.cursor ?? .default,
            backgroundColor: ResolvedColor(red: 0, green: 0, blue: 0, opacity: 0)
        )
    }
}

extension WindowScene {

    /// The space around a popup in its surface, for its shadow.
    static let popupMargins = HostInsets(top: 12, left: 16, bottom: 22, right: 16)

    /// Opens a surface for each popup the graph shows outside the window,
    /// closes those it no longer shows, and moves the rest to where they
    /// are now. A popup the host can't open a surface for is drawn in the
    /// window instead.
    func syncPopups() {
        guard let window else { return }
        let wanted = graph.detachedPopups
        let wantedIDs = Set(wanted.map(\.id))
        // Last first: a popup's own popups close with it.
        for id in popupWindows.keys.sorted(by: >) where !wantedIDs.contains(id) {
            if let popup = popupWindows.removeValue(forKey: id) {
                HostRuntime.close(popup)
            }
        }
        for popup in wanted {
            let placement = HostPopupPlacement(
                anchor: popup.anchor,
                edge: popup.edge == .trailing ? .trailing : .bottom,
                offset: popup.offset,
                size: popup.size,
                margins: Self.popupMargins
            )
            if let open = popupWindows[popup.id] {
                open.movePopup(to: placement)
                // The system made it shorter to fit the screen: its views
                // fit that.
                if let frame = open.popupFrame, frame.height > 0, frame.height < popup.size.height - 0.5 {
                    graph.setPopupHeight(frame.height, for: popup.id)
                }
                continue
            }
            let parent = popup.parentID.flatMap { popupWindows[$0] } ?? window
            let id = popup.id
            if let opened = HostRuntime.openPopup(of: parent, placement: placement, makeScene: { _ in
                PopupScene(id: id, owner: self, margins: Self.popupMargins)
            }) {
                opened.onPopupDismissed = { [weak self] in
                    self?.graph.dismissPresentation(id)
                }
                popupWindows[id] = opened
            } else {
                graph.attachPopup(id)
            }
        }
    }

    /// The surface showing a popup.
    func popupWindow(for id: Int) -> HostWindow? {
        popupWindows[id]
    }

    /// Closes the window's popups, as the window closes.
    func closePopups() {
        for id in popupWindows.keys.sorted(by: >) {
            if let popup = popupWindows.removeValue(forKey: id) {
                HostRuntime.close(popup)
            }
        }
    }
}
