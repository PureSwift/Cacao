//
//  Gesture.swift
//  Cacao
//
//  Created by Alsey Coleman Miller on 11/13/26.
//

import CacaoRender
import Foundation
#if canImport(CoreGraphics)
import CoreGraphics
#endif

// MARK: - Gesture

/// An instance that matches a sequence of events to a gesture, and returns a
/// stream of values for each of its states.
@MainActor
@preconcurrency
public protocol Gesture<Value> {

    /// The type representing the gesture's value.
    associatedtype Value

    /// The type of gesture representing the body of `Self`.
    associatedtype Body: Gesture

    /// The content and behavior of the gesture.
    var body: Self.Body { get }
}

extension Never: Gesture {

    public typealias Value = Never
}

extension Gesture where Body == Never {

    public var body: Never {
        fatalError("\(Self.self) is a primitive gesture and has no body")
    }
}

/// A gesture Cacao recognizes directly.
@MainActor
internal protocol PrimitiveGesture {

    /// A recognizer for one interaction, for a view with the frame in the
    /// window, returning a `GestureRecognizer<Value>`.
    func makeRecognizer(in context: GestureContext) -> AnyGestureRecognizer
}

extension Gesture {

    /// A recognizer for one interaction with the gesture.
    func recognizer(in context: GestureContext) -> GestureRecognizer<Value> {
        if let primitive = self as? any PrimitiveGesture {
            return primitive.makeRecognizer(in: context) as! GestureRecognizer<Value>
        }
        guard let recognizer = body.recognizer(in: context) as? GestureRecognizer<Value> else {
            fatalError("The body of \(Self.self) has a different value type")
        }
        return recognizer
    }
}

/// Where a gesture's view is, for its values' coordinates.
internal struct GestureContext {

    /// The view's frame in the window.
    let frame: CGRect

    /// The origins of named coordinate spaces around the view, in the window.
    let namedSpaces: [AnyHashable: CGPoint]

    /// A window location in a coordinate space.
    func location(_ point: CGPoint, in space: CoordinateSpace) -> CGPoint {
        switch space {
        case .global:
            return point
        case .local:
            return CGPoint(x: point.x - frame.minX, y: point.y - frame.minY)
        case let .named(name):
            let origin = namedSpaces[name] ?? CGPoint(x: 0, y: 0)
            return CGPoint(x: point.x - origin.x, y: point.y - origin.y)
        }
    }
}

// MARK: - Coordinate spaces

/// A resolved coordinate space created by the coordinate space protocol.
public enum CoordinateSpace: Hashable, @unchecked Sendable {

    case global

    case local

    case named(AnyHashable)

    public var isGlobal: Bool { self == .global }

    public var isLocal: Bool { self == .local }
}

/// A frame of reference within the layout system.
public protocol CoordinateSpaceProtocol {

    /// The resolved coordinate space.
    var coordinateSpace: CoordinateSpace { get }
}

/// The global coordinate space at the root of the view hierarchy.
public struct GlobalCoordinateSpace: CoordinateSpaceProtocol {

    public init() { }

    public var coordinateSpace: CoordinateSpace { .global }
}

/// The local coordinate space of the current view.
public struct LocalCoordinateSpace: CoordinateSpaceProtocol {

    public init() { }

    public var coordinateSpace: CoordinateSpace { .local }
}

/// A named coordinate space.
public struct NamedCoordinateSpace: CoordinateSpaceProtocol, Equatable {

    let name: AnyHashable

    public var coordinateSpace: CoordinateSpace { .named(name) }
}

extension CoordinateSpaceProtocol where Self == GlobalCoordinateSpace {

    /// The global coordinate space at the root of the view hierarchy.
    public static var global: GlobalCoordinateSpace { GlobalCoordinateSpace() }
}

extension CoordinateSpaceProtocol where Self == LocalCoordinateSpace {

    /// The local coordinate space of the current view.
    public static var local: LocalCoordinateSpace { LocalCoordinateSpace() }
}

