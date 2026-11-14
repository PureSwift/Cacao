//
//  Transition.swift
//  Cacao
//
//  Created by Alsey Coleman Miller on 11/13/26.
//

import Foundation
#if canImport(CoreGraphics)
import CoreGraphics
#endif

// MARK: - Transform

/// An affine transform of the plane, for transform effects.
package struct Transform2D: Equatable, Sendable {

    package var a: CGFloat = 1
    package var b: CGFloat = 0
    package var c: CGFloat = 0
    package var d: CGFloat = 1
    package var tx: CGFloat = 0
    package var ty: CGFloat = 0

    package static let identity = Transform2D()

    package init() { }

    package init(a: CGFloat, b: CGFloat, c: CGFloat, d: CGFloat, tx: CGFloat, ty: CGFloat) {
        (self.a, self.b, self.c, self.d, self.tx, self.ty) = (a, b, c, d, tx, ty)
    }

    package static func translation(_ x: CGFloat, _ y: CGFloat) -> Transform2D {
        Transform2D(a: 1, b: 0, c: 0, d: 1, tx: x, ty: y)
    }

    package static func scale(_ x: CGFloat, _ y: CGFloat) -> Transform2D {
        Transform2D(a: x, b: 0, c: 0, d: y, tx: 0, ty: 0)
    }

    package static func rotation(_ radians: CGFloat) -> Transform2D {
        let cosine = CGFloat(cos(Double(radians)))
        let sine = CGFloat(sin(Double(radians)))
        return Transform2D(a: cosine, b: sine, c: -sine, d: cosine, tx: 0, ty: 0)
    }

    /// This transform followed by another.
    package func concatenating(_ t: Transform2D) -> Transform2D {
        Transform2D(
            a: a * t.a + b * t.c,
            b: a * t.b + b * t.d,
            c: c * t.a + d * t.c,
            d: c * t.b + d * t.d,
            tx: tx * t.a + ty * t.c + t.tx,
            ty: tx * t.b + ty * t.d + t.ty
        )
    }

    /// The transform about a point: move it to the origin, transform, move back.
    package func about(_ point: CGPoint) -> Transform2D {
        Transform2D.translation(-point.x, -point.y)
            .concatenating(self)
            .concatenating(.translation(point.x, point.y))
    }

    package func apply(_ point: CGPoint) -> CGPoint {
        CGPoint(x: a * point.x + c * point.y + tx, y: b * point.x + d * point.y + ty)
    }

    /// Whether the transform only moves.
    package var isTranslation: Bool {
        a == 1 && b == 0 && c == 0 && d == 1
    }

    /// The transform that undoes this one, if it can be undone.
    package func inverted() -> Transform2D? {
        let determinant = a * d - b * c
        guard determinant != 0 else { return nil }
        return Transform2D(
            a: d / determinant,
            b: -b / determinant,
            c: -c / determinant,
            d: a / determinant,
            tx: (c * ty - d * tx) / determinant,
            ty: (b * tx - a * ty) / determinant
        )
    }

    /// The bounding rectangle of a rectangle's transformed corners.
    package func boundingRect(of rect: CGRect) -> CGRect {
        guard !rect.isNull else { return rect }
        let corners = [
            apply(CGPoint(x: rect.minX, y: rect.minY)), apply(CGPoint(x: rect.maxX, y: rect.minY)),
            apply(CGPoint(x: rect.minX, y: rect.maxY)), apply(CGPoint(x: rect.maxX, y: rect.maxY)),
        ]
        let xs = corners.map(\.x), ys = corners.map(\.y)
        return CGRect(x: xs.min()!, y: ys.min()!, width: xs.max()! - xs.min()!, height: ys.max()! - ys.min()!)
    }
}

// MARK: - AnyTransition

/// A type-erased transition: how a view looks as it's inserted or removed.
public struct AnyTransition: Sendable {

    /// A transitioning view's frame, and the size of the window it's in.
    internal struct TransitionGeometry {

        let frame: CGRect

        let container: CGSize

