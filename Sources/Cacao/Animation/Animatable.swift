//
//  Animatable.swift
//  Cacao
//
//  Created by Alsey Coleman Miller on 11/13/26.
//

import Foundation
#if canImport(CoreGraphics)
import CoreGraphics
#endif

/// A type that can serve as the animatable data of an animatable type.
public protocol VectorArithmetic: AdditiveArithmetic {

    /// Multiplies each component of this value by the given value.
    mutating func scale(by rhs: Double)

    /// Returns the dot-product of this vector arithmetic instance with itself.
    var magnitudeSquared: Double { get }
}

extension VectorArithmetic {

    /// Returns a value with each component of this value multiplied by the
    /// given value.
    public func scaled(by rhs: Double) -> Self {
        var result = self
        result.scale(by: rhs)
        return result
    }

    /// Interpolates this value with `other` by the specified `amount`.
    public func interpolated(towards other: Self, amount: Double) -> Self {
        self + (other - self).scaled(by: amount)
    }
}

extension Double: VectorArithmetic {
    public mutating func scale(by rhs: Double) { self *= rhs }
    public var magnitudeSquared: Double { self * self }
}

extension Float: VectorArithmetic {
    public mutating func scale(by rhs: Double) { self *= Float(rhs) }
    public var magnitudeSquared: Double { Double(self * self) }
}

extension CGFloat: VectorArithmetic {
    public mutating func scale(by rhs: Double) { self *= CGFloat(rhs) }
    public var magnitudeSquared: Double { Double(self * self) }
}

/// An empty type for animatable data.
public struct EmptyAnimatableData: VectorArithmetic, Sendable {

    public init() { }

    public static var zero: EmptyAnimatableData { EmptyAnimatableData() }

    public static func + (lhs: EmptyAnimatableData, rhs: EmptyAnimatableData) -> EmptyAnimatableData { lhs }

    public static func - (lhs: EmptyAnimatableData, rhs: EmptyAnimatableData) -> EmptyAnimatableData { lhs }

    public mutating func scale(by rhs: Double) { }

    public var magnitudeSquared: Double { 0 }
}

/// A pair of animatable values, which is itself animatable.
public struct AnimatablePair<First: VectorArithmetic, Second: VectorArithmetic>: VectorArithmetic {

    public var first: First

    public var second: Second

    public init(_ first: First, _ second: Second) {
        self.first = first
        self.second = second
    }

    public static var zero: AnimatablePair { AnimatablePair(.zero, .zero) }

    public static func + (lhs: AnimatablePair, rhs: AnimatablePair) -> AnimatablePair {
        AnimatablePair(lhs.first + rhs.first, lhs.second + rhs.second)
    }

    public static func - (lhs: AnimatablePair, rhs: AnimatablePair) -> AnimatablePair {
        AnimatablePair(lhs.first - rhs.first, lhs.second - rhs.second)
    }

    public mutating func scale(by rhs: Double) {
        first.scale(by: rhs)
        second.scale(by: rhs)
    }

    public var magnitudeSquared: Double {
        first.magnitudeSquared + second.magnitudeSquared
    }
}

extension AnimatablePair: Sendable where First: Sendable, Second: Sendable { }

/// A type that describes how to animate a property of a view.
public protocol Animatable {

    /// The type defining the data to animate.
    associatedtype AnimatableData: VectorArithmetic

    /// The data to animate.
    var animatableData: Self.AnimatableData { get set }
}

extension Animatable where Self.AnimatableData == EmptyAnimatableData {

    public var animatableData: EmptyAnimatableData {
        get { EmptyAnimatableData() }
        set { }
    }
}

extension RoundedRectangle: Animatable {

    public nonisolated var animatableData: AnimatablePair<CGFloat, CGFloat> {
        get { AnimatablePair(cornerSize.width, cornerSize.height) }
        set { cornerSize = CGSize(width: newValue.first, height: newValue.second) }
    }
}

extension Rectangle: Animatable { }
extension Circle: Animatable { }
extension Ellipse: Animatable { }
extension Capsule: Animatable { }

// MARK: - Angle

/// A geometric angle whose value you access in either radians or degrees.
public struct Angle: Hashable, Comparable, Sendable, Animatable {

    public var radians: Double

    public var degrees: Double {
        get { radians * 180 / .pi }
        set { radians = newValue * .pi / 180 }
    }

    public init() {
        self.radians = 0
    }

    public init(radians: Double) {
        self.radians = radians
    }

    public init(degrees: Double) {
        self.radians = degrees * .pi / 180
    }

    public static func radians(_ radians: Double) -> Angle {
        Angle(radians: radians)
    }

    public static func degrees(_ degrees: Double) -> Angle {
        Angle(degrees: degrees)
    }

    public static let zero = Angle()

    public static func < (lhs: Angle, rhs: Angle) -> Bool {
        lhs.radians < rhs.radians
    }

    public var animatableData: Double {
        get { radians }
        set { radians = newValue }
    }
}

// MARK: - Animatable data as a vector

/// Converts animatable data to and from a list of numbers, for animating
/// values of any animatable type the same way.
internal enum AnimatableVector {

    /// The components of animatable data, if it's made of known parts.
    static func components(_ data: any VectorArithmetic) -> [Double]? {
        switch data {
        case let value as Double: return [value]
        case let value as CGFloat: return [Double(value)]
        case let value as Float: return [Double(value)]
        case is EmptyAnimatableData: return []
        case let pair as any _AnimatablePairProtocol: return pair.components
        default: return nil
        }
    }

    /// Animatable data of the same shape as `template`, from components.
    static func value<V: VectorArithmetic>(_ components: [Double], like template: V) -> V? {
        var index = 0
        return build(template, components, &index)
    }

    static func build<V: VectorArithmetic>(_ template: V, _ components: [Double], _ index: inout Int) -> V? {
        switch template {
        case is Double:
            defer { index += 1 }
            return components.indices.contains(index) ? components[index] as? V : nil
        case is CGFloat:
            defer { index += 1 }
            return components.indices.contains(index) ? CGFloat(components[index]) as? V : nil
        case is Float:
            defer { index += 1 }
            return components.indices.contains(index) ? Float(components[index]) as? V : nil
        case is EmptyAnimatableData:
            return template
        case let pair as any _AnimatablePairProtocol:
            return pair.rebuild(components, &index) as? V
        default:
            return nil
        }
    }
}

internal protocol _AnimatablePairProtocol {
    var components: [Double]? { get }
    func rebuild(_ components: [Double], _ index: inout Int) -> Any?
}

extension AnimatablePair: _AnimatablePairProtocol {

    var components: [Double]? {
        guard let first = AnimatableVector.components(first),
              let second = AnimatableVector.components(second) else { return nil }
        return first + second
    }

    func rebuild(_ components: [Double], _ index: inout Int) -> Any? {
        guard let first = AnimatableVector.build(first, components, &index),
              let second = AnimatableVector.build(second, components, &index) else { return nil }
        return AnimatablePair(first, second)
    }
}