extension CoordinateSpaceProtocol where Self == NamedCoordinateSpace {

    /// Creates a named coordinate space using the given value.
    public static func named(_ name: some Hashable) -> NamedCoordinateSpace {
        NamedCoordinateSpace(name: AnyHashable(name))
    }
}

extension View {

    /// Assigns a name to the view's coordinate space, so other code can
    /// operate on dimensions like points and sizes relative to the named space.
    public func coordinateSpace(_ name: NamedCoordinateSpace) -> some View {
        modifier(_AttributesModifier { $0.coordinateSpaceName = name.name })
    }

    /// Assigns a name to the view's coordinate space.
    public func coordinateSpace<T: Hashable>(name: T) -> some View {
        coordinateSpace(.named(name))
    }
}

// MARK: - Gesture masks

/// Options that control how adding a gesture to a view affects other
/// gestures recognized by the view and its subviews.
public struct GestureMask: OptionSet, Sendable {

    public let rawValue: UInt32

    public init(rawValue: UInt32) {
        self.rawValue = rawValue
    }

    /// Disable all gestures in the subview hierarchy, including the added gesture.
    public static let none: GestureMask = []

    /// Enable the added gesture but disable all gestures in the subview hierarchy.
    public static let gesture = GestureMask(rawValue: 1)

    /// Enable all gestures in the subview hierarchy but disable the added gesture.
    public static let subviews = GestureMask(rawValue: 2)

    /// Enable both the added gesture as well as all other gestures on the view
    /// and its subviews.
    public static let all: GestureMask = [.gesture, .subviews]
}

// MARK: - Attaching gestures

/// A gesture attached to a view.
internal struct GestureAttachment {

    enum Priority {
        /// Recognized in place of the view's subviews' gestures.
        case high
        /// Subviews' gestures take precedence.
        case normal
        /// Recognized alongside other gestures.
        case simultaneous
    }

    let priority: Priority

    let mask: GestureMask

    let make: @MainActor (GestureContext) -> AnyGestureRecognizer
}

internal struct _GestureModifier<G: Gesture>: ViewModifier, PrimitiveViewModifier {

    let gesture: G

    let priority: GestureAttachment.Priority

    let mask: GestureMask

    func resolve(content: any View, in context: ResolveContext) -> Resolution {
        var attributes = NodeAttributes()
        if context.environment.isEnabled {
            let gesture = self.gesture
            attributes.gestures = [GestureAttachment(priority: priority, mask: mask) { context in
                gesture.recognizer(in: context)
            }]
        }
        // The system moves the window from here, enabled or not.
        attributes.isWindowDragArea = gesture is WindowDragGesture
        return Resolution(children: [ChildView(key: 0, view: content)], attributes: attributes)
    }

    typealias Body = Never
}

extension View {

    /// Attaches a gesture to the view with a lower precedence than gestures
    /// defined by the view.
    public func gesture<T: Gesture>(_ gesture: T, including mask: GestureMask = .all) -> some View {
        modifier(_GestureModifier(gesture: gesture, priority: .normal, mask: mask))
    }

    /// Attaches a gesture to the view, enabled or not.
    public func gesture<T: Gesture>(_ gesture: T, isEnabled: Bool) -> some View {
        modifier(_GestureModifier(gesture: gesture, priority: .normal, mask: isEnabled ? .all : .subviews))
    }

    /// Attaches a gesture to the view with a higher precedence than gestures
    /// defined by the view.
    public func highPriorityGesture<T: Gesture>(_ gesture: T, including mask: GestureMask = .all) -> some View {
        modifier(_GestureModifier(gesture: gesture, priority: .high, mask: mask))
    }

    /// Attaches a gesture to the view to process simultaneously with gestures
    /// defined by the view.
    public func simultaneousGesture<T: Gesture>(_ gesture: T, including mask: GestureMask = .all) -> some View {
        modifier(_GestureModifier(gesture: gesture, priority: .simultaneous, mask: mask))
    }

