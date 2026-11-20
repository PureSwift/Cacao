//
//  TouchRotation.swift
//  Cacao
//
//  Created by Alsey Coleman Miller on 11/15/26.
//

import CacaoRender
import Foundation
#if canImport(CoreGraphics)
import CoreGraphics
#endif

/// Follows the fingers on a touch screen and reports how the first two
/// turn around each other, for hosts whose platform reports touches but not
/// rotations.
///
/// The angle is the total since the second finger came down, in radians,
/// clockwise on screen as `RotateGesture` reports it, and it keeps counting
/// past a half turn.
package struct TouchRotationTracker {

    /// A change to the rotation, for `ViewGraph.rotate`.
    package struct Update: Equatable {
        package var phase: PointerPhase
        package var angle: Double
        /// Between the two fingers.
        package var location: CGPoint
    }

    private var fingers: [(id: UInt64, location: CGPoint)] = []

    /// The direction from the first finger to the second, last seen.
    private var lastDirection: Double?

    private var angle = 0.0

    package init() { }

    package mutating func fingerDown(_ id: UInt64, at location: CGPoint) -> Update? {
        guard !fingers.contains(where: { $0.id == id }) else { return nil }
        fingers.append((id, location))
        guard fingers.count == 2 else { return nil }
        angle = 0
        lastDirection = direction
        return Update(phase: .began, angle: 0, location: center)
    }

    package mutating func fingerMoved(_ id: UInt64, to location: CGPoint) -> Update? {
        guard let index = fingers.firstIndex(where: { $0.id == id }) else { return nil }
        fingers[index].location = location
        guard index < 2, fingers.count >= 2, let last = lastDirection else { return nil }
        let direction = self.direction
        // The smallest turn from the last direction, so crossing a half turn
        // doesn't jump.
        var delta = direction - last
        while delta > .pi { delta -= 2 * .pi }
        while delta <= -.pi { delta += 2 * .pi }
        lastDirection = direction
        guard delta != 0 else { return nil }
        angle += delta
        return Update(phase: .moved, angle: angle, location: center)
    }

    package mutating func fingerUp(_ id: UInt64, cancelled: Bool = false) -> Update? {
        guard let index = fingers.firstIndex(where: { $0.id == id }) else { return nil }
        let wasRotating = index < 2 && fingers.count >= 2 && lastDirection != nil
        let update = wasRotating ? Update(phase: cancelled ? .cancelled : .ended, angle: angle, location: center) : nil
        fingers.remove(at: index)
        if wasRotating {
            // Another rotation starts only when two fingers are down again.
            lastDirection = nil
            fingers.removeAll()
        }
        return update
    }

    private var direction: Double {
        let first = fingers[0].location, second = fingers[1].location
        return atan2(Double(second.y - first.y), Double(second.x - first.x))
    }

    private var center: CGPoint {
        let first = fingers[0].location, second = fingers[1].location
        return CGPoint(x: (first.x + second.x) / 2, y: (first.y + second.y) / 2)
    }
}
