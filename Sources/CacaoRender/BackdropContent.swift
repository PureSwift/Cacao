//
//  BackdropContent.swift
//  CacaoRender
//
//  Created by Alsey Coleman Miller on 11/20/26.
//

import Foundation
#if canImport(CoreGraphics)
import CoreGraphics
#endif

/// What is already drawn behind an item, blurred, in the item's frame: the
/// frosted glass of a material or of Core Animation's backdrop layer.
///
/// It shows the frame as drawn so far, so it comes after what it blurs in
/// its display list.
public struct BackdropContent: Equatable, Sendable {

    /// The corners of a rectangle.
    public struct Corners: OptionSet, Hashable, Sendable {

        public let rawValue: Int

        public init(rawValue: Int) {
            self.rawValue = rawValue
        }

        public static let topLeading = Corners(rawValue: 1 << 0)
        public static let topTrailing = Corners(rawValue: 1 << 1)
        public static let bottomLeading = Corners(rawValue: 1 << 2)
        public static let bottomTrailing = Corners(rawValue: 1 << 3)
        public static let all: Corners = [.topLeading, .topTrailing, .bottomLeading, .bottomTrailing]
    }

    /// The blur's radius (a Gaussian's standard deviation), in points.
    public var blurRadius: CGFloat

    /// How much color the blurred backdrop keeps: 1 leaves it as it is,
    /// more makes it more vivid, 0 gray.
    public var saturation: Double

    /// The radius of the frame's rounded corners.
    public var cornerRadius: CGFloat

    /// Which corners are rounded.
    public var corners: Corners

    public init(blurRadius: CGFloat, saturation: Double = 1, cornerRadius: CGFloat = 0, corners: Corners = .all) {
        self.blurRadius = blurRadius
        self.saturation = saturation
        self.cornerRadius = cornerRadius
        self.corners = corners
    }
}