    /// Adds an action to perform when this view recognizes a tap gesture.
    public func onTapGesture(count: Int = 1, perform action: @escaping () -> Void) -> some View {
        gesture(TapGesture(count: count).onEnded { action() })
    }

    /// Adds an action to perform when this view recognizes a tap gesture,
    /// and provides the action with the location of the interaction.
    public func onTapGesture(
        count: Int = 1,
        coordinateSpace: some CoordinateSpaceProtocol = .local,
        perform action: @escaping (CGPoint) -> Void
    ) -> some View {
        gesture(SpatialTapGesture(count: count, coordinateSpace: coordinateSpace).onEnded { action($0.location) })
    }

    /// Adds an action to perform when this view recognizes a long press gesture.
    public func onLongPressGesture(
        minimumDuration: Double = 0.5,
        maximumDistance: CGFloat = 10,
        perform action: @escaping () -> Void,
        onPressingChanged: ((Bool) -> Void)? = nil
    ) -> some View {
        gesture(_PressingGesture(
            content: LongPressGesture(minimumDuration: minimumDuration, maximumDistance: maximumDistance).onEnded { _ in action() },
            onPressingChanged: onPressingChanged
        ))
    }

    /// Adds an action to perform when this view recognizes a long press gesture.
    public func onLongPressGesture(
        minimumDuration: Double = 0.5,
        maximumDistance: CGFloat = 10,
        pressing: ((Bool) -> Void)? = nil,
        perform action: @escaping () -> Void
    ) -> some View {
        onLongPressGesture(minimumDuration: minimumDuration, maximumDistance: maximumDistance, perform: action, onPressingChanged: pressing)
    }
}

// MARK: - Primitive gestures

/// A gesture that recognizes one or more taps.
public struct TapGesture: Gesture, PrimitiveGesture {

    /// The required number of tap events.
    public var count: Int

    public init(count: Int = 1) {
        self.count = count
    }

    public typealias Value = Void

    public typealias Body = Never

    func makeRecognizer(in context: GestureContext) -> AnyGestureRecognizer {
        TapRecognizer(count: count) { _ in () }
    }
}

/// A gesture that recognizes one or more taps and reports their location.
public struct SpatialTapGesture: Gesture, PrimitiveGesture {

    /// The attributes of a tap gesture.
    public struct Value: Equatable, Sendable {

        /// The location of the tap gesture's current event.
        public var location: CGPoint
    }

    /// The required number of tap events.
    public var count: Int

    /// The coordinate space in which to receive location values.
    public var coordinateSpace: CoordinateSpace

    public init(count: Int = 1, coordinateSpace: some CoordinateSpaceProtocol = .local) {
        self.count = count
        self.coordinateSpace = coordinateSpace.coordinateSpace
    }

    public typealias Body = Never

    func makeRecognizer(in context: GestureContext) -> AnyGestureRecognizer {
        let space = coordinateSpace
        return TapRecognizer(count: count) { location in
            Value(location: context.location(location, in: space))
        }
    }
}

/// A gesture that succeeds when the user performs a long press.
public struct LongPressGesture: Gesture, PrimitiveGesture {

    /// The minimum duration of the long press that must elapse before the
    /// gesture succeeds.
    public var minimumDuration: Double

    /// The maximum distance that the long press can move before the gesture fails.
    public var maximumDistance: CGFloat

    public init(minimumDuration: Double = 0.5, maximumDistance: CGFloat = 10) {
        self.minimumDuration = minimumDuration
        self.maximumDistance = maximumDistance
    }

    public typealias Value = Bool

    public typealias Body = Never

    func makeRecognizer(in context: GestureContext) -> AnyGestureRecognizer {
        LongPressRecognizer(minimumDuration: minimumDuration, maximumDistance: maximumDistance)
    }
}

/// A dragging motion that invokes an action as the drag-event sequence changes.
public struct DragGesture: Gesture, PrimitiveGesture {