        var minX: CGFloat { frame.minX }
        var minY: CGFloat { frame.minY }
        var maxX: CGFloat { frame.maxX }
        var maxY: CGFloat { frame.maxY }
        var midX: CGFloat { frame.midX }
        var midY: CGFloat { frame.midY }
        var width: CGFloat { frame.width }
        var height: CGFloat { frame.height }
        var origin: CGPoint { frame.origin }
        var size: CGSize { frame.size }
    }

    /// How a view looks at the start of its insertion, or the end of its
    /// removal, given its frame.
    internal struct State {
        var opacity: Double = 1
        var transform: Transform2D = .identity

        func combined(with other: State) -> State {
            State(opacity: opacity * other.opacity, transform: transform.concatenating(other.transform))
        }
    }

    internal let insertion: @Sendable (TransitionGeometry) -> State

    internal let removal: @Sendable (TransitionGeometry) -> State

    internal init(insertion: @escaping @Sendable (TransitionGeometry) -> State, removal: @escaping @Sendable (TransitionGeometry) -> State) {
        self.insertion = insertion
        self.removal = removal
    }

    internal init(_ state: @escaping @Sendable (TransitionGeometry) -> State) {
        self.init(insertion: state, removal: state)
    }

    /// A transition that returns the input view, unmodified, as the output view.
    public static let identity = AnyTransition { _ in State() }

    /// A transition from transparent to opaque on insertion, and from opaque
    /// to transparent on removal.
    public static let opacity = AnyTransition { _ in State(opacity: 0) }

    /// A transition that scales the view.
    public static var scale: AnyTransition {
        scale(scale: 0, anchor: .center)
    }

    /// Returns a transition that scales the view.
    public static func scale(scale: CGFloat, anchor: UnitPoint = .center) -> AnyTransition {
        AnyTransition { frame in
            let point = CGPoint(x: frame.minX + frame.width * anchor.x, y: frame.minY + frame.height * anchor.y)
            return State(transform: Transform2D.scale(max(scale, 0.0001), max(scale, 0.0001)).about(point))
        }
    }

    /// Returns a transition that offsets the view by the specified amount.
    public static func offset(_ offset: CGSize) -> AnyTransition {
        AnyTransition { _ in State(transform: .translation(offset.width, offset.height)) }
    }

    /// Returns a transition that offsets the view by the specified x and y values.
    public static func offset(x: CGFloat = 0, y: CGFloat = 0) -> AnyTransition {
        offset(CGSize(width: x, height: y))
    }

    /// Returns a transition that moves the view away, towards the specified edge.
    public static func move(edge: Edge) -> AnyTransition {
        AnyTransition { frame in
            switch edge {
            // Just past the edge of the window.
            case .leading: State(transform: .translation(-frame.maxX, 0))
            case .trailing: State(transform: .translation(max(frame.container.width - frame.minX, frame.width), 0))
            case .top: State(transform: .translation(0, -frame.maxY))
            case .bottom: State(transform: .translation(0, max(frame.container.height - frame.minY, frame.height)))
            }
        }
    }

    /// A transition that inserts by moving in from the leading edge, and
    /// removes by moving out towards the trailing edge.
    public static var slide: AnyTransition {
        asymmetric(insertion: .move(edge: .leading), removal: .move(edge: .trailing))
    }

    /// Creates a transition that when added to a view will animate the
    /// view's insertion by moving it in from the specified edge, and its
    /// removal by moving it out towards the opposite edge, fading as it goes.
    public static func push(from edge: Edge) -> AnyTransition {
        let opposite: Edge = switch edge {
        case .leading: .trailing
        case .trailing: .leading
        case .top: .bottom
        case .bottom: .top
        }
        return asymmetric(insertion: .move(edge: edge), removal: .move(edge: opposite).combined(with: .opacity))
    }

    /// Provides a composite transition that uses a different transition for
    /// insertion versus removal.
    public static func asymmetric(insertion: AnyTransition, removal: AnyTransition) -> AnyTransition {
        AnyTransition(insertion: insertion.insertion, removal: removal.removal)
    }

