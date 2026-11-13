//
//  ScrollPhysics.swift
//  CacaoScrollPhysics
//
//  Created by Alsey Coleman Miller on 11/13/26.
//

/// Scrolling physics: finger velocity, deceleration after a flick,
/// rubber-band overscroll and spring-back.
///
/// The implementation lands in Phase 2 (see `Documentation/Plan.md` §2.5),
/// ported from Perry's `PerryScrollPhysics`.
public enum ScrollPhysics {

    /// The distance a finger moves before a touch becomes a pan, in points.
    public static let panThreshold = 10.0

    /// UIScrollView's normal deceleration rate: the velocity kept each millisecond.
    public static let normalDecelerationRate = 0.998
}