    /// The attributes of a drag gesture.
    public struct Value: Equatable, Sendable {

        /// The time associated with the drag gesture's current event.
        public var time: Date

        /// The location of the drag gesture's current event.
        public var location: CGPoint

        /// The location of the drag gesture's first event.
        public var startLocation: CGPoint

        /// The total translation from the start of the drag gesture to the
        /// current event of the drag gesture.
        public var translation: CGSize {
            CGSize(width: location.x - startLocation.x, height: location.y - startLocation.y)
        }

        /// The current drag velocity, in points per second.
        public var velocity: CGSize

        /// A prediction, based on the current drag velocity, of where the
        /// final location will be if dragging stopped now.
        public var predictedEndLocation: CGPoint {
            CGPoint(x: location.x + velocity.width * 0.25, y: location.y + velocity.height * 0.25)
        }

        /// A prediction, based on the current drag velocity, of what the
        /// final translation will be if dragging stopped now.
        public var predictedEndTranslation: CGSize {
            CGSize(width: predictedEndLocation.x - startLocation.x, height: predictedEndLocation.y - startLocation.y)
        }
    }

    /// The minimum dragging distance before the gesture succeeds.
    public var minimumDistance: CGFloat

    /// The coordinate space in which to receive location values.
    public var coordinateSpace: CoordinateSpace

    public init(minimumDistance: CGFloat = 10, coordinateSpace: some CoordinateSpaceProtocol = .local) {
        self.minimumDistance = minimumDistance
        self.coordinateSpace = coordinateSpace.coordinateSpace
    }

    public typealias Body = Never

    func makeRecognizer(in context: GestureContext) -> AnyGestureRecognizer {
        let space = coordinateSpace
        return DragRecognizer(minimumDistance: minimumDistance) { start, location, velocity in
            Value(
                time: Date(),
                location: context.location(location, in: space),
                startLocation: context.location(start, in: space),
                velocity: velocity
            )
        }
    }
}

/// A gesture that recognizes a magnification motion and tracks the amount
/// of magnification.
public struct MagnifyGesture: Gesture, PrimitiveGesture {

    /// The attributes of a magnify gesture.
    public struct Value: Equatable, Sendable {

        /// The time associated with the gesture's current event.
        public var time: Date

        /// The relative amount that the gesture has magnified by.
        public var magnification: CGFloat

        /// The current magnification velocity.
        public var velocity: CGFloat

        /// The initial anchor point of the gesture in the modified view's
        /// coordinate space.
        public var startAnchor: UnitPoint

        /// The initial center of the gesture in the modified view's
        /// coordinate space.
        public var startLocation: CGPoint
    }

    /// The minimum required delta before the gesture starts.
    public var minimumScaleDelta: CGFloat

    public init(minimumScaleDelta: CGFloat = 0.01) {
        self.minimumScaleDelta = minimumScaleDelta
    }

    public typealias Body = Never

    func makeRecognizer(in context: GestureContext) -> AnyGestureRecognizer {
        let frame = context.frame
        return TwoFingerRecognizer(kind: .magnify, threshold: Double(minimumScaleDelta)) { amount, velocity, start in
            let local = context.location(start, in: .local)
            return Value(
                time: Date(),
                magnification: CGFloat(amount),
                velocity: CGFloat(velocity),
                startAnchor: UnitPoint(
                    x: frame.width > 0 ? local.x / frame.width : 0,
                    y: frame.height > 0 ? local.y / frame.height : 0
                ),
                startLocation: local
            )
        }
    }
}

/// A gesture that recognizes a magnification motion and tracks the amount
/// of magnification.
@available(*, deprecated, renamed: "MagnifyGesture")
public struct MagnificationGesture: Gesture, PrimitiveGesture {

    /// The minimum required delta before the gesture starts.
    public var minimumScaleDelta: CGFloat

    public init(minimumScaleDelta: CGFloat = 0.01) {
        self.minimumScaleDelta = minimumScaleDelta
    }

    public typealias Value = CGFloat