    /// Combines this transition with another, returning a new transition
    /// that is the result of both transitions being applied.
    public func combined(with other: AnyTransition) -> AnyTransition {
        let insertion = self.insertion
        let removal = self.removal
        return AnyTransition(
            insertion: { insertion($0).combined(with: other.insertion($0)) },
            removal: { removal($0).combined(with: other.removal($0)) }
        )
    }

    /// The effect partway through: `progress` from 0 (out) to 1 (in).
    internal func effect(progress: Double, frame: CGRect, container: CGSize, isInsertion: Bool) -> (opacity: Double, transform: Transform2D) {
        let state = (isInsertion ? insertion : removal)(TransitionGeometry(frame: frame, container: container))
        let p = CGFloat(progress)
        let t = state.transform
        let transform = Transform2D(
            a: 1 + (t.a - 1) * (1 - p),
            b: t.b * (1 - p),
            c: t.c * (1 - p),
            d: 1 + (t.d - 1) * (1 - p),
            tx: t.tx * (1 - p),
            ty: t.ty * (1 - p)
        )
        return (1 + (state.opacity - 1) * (1 - progress), transform)
    }
}

internal struct _TransitionModifier: ViewModifier, PrimitiveViewModifier {

    let transition: AnyTransition

    func resolve(content: any View, in context: ResolveContext) -> Resolution {
        var attributes = NodeAttributes()
        attributes.transition = transition
        return Resolution(children: [ChildView(key: 0, view: content)], attributes: attributes)
    }

    typealias Body = Never
}

extension View {

    /// Associates a transition with the view.
    public func transition(_ t: AnyTransition) -> some View {
        modifier(_TransitionModifier(transition: t))
    }
}

// MARK: - Transform effects

/// Scales or rotates its content's drawing about an anchor, without changing
/// its layout.
internal struct TransformBehavior: UnaryLayoutBehavior, AnimatableBehavior {

    var scale: CGSize

    var rotation: Double

    let anchor: UnitPoint

    func sizeThatFits(_ proposal: ProposedViewSize, child: LayoutProxy) -> CGSize {
        child.size(in: proposal)
    }

    func placement(of child: LayoutProxy, size: CGSize, proposal: ProposedViewSize) -> (proposal: ProposedViewSize, origin: CGPoint) {
        (proposal, CGPoint(x: 0, y: 0))
    }

    func displayEffect(node: ViewNode) -> DisplayList.Effect? {
        let frame = node.graph.presentationFrame(of: node)
        let point = CGPoint(x: frame.minX + frame.width * anchor.x, y: frame.minY + frame.height * anchor.y)
        let transform = Transform2D.scale(scale.width, scale.height)
            .concatenating(.rotation(CGFloat(rotation)))
            .about(point)
        return transform == .identity ? nil : .transform(transform)
    }

    var animatableValues: [Double] {
        [Double(scale.width), Double(scale.height), rotation]
    }

    func applying(_ values: [Double]) -> any NodeBehavior {
        TransformBehavior(scale: CGSize(width: values[0], height: values[1]), rotation: values[2], anchor: anchor)
    }
}

internal struct _TransformEffect: ViewModifier, LayoutModifier {

    let scale: CGSize

    let rotation: Double

    let anchor: UnitPoint

    var behavior: any NodeBehavior { TransformBehavior(scale: scale, rotation: rotation, anchor: anchor) }

    typealias Body = Never
}

extension View {

    /// Scales this view's rendered output by the given amount in both the
    /// horizontal and vertical directions, relative to an anchor point.
    public func scaleEffect(_ s: CGFloat, anchor: UnitPoint = .center) -> some View {
        scaleEffect(x: s, y: s, anchor: anchor)
    }

    /// Scales this view's rendered output by the given horizontal and
    /// vertical amounts, relative to an anchor point.
    public func scaleEffect(x: CGFloat = 1, y: CGFloat = 1, anchor: UnitPoint = .center) -> some View {
        modifier(_TransformEffect(scale: CGSize(width: x, height: y), rotation: 0, anchor: anchor))
    }

    /// Scales this view's rendered output by the given size.
    public func scaleEffect(_ scale: CGSize, anchor: UnitPoint = .center) -> some View {
        scaleEffect(x: scale.width, y: scale.height, anchor: anchor)
    }

