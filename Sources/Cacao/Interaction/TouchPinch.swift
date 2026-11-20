//
//  TouchPinch.swift
//  Cacao
//
//  Created by Alsey Coleman Miller on 11/20/26.
//

import CacaoRender
import Foundation
#if canImport(CoreGraphics)
import CoreGraphics
#endif

/// Follows the fingers on a touch screen and reports how far apart the
/// first two are, for hosts whose platform reports touches but not pinches.
///
/// The scale is the distance between the fingers over what it was when the
/// second came down, as `MagnifyGesture` reports it.
package struct TouchPinchTracker {

    /// A change to the pinch, for `ViewGraph.magnify`.
    package struct Update: Equatable {
        package var phase: PointerPhase
        package var scale: Double
        /// Between the two fingers.
        package var location: CGPoint
    }

    private var fingers: [(id: UInt64, location: CGPoint)] = []

    /// How far apart the fingers were when the second came down.
    private var startDistance: Double?

    private var scale = 1.0

    package init() { }

    package mutating func fingerDown(_ id: UInt64, at location: CGPoint) -> Update? {
        guard !fingers.contains(where: { $0.id == id }) else { return nil }
        fingers.append((id, location))
        guard fingers.count == 2 else { return nil }
        // Fingers on the same spot have no distance to scale from.
        let distance = self.distance
        guard distance > 0 else { return nil }
        startDistance = distance
        scale = 1
        return Update(phase: .began, scale: 1, location: center)
    }

    package mutating func fingerMoved(_ id: UInt64, to location: CGPoint) -> Update? {
        guard let index = fingers.firstIndex(where: { $0.id == id }) else { return nil }
        fingers[index].location = location
        guard index < 2, fingers.count >= 2, let startDistance else { return nil }
        let next = distance / startDistance
        guard next != scale else { return nil }
        scale = next
        return Update(phase: .moved, scale: scale, location: center)
    }

    package mutating func fingerUp(_ id: UInt64, cancelled: Bool = false) -> Update? {
        guard let index = fingers.firstIndex(where: { $0.id == id }) else { return nil }
        let wasPinching = index < 2 && fingers.count >= 2 && startDistance != nil
        let update = wasPinching ? Update(phase: cancelled ? .cancelled : .ended, scale: scale, location: center) : nil
        fingers.remove(at: index)
        if wasPinching {
            // Another pinch starts only when two fingers are down again.
            startDistance = nil
            fingers.removeAll()
        }
        return update
    }

    private var distance: Double {
        let first = fingers[0].location, second = fingers[1].location
        return Double(hypot(second.x - first.x, second.y - first.y))
    }

    private var center: CGPoint {
        let first = fingers[0].location, second = fingers[1].location
        return CGPoint(x: (first.x + second.x) / 2, y: (first.y + second.y) / 2)
    }
}