    public typealias Body = Never

    func makeRecognizer(in context: GestureContext) -> AnyGestureRecognizer {
        TwoFingerRecognizer(kind: .magnify, threshold: Double(minimumScaleDelta)) { amount, _, _ in
            CGFloat(amount)
        }
    }
}

/// A gesture that recognizes a rotation motion and tracks the angle of the rotation.
public struct RotateGesture: Gesture, PrimitiveGesture {

    /// The attributes of a rotation gesture.
    public struct Value: Equatable, Sendable {

        /// The time associated with the gesture's current event.
        public var time: Date

        /// The relative amount that the gesture has rotated by.
        public var rotation: Angle

        /// The current rotation velocity.
        public var velocity: Angle

        /// The initial anchor point of the gesture in the modified view's
        /// coordinate space.
        public var startAnchor: UnitPoint

        /// The initial center of the gesture in the modified view's
        /// coordinate space.
        public var startLocation: CGPoint
    }

    /// The minimum delta required before the gesture succeeds.
    public var minimumAngleDelta: Angle

    public init(minimumAngleDelta: Angle = .degrees(1)) {
        self.minimumAngleDelta = minimumAngleDelta
    }

    public typealias Body = Never

    func makeRecognizer(in context: GestureContext) -> AnyGestureRecognizer {
        let frame = context.frame
        return TwoFingerRecognizer(kind: .rotate, threshold: minimumAngleDelta.radians) { amount, velocity, start in
            let local = context.location(start, in: .local)
            return Value(
                time: Date(),
                rotation: .radians(amount),
                velocity: .radians(velocity),
                startAnchor: UnitPoint(
                    x: frame.width > 0 ? local.x / frame.width : 0,
                    y: frame.height > 0 ? local.y / frame.height : 0
                ),
                startLocation: local
            )
        }
    }
}

/// A gesture that recognizes a rotation motion and tracks the angle of the rotation.
@available(*, deprecated, renamed: "RotateGesture")
public struct RotationGesture: Gesture, PrimitiveGesture {

    /// The minimum delta required before the gesture succeeds.
    public var minimumAngleDelta: Angle

    public init(minimumAngleDelta: Angle = .degrees(1)) {
        self.minimumAngleDelta = minimumAngleDelta
    }

    public typealias Value = Angle

    public typealias Body = Never

    func makeRecognizer(in context: GestureContext) -> AnyGestureRecognizer {
        TwoFingerRecognizer(kind: .rotate, threshold: minimumAngleDelta.radians) { amount, _, _ in
            Angle.radians(amount)
        }
    }
}

// MARK: - Composed gestures

/// A gesture containing two gestures that can happen at the same time with
/// neither of them preceding the other.
public struct SimultaneousGesture<First: Gesture, Second: Gesture>: Gesture, PrimitiveGesture {

    /// The value of a simultaneous gesture that indicates which of its two
    /// gestures receives events.
    public struct Value {

        /// The value of the first gesture.
        public var first: First.Value?

        /// The value of the second gesture.
        public var second: Second.Value?
    }

    /// The first of two gestures that can happen simultaneously.
    public var first: First

    /// The second of two gestures that can happen simultaneously.
    public var second: Second

    public init(_ first: First, _ second: Second) {
        self.first = first
        self.second = second
    }

    public typealias Body = Never

    func makeRecognizer(in context: GestureContext) -> AnyGestureRecognizer {
        SimultaneousRecognizer(first: first.recognizer(in: context), second: second.recognizer(in: context)) {
            Value(first: $0, second: $1)
        }
    }
}

extension SimultaneousGesture.Value: Equatable where First.Value: Equatable, Second.Value: Equatable { }

extension SimultaneousGesture.Value: Sendable where First.Value: Sendable, Second.Value: Sendable { }

/// A gesture that's a sequence of two gestures.
public struct SequenceGesture<First: Gesture, Second: Gesture>: Gesture, PrimitiveGesture {

