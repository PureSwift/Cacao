//
//  Publishers.swift
//  Cacao
//
//  Created by Alsey Coleman Miller on 11/13/26.
//

import CacaoRender
import Foundation

#if !(canImport(Darwin) && canImport(Combine))

// Where there's no Combine, Cacao provides the part of it SwiftUI code
// commonly uses: publishers to receive values from (`onReceive`, `sink`),
// subjects, `Just`, timers, notifications and `@Published` projections.
// Values are delivered as they're sent, without demand.

/// Declares that a type can transmit a sequence of values over time.
public protocol Publisher<Output, Failure> {

    associatedtype Output

    associatedtype Failure: Error

    /// Calls `receive` with each value the publisher sends, until the
    /// returned cancellable is cancelled or released.
    func _subscribe(_ receive: @escaping (Output) -> Void) -> AnyCancellable
}

/// A type-erasing cancellable object that executes a provided closure when
/// canceled, or when it's released.
public final class AnyCancellable: Hashable, @unchecked Sendable {

    private var cancelAction: (() -> Void)?

    public init(_ cancel: @escaping () -> Void) {
        self.cancelAction = cancel
    }

    public func cancel() {
        let action = cancelAction
        cancelAction = nil
        action?()
    }

    /// Stores this cancellable in a collection.
    public func store(in set: inout Set<AnyCancellable>) {
        set.insert(self)
    }

    /// Stores this cancellable in an array.
    public func store(in array: inout [AnyCancellable]) {
        array.append(self)
    }

    deinit {
        cancelAction?()
    }

    public static func == (lhs: AnyCancellable, rhs: AnyCancellable) -> Bool {
        lhs === rhs
    }

    public func hash(into hasher: inout Hasher) {
        hasher.combine(ObjectIdentifier(self))
    }
}

extension Publisher where Failure == Never {

    /// Attaches a subscriber with closure-based behavior to a publisher
    /// that never fails.
    public func sink(receiveValue: @escaping (Output) -> Void) -> AnyCancellable {
        _subscribe(receiveValue)
    }

    /// Assigns each element from a publisher to a property on an object.
    public func assign<Root: AnyObject>(to keyPath: ReferenceWritableKeyPath<Root, Output>, on object: Root) -> AnyCancellable {
        _subscribe { [weak object] value in
            object?[keyPath: keyPath] = value
        }
    }
}

// MARK: Async sequences

/// A publisher's values as an asynchronous sequence.
public struct AsyncPublisher<P: Publisher>: AsyncSequence where P.Failure == Never {

    public typealias Element = P.Output

    let publisher: P

    public init(_ publisher: P) {
        self.publisher = publisher
    }

    public struct Iterator: AsyncIteratorProtocol {

        var iterator: AsyncStream<Element>.Iterator

        /// Keeps the subscription while the iterator lives.
        let subscription: AnyCancellable

        public mutating func next() async -> Element? {
            await iterator.next()
        }
    }

    public func makeAsyncIterator() -> Iterator {
        let (stream, continuation) = AsyncStream<Element>.makeStream()
        nonisolated(unsafe) let unsafeContinuation = continuation
        let subscription = publisher._subscribe { value in
            nonisolated(unsafe) let value = value
            unsafeContinuation.yield(value)
        }
        continuation.onTermination = { _ in subscription.cancel() }
        return Iterator(iterator: stream.makeAsyncIterator(), subscription: subscription)
    }
}

extension Publisher where Failure == Never {

    /// The elements produced by the publisher, as an asynchronous sequence.
    public var values: AsyncPublisher<Self> {
        AsyncPublisher(self)
    }
}

// MARK: Operators

/// A publisher of another publisher's values, transformed.
public struct _MapPublisher<Upstream: Publisher, Output>: Publisher {

    public typealias Failure = Upstream.Failure

    let upstream: Upstream

    let transform: (Upstream.Output) -> Output

    public func _subscribe(_ receive: @escaping (Output) -> Void) -> AnyCancellable {
        let transform = self.transform
        return upstream._subscribe { receive(transform($0)) }
    }
}

/// A publisher of the values of another publisher that pass a test.
public struct _FilterPublisher<Upstream: Publisher>: Publisher {

    public typealias Output = Upstream.Output

    public typealias Failure = Upstream.Failure

    let upstream: Upstream

    let isIncluded: (Upstream.Output) -> Bool

    public func _subscribe(_ receive: @escaping (Output) -> Void) -> AnyCancellable {
        let isIncluded = self.isIncluded
        return upstream._subscribe { if isIncluded($0) { receive($0) } }
    }
}

/// A publisher of another publisher's values that differ from the last.
public struct _RemoveDuplicatesPublisher<Upstream: Publisher>: Publisher where Upstream.Output: Equatable {

    public typealias Output = Upstream.Output

    public typealias Failure = Upstream.Failure

    let upstream: Upstream

    public func _subscribe(_ receive: @escaping (Output) -> Void) -> AnyCancellable {
        var last: Output?
        return upstream._subscribe { value in
            guard value != last else { return }
            last = value
            receive(value)
        }
    }
}