    /// Rotates a view's rendered output in two dimensions around the
    /// specified point.
    public func rotationEffect(_ angle: Angle, anchor: UnitPoint = .center) -> some View {
        modifier(_TransformEffect(scale: CGSize(width: 1, height: 1), rotation: angle.radians, anchor: anchor))
    }
}

// MARK: - Matched geometry

/// A dynamic property type that allows access to a namespace defined by the
/// persistent identity of the object containing the property.
@propertyWrapper
public struct Namespace: DynamicProperty {

    /// A namespace's identity.
    public struct ID: Hashable, Sendable {
        internal let value: Int
    }

    internal var box = StateBox(0)

    nonisolated(unsafe) private static var next = 0

    public init() { }

    public var wrappedValue: Namespace.ID {
        if box.value == 0 {
            Self.next += 1
            box.value = Self.next
        }
        return ID(value: box.value)
    }
}

extension Namespace: DynamicPropertyInstaller {

    func install(in node: ViewNode, label: String) {
        box.install(in: node, label: label)
    }
}

/// The key of a matched geometry group.
internal struct MatchedGeometryKey: Hashable {
    let id: AnyHashable
    let namespace: Namespace.ID
}

/// How a view takes part in a matched geometry group.
internal struct MatchedGeometry {

    let key: AnyHashable

    let properties: MatchedGeometryProperties

    let anchor: UnitPoint

    /// Whether the view's geometry is the group's; other views take it.
    let isSource: Bool

    /// The point of `frame` at the view's anchor: where a source is, for
    /// views that match its position.
    func anchorPoint(in frame: CGRect) -> CGPoint {
        CGPoint(x: frame.minX + frame.width * anchor.x, y: frame.minY + frame.height * anchor.y)
    }

    /// The frame of a view now at `current` that takes from a source what
    /// `properties` say: its size, and its position, by lining up the view's
    /// anchor with the source's `point`. A view that doesn't take the
    /// position keeps its origin.
    func frame(at current: CGRect, matching size: CGSize, point: CGPoint) -> CGRect {
        let size = properties.contains(.size) ? size : current.size
        guard properties.contains(.position) else {
            return CGRect(origin: current.origin, size: size)
        }
        return CGRect(
            x: point.x - size.width * anchor.x,
            y: point.y - size.height * anchor.y,
            width: size.width,
            height: size.height
        )
    }
}

internal struct _MatchedGeometryModifier: ViewModifier, PrimitiveViewModifier {

    let geometry: MatchedGeometry

    func resolve(content: any View, in context: ResolveContext) -> Resolution {
        var attributes = NodeAttributes()
        attributes.matchedGeometry = geometry
        return Resolution(children: [ChildView(key: 0, view: content)], attributes: attributes)
    }

    typealias Body = Never
}

extension View {

    /// Defines a group of views with synchronized geometry: when one view
    /// with an identifier replaces another in an animated update, it moves
    /// and resizes from where the other was, and views that aren't the
    /// source take the source's frame, as far as `properties` say, lining up
    /// their `anchor` points.
    public func matchedGeometryEffect<ID: Hashable>(
        id: ID,
        in namespace: Namespace.ID,
        properties: MatchedGeometryProperties = .frame,
        anchor: UnitPoint = .center,
        isSource: Bool = true
    ) -> some View {
        modifier(_MatchedGeometryModifier(geometry: MatchedGeometry(
            key: AnyHashable(MatchedGeometryKey(id: AnyHashable(id), namespace: namespace)),
            properties: properties,
            anchor: anchor,
            isSource: isSource
        )))
    }
}

/// A set of view properties that may be synchronized between views using
/// matched geometry.
public struct MatchedGeometryProperties: OptionSet, Sendable {

    public let rawValue: UInt32

    public init(rawValue: UInt32) {
        self.rawValue = rawValue
    }

    public static let position = MatchedGeometryProperties(rawValue: 1 << 0)

    public static let size = MatchedGeometryProperties(rawValue: 1 << 1)

    public static let frame: MatchedGeometryProperties = [.position, .size]
}