    /// The value of a sequence gesture that helps to detect whether the
    /// first gesture succeeded, so the second gesture can start.
    public enum Value {

        /// The first gesture hasn't ended.
        case first(First.Value)

        /// The first gesture has ended.
        case second(First.Value, Second.Value?)
    }

    /// The first gesture in a sequence of two gestures.
    public var first: First

    /// The second gesture in a sequence of two gestures.
    public var second: Second

    public init(_ first: First, _ second: Second) {
        self.first = first
        self.second = second
    }

    public typealias Body = Never

    func makeRecognizer(in context: GestureContext) -> AnyGestureRecognizer {
        let second = self.second
        return SequenceRecognizer<First.Value, Second.Value, Value>(
            first: first.recognizer(in: context),
            makeSecond: { second.recognizer(in: context) },
            first: { .first($0) },
            second: { .second($0, $1) }
        )
    }
}

extension SequenceGesture.Value: Equatable where First.Value: Equatable, Second.Value: Equatable { }

extension SequenceGesture.Value: Sendable where First.Value: Sendable, Second.Value: Sendable { }

/// A gesture that consists of two gestures where only one of them can succeed.
public struct ExclusiveGesture<First: Gesture, Second: Gesture>: Gesture, PrimitiveGesture {

    /// The value of an exclusive gesture that indicates which of two
    /// gestures succeeded.
    public enum Value {

        /// The first of two gestures succeeded.
        case first(First.Value)

        /// The second of two gestures succeeded.
        case second(Second.Value)
    }

    /// The first of two gestures.
    public var first: First

    /// The second of two gestures.
    public var second: Second

    public init(_ first: First, _ second: Second) {
        self.first = first
        self.second = second
    }

    public typealias Body = Never

    func makeRecognizer(in context: GestureContext) -> AnyGestureRecognizer {
        ExclusiveRecognizer<First.Value, Second.Value, Value>(
            first: first.recognizer(in: context),
            second: second.recognizer(in: context),
            first: { .first($0) },
            second: { .second($0) }
        )
    }
}

extension ExclusiveGesture.Value: Equatable where First.Value: Equatable, Second.Value: Equatable { }

extension ExclusiveGesture.Value: Sendable where First.Value: Sendable, Second.Value: Sendable { }

extension Gesture {

    /// Combines a gesture with another gesture to create a new gesture that
    /// recognizes both gestures at the same time.
    public func simultaneously<Other: Gesture>(with other: Other) -> SimultaneousGesture<Self, Other> {
        SimultaneousGesture(self, other)
    }

    /// Sequences a gesture with another one to create a new gesture, which
    /// results in the second gesture only receiving events after the first
    /// gesture succeeds.
    public func sequenced<Other: Gesture>(before other: Other) -> SequenceGesture<Self, Other> {
        SequenceGesture(self, other)
    }

    /// Combines two gestures exclusively to create a new gesture where only
    /// one gesture succeeds, giving precedence to the first gesture.
    public func exclusively<Other: Gesture>(before other: Other) -> ExclusiveGesture<Self, Other> {
        ExclusiveGesture(self, other)
    }
}

// MARK: - Gesture modifiers

/// A gesture that calls an action as its value changes.
public struct _ChangedGesture<Content: Gesture>: Gesture, PrimitiveGesture where Content.Value: Equatable {

    let content: Content

    let action: (Content.Value) -> Void

    public typealias Value = Content.Value

    public typealias Body = Never

    func makeRecognizer(in context: GestureContext) -> AnyGestureRecognizer {
        let action = self.action
        return CallbackRecognizer(content: content.recognizer(in: context)) { recognizer, inner in
            if inner.didChange, !inner.state.isFinished, let value = inner.value, (recognizer.lastReported as? Content.Value) != value {
                recognizer.lastReported = value
                recognizer.actions.append { action(value) }
            }
        }
    }
}

/// A gesture that calls an action when it ends.
public struct _EndedGesture<Content: Gesture>: Gesture, PrimitiveGesture {