/// A publisher that performs type erasure by wrapping another publisher.
public struct AnyPublisher<Output, Failure: Error>: Publisher {

    private let subscribe: (@escaping (Output) -> Void) -> AnyCancellable

    public init<P: Publisher>(_ publisher: P) where P.Output == Output, P.Failure == Failure {
        self.subscribe = publisher._subscribe
    }

    public func _subscribe(_ receive: @escaping (Output) -> Void) -> AnyCancellable {
        subscribe(receive)
    }
}

extension Publisher {

    public func map<T>(_ transform: @escaping (Output) -> T) -> _MapPublisher<Self, T> {
        _MapPublisher(upstream: self, transform: transform)
    }

    public func filter(_ isIncluded: @escaping (Output) -> Bool) -> _FilterPublisher<Self> {
        _FilterPublisher(upstream: self, isIncluded: isIncluded)
    }

    public func removeDuplicates() -> _RemoveDuplicatesPublisher<Self> where Output: Equatable {
        _RemoveDuplicatesPublisher(upstream: self)
    }

    /// Values are delivered as they're sent; Cacao's `onReceive` delivers
    /// them on the main thread.
    public func receive<S>(on scheduler: S) -> Self {
        self
    }

    public func eraseToAnyPublisher() -> AnyPublisher<Output, Failure> {
        AnyPublisher(self)
    }
}

// MARK: Subjects

/// Subscribers of a subject, by token.
private final class Subscribers<Output>: @unchecked Sendable {

    private let lock = NSLock()

    private var next = 0

    private var receivers: [Int: (Output) -> Void] = [:]

    func add(_ receive: @escaping (Output) -> Void) -> AnyCancellable {
        lock.lock()
        next += 1
        let token = next
        receivers[token] = receive
        lock.unlock()
        return AnyCancellable { [weak self] in
            self?.lock.lock()
            self?.receivers[token] = nil
            self?.lock.unlock()
        }
    }

    func send(_ value: Output) {
        lock.lock()
        let current = receivers.sorted { $0.key < $1.key }.map(\.value)
        lock.unlock()
        for receive in current {
            receive(value)
        }
    }
}

/// A subject that broadcasts elements to downstream subscribers.
public final class PassthroughSubject<Output, Failure: Error>: Publisher, @unchecked Sendable {

    private let subscribers = Subscribers<Output>()

    public init() { }

    public func send(_ value: Output) {
        subscribers.send(value)
    }

    public func _subscribe(_ receive: @escaping (Output) -> Void) -> AnyCancellable {
        subscribers.add(receive)
    }
}

extension PassthroughSubject where Output == Void {

    public func send() {
        send(())
    }
}

/// A subject that wraps a single value and publishes a new element
/// whenever the value changes.
public final class CurrentValueSubject<Output, Failure: Error>: Publisher, @unchecked Sendable {

    private let subscribers = Subscribers<Output>()

    private let lock = NSLock()

    private var current: Output

    public init(_ value: Output) {
        self.current = value
    }

    /// The value wrapped by this subject, published as a new element
    /// whenever it changes.
    public var value: Output {
        get {
            lock.lock()
            defer { lock.unlock() }
            return current
        }
        set {
            send(newValue)
        }
    }

    public func send(_ value: Output) {
        lock.lock()
        current = value
        lock.unlock()
        subscribers.send(value)
    }

    /// New subscribers receive the current value first.
    public func _subscribe(_ receive: @escaping (Output) -> Void) -> AnyCancellable {
        let cancellable = subscribers.add(receive)
        receive(value)
        return cancellable
    }
}

/// A publisher that emits an output to each subscriber just once.
public struct Just<Output>: Publisher {

    public typealias Failure = Never

    public let output: Output

    public init(_ output: Output) {
        self.output = output
    }

    public func _subscribe(_ receive: @escaping (Output) -> Void) -> AnyCancellable {
        receive(output)
        return AnyCancellable { }
    }
}

extension ObservableObjectPublisher {

    public typealias Output = Void

    public typealias Failure = Never
}

extension Published {

    /// A publisher of a published property's new values, sent before the
    /// property changes.
    public struct Publisher: Cacao.Publisher {

        public typealias Output = Value

        public typealias Failure = Never

        let subject: CurrentValueSubject<Value, Never>

        public func _subscribe(_ receive: @escaping (Value) -> Void) -> AnyCancellable {
            subject._subscribe(receive)
        }
    }
}

// MARK: Timers and notifications

extension Timer {

    /// Returns a publisher that repeatedly emits the current date on the
    /// given interval.
    public static func publish(
        every interval: TimeInterval,
        tolerance: TimeInterval? = nil,
        on runLoop: RunLoop,
        in mode: RunLoop.Mode,
        options: Any? = nil
    ) -> TimerPublisher {
        TimerPublisher(interval: interval, runLoop: runLoop, mode: mode)
    }