    let content: Content

    let action: (Content.Value) -> Void

    public typealias Value = Content.Value

    public typealias Body = Never

    func makeRecognizer(in context: GestureContext) -> AnyGestureRecognizer {
        let action = self.action
        return CallbackRecognizer<Content.Value, Content.Value>(content: content.recognizer(in: context)) { recognizer, inner in
            if inner.state == .ended, inner.didChange, let value = inner.value {
                recognizer.actions.append { action(value) }
            }
        }
    }
}

/// A gesture that updates a gesture state as it changes.
public struct GestureStateGesture<Base: Gesture, State>: Gesture, PrimitiveGesture {

    public typealias Value = Base.Value

    /// The originating gesture.
    public var base: Base

    /// A value that changes as the user performs the gesture.
    public var state: GestureState<State>

    /// The updating gesture containing the originating gesture's value, the
    /// updated state of the gesture, and a transaction.
    public var body: (GestureStateGesture<Base, State>.Value, inout State, inout Transaction) -> Void

    public init(base: Base, state: GestureState<State>, body: @escaping (Value, inout State, inout Transaction) -> Void) {
        self.base = base
        self.state = state
        self.body = body
    }

    public typealias Body = Never

    func makeRecognizer(in context: GestureContext) -> AnyGestureRecognizer {
        let state = self.state
        let update = self.body
        let recognizer = CallbackRecognizer<Base.Value, Base.Value>(content: base.recognizer(in: context)) { recognizer, inner in
            if inner.didChange, !inner.state.isFinished, let value = inner.value {
                recognizer.actions.append {
                    var current = state.wrappedValue
                    var transaction = Transaction.current ?? Transaction()
                    update(value, &current, &transaction)
                    withTransaction(transaction) {
                        state.box.value = current
                    }
                }
            }
        }
        // However it ends, the state goes back to its initial value.
        recognizer.onFinish = { state.reset() }
        return recognizer
    }
}

/// A gesture that maps its value.
public struct _MapGesture<Content: Gesture, Value>: Gesture, PrimitiveGesture {

    let content: Content

    let transform: (Content.Value) -> Value

    public typealias Body = Never

    func makeRecognizer(in context: GestureContext) -> AnyGestureRecognizer {
        CallbackRecognizer<Content.Value, Value>(content: content.recognizer(in: context), transform: transform) { _, _ in }
    }
}

/// Reports a press starting and ending, for `onLongPressGesture`.
internal struct _PressingGesture<Content: Gesture>: Gesture, PrimitiveGesture {

    let content: Content

    let onPressingChanged: ((Bool) -> Void)?

    typealias Value = Content.Value

    typealias Body = Never

    func makeRecognizer(in context: GestureContext) -> AnyGestureRecognizer {
        guard let pressing = onPressingChanged else {
            return content.recognizer(in: context)
        }
        let recognizer = CallbackRecognizer<Content.Value, Content.Value>(content: content.recognizer(in: context)) { recognizer, inner in
            if !recognizer.isPressing, inner.didChange, !inner.state.isFinished {
                recognizer.actions.append {
                    recognizer.isPressing = true
                    pressing(true)
                }
            }
        }
        recognizer.onFinish = { [unowned recognizer] in
            guard recognizer.isPressing else { return }
            recognizer.isPressing = false
            pressing(false)
        }
        return recognizer
    }
}

extension Gesture where Value: Equatable {

    /// Adds an action to perform when the gesture's value changes.
    public func onChanged(_ action: @escaping (Value) -> Void) -> _ChangedGesture<Self> {
        _ChangedGesture(content: self, action: action)
    }
}

extension Gesture {

    /// Adds an action to perform when the gesture ends.
    public func onEnded(_ action: @escaping (Value) -> Void) -> _EndedGesture<Self> {
        _EndedGesture(content: self, action: action)
    }

    /// Updates the provided gesture state property as the gesture's value changes.
    public func updating<State>(
        _ state: GestureState<State>,
        body: @escaping (Value, inout State, inout Transaction) -> Void
    ) -> GestureStateGesture<Self, State> {
        GestureStateGesture(base: self, state: state, body: body)
    }

    /// Returns a gesture that's the result of mapping the given closure over
    /// the gesture.
    public func map<T>(_ body: @escaping (Value) -> T) -> _MapGesture<Self, T> {
        _MapGesture(content: self, transform: body)
    }
}

/// A type-erased gesture.
public struct AnyGesture<Value>: Gesture, PrimitiveGesture {

    private let make: @MainActor (GestureContext) -> GestureRecognizer<Value>

    /// Creates an instance from another gesture.
    public init<T: Gesture>(_ gesture: T) where Value == T.Value {
        self.make = { gesture.recognizer(in: $0) }
    }

    public typealias Body = Never

    func makeRecognizer(in context: GestureContext) -> AnyGestureRecognizer {
        make(context)
    }
}

// MARK: - GestureState

/// A property wrapper type that updates a property while the user performs
/// a gesture and resets the property back to its initial state when the
/// gesture ends.
@propertyWrapper
public struct GestureState<Value>: DynamicProperty {

    internal let box: StateBox<Value>

    private let initialValue: Value

    private let resetAction: (Value, inout Transaction) -> Void

    /// Creates a view state that's derived from a gesture.
    public init(wrappedValue: Value) {
        self.init(wrappedValue: wrappedValue, resetTransaction: Transaction())
    }

    /// Creates a view state that's derived from a gesture with an initial value.
    public init(initialValue: Value) {
        self.init(wrappedValue: initialValue)
    }

    /// Creates a view state that's derived from a gesture with an initial
    /// state value and a transaction to reset it.
    public init(wrappedValue: Value, resetTransaction: Transaction) {
        self.box = StateBox(wrappedValue)
        self.initialValue = wrappedValue
        self.resetAction = { _, transaction in transaction = resetTransaction }
    }

    /// Creates a view state that's derived from a gesture with an initial
    /// state value and a transaction to reset it.
    public init(initialValue: Value, resetTransaction: Transaction) {
        self.init(wrappedValue: initialValue, resetTransaction: resetTransaction)
    }

    /// Creates a view state that's derived from a gesture with an initial
    /// state value and a closure that provides a transaction to reset it.
    public init(wrappedValue: Value, reset: @escaping (Value, inout Transaction) -> Void) {
        self.box = StateBox(wrappedValue)
        self.initialValue = wrappedValue
        self.resetAction = reset
    }

    /// Creates a view state that's derived from a gesture with an initial
    /// state value and a closure that provides a transaction to reset it.
    public init(initialValue: Value, reset: @escaping (Value, inout Transaction) -> Void) {
        self.init(wrappedValue: initialValue, reset: reset)
    }

    /// The wrapped value referenced by the gesture state property.
    public var wrappedValue: Value {
        box.value
    }

    /// A binding to the gesture state property.
    public var projectedValue: GestureState<Value> {
        self
    }

    /// Puts the value back to its initial value.
    @MainActor
    internal func reset() {
        var transaction = Transaction()
        resetAction(box.value, &transaction)
        let initial = initialValue
        let box = self.box
        withTransaction(transaction) {
            box.value = initial
        }
    }
}

extension GestureState where Value: ExpressibleByNilLiteral {

    /// Creates a view state that's derived from a gesture with a transaction
    /// to reset it.
    public init(resetTransaction: Transaction = Transaction()) {
        self.init(wrappedValue: nil, resetTransaction: resetTransaction)
    }

    /// Creates a view state that's derived from a gesture with a closure
    /// that provides a transaction to reset it.
    public init(reset: @escaping (Value, inout Transaction) -> Void) {
        self.init(wrappedValue: nil, reset: reset)
    }
}

extension GestureState: DynamicPropertyInstaller {

    func install(in node: ViewNode, label: String) {
        box.install(in: node, label: label)
    }
}