    /// A publisher that repeatedly emits the current date on a given
    /// interval, once connected.
    public final class TimerPublisher: Cacao.Publisher, @unchecked Sendable {

        public typealias Output = Date

        public typealias Failure = Never

        public let interval: TimeInterval

        public let runLoop: RunLoop

        public let mode: RunLoop.Mode

        private let subscribers = Subscribers<Date>()

        private var timer: Timer?

        init(interval: TimeInterval, runLoop: RunLoop, mode: RunLoop.Mode) {
            self.interval = interval
            self.runLoop = runLoop
            self.mode = mode
        }

        /// Starts the timer, returning what stops it.
        public func connect() -> AnyCancellable {
            if timer == nil {
                let timer = Timer(timeInterval: interval, repeats: true) { [weak self] _ in
                    self?.subscribers.send(Date())
                }
                runLoop.add(timer, forMode: mode)
                self.timer = timer
            }
            return AnyCancellable { [weak self] in
                self?.timer?.invalidate()
                self?.timer = nil
            }
        }

        /// A publisher that connects the timer when it's first subscribed
        /// to, and disconnects it when the last subscription ends.
        public func autoconnect() -> Autoconnect {
            Autoconnect(upstream: self)
        }

        public func _subscribe(_ receive: @escaping (Date) -> Void) -> AnyCancellable {
            subscribers.add(receive)
        }

        public final class Autoconnect: Cacao.Publisher, @unchecked Sendable {

            public typealias Output = Date

            public typealias Failure = Never

            public let upstream: TimerPublisher

            private var connection: AnyCancellable?

            private var count = 0

            init(upstream: TimerPublisher) {
                self.upstream = upstream
            }

            public func _subscribe(_ receive: @escaping (Date) -> Void) -> AnyCancellable {
                let subscription = upstream._subscribe(receive)
                count += 1
                if connection == nil {
                    connection = upstream.connect()
                }
                return AnyCancellable { [weak self] in
                    subscription.cancel()
                    guard let self else { return }
                    self.count -= 1
                    if self.count == 0 {
                        self.connection?.cancel()
                        self.connection = nil
                    }
                }
            }
        }
    }
}

extension NotificationCenter {

    /// Returns a publisher that emits events when broadcasting notifications.
    public func publisher(for name: Notification.Name, object: AnyObject? = nil) -> NotificationCenter.Publisher {
        Publisher(center: self, name: name, object: object)
    }

    /// A publisher that emits elements when broadcasting notifications.
    public struct Publisher: Cacao.Publisher {

        public typealias Output = Notification

        public typealias Failure = Never

        public let center: NotificationCenter

        public let name: Notification.Name

        public let object: AnyObject?

        public func _subscribe(_ receive: @escaping (Notification) -> Void) -> AnyCancellable {
            nonisolated(unsafe) let receive = receive
            let observer = center.addObserver(forName: name, object: object, queue: nil) { receive($0) }
            nonisolated(unsafe) let center = self.center
            return AnyCancellable { center.removeObserver(observer) }
        }
    }
}

#endif

// MARK: - onReceive

#if canImport(Darwin) && canImport(Combine)
import Combine
#endif

/// The subscription of an `onReceive` modifier, and its latest action.
private final class ReceiveState<Output>: @unchecked Sendable {

    var subscription: AnyCancellable?

    var action: ((Output) -> Void)?

    /// Runs the latest action: right away on the main thread, or else on
    /// the main actor.
    func deliver(_ value: Output) {
        if Thread.isMainThread {
            action?(value)
        } else {
            nonisolated(unsafe) let value = value
            let state = UncheckedSendable(self)
            Task { @MainActor in
                state.value.action?(value)
            }
        }
    }
}

internal struct _ReceiveModifier<P: Publisher>: ViewModifier, PrimitiveViewModifier where P.Failure == Never {

    let publisher: P

    let action: (P.Output) -> Void

    func resolve(content: any View, in context: ResolveContext) -> Resolution {
        let node = context.node
        let state = (node.dynamicStorage["receive"] as? ReceiveState<P.Output>) ?? ReceiveState<P.Output>()
        node.dynamicStorage["receive"] = state
        state.action = action
        // Subscribes once, for as long as the view shows.
        let publisher = self.publisher
        let subscribe = { [weak state] in
            guard let state, state.subscription == nil else { return }
            state.subscription = publisher.sink { [weak state] value in
                state?.deliver(value)
            }
        }
        subscribe()
        var attributes = NodeAttributes()
        attributes.onAppear = subscribe
        attributes.onDisappear = { [weak state] in
            state?.subscription?.cancel()
            state?.subscription = nil
        }
        return Resolution(children: [ChildView(key: 0, view: content)], attributes: attributes)
    }

    typealias Body = Never
}

extension View {

    /// Adds an action to perform when this view detects data emitted by
    /// the given publisher.
    public func onReceive<P: Publisher>(
        _ publisher: P,
        perform action: @escaping (P.Output) -> Void
    ) -> some View where P.Failure == Never {
        modifier(_ReceiveModifier(publisher: publisher, action: action))
    }
}
