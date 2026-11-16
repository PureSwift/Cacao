//
//  ObservableObject.swift
//  Cacao
//
//  Created by Alsey Coleman Miller on 11/13/26.
//

import Foundation
import Observation

// MARK: - ObservableObject

#if canImport(Combine)
// Apple platforms: Combine's ObservableObject and Published, which
// Foundation also exports.
@_exported import Combine

/// Subscribes to an object's changes, returning what keeps the subscription.
internal func subscribe<T: ObservableObject>(_ object: T, _ action: @escaping @Sendable () -> Void) -> AnyObject {
    object.objectWillChange.sink { _ in action() }
}
#else
// MARK: - ObservableObject

/// A type of object with a publisher that emits before the object has changed.
///
/// Cacao provides this protocol without Combine: the publisher tells the
/// views that use the object to update.
public protocol ObservableObject: AnyObject {

    /// The type of publisher that emits before the object has changed.
    associatedtype ObjectWillChangePublisher: ObjectWillChangePublishing = ObservableObjectPublisher

    /// A publisher that emits before the object has changed.
    var objectWillChange: ObjectWillChangePublisher { get }
}

/// A publisher that views subscribe to, to update when an object changes:
/// a publisher of `Void` that never fails, as Combine's are.
public protocol ObjectWillChangePublishing: AnyObject, Publisher where Output == Void, Failure == Never {

    /// Calls an action before each change, until the subscription goes away.
    func subscribe(_ action: @escaping @Sendable () -> Void) -> ObjectSubscription
}

extension ObjectWillChangePublishing {

    public func _subscribe(_ receive: @escaping (()) -> Void) -> AnyCancellable {
        nonisolated(unsafe) let receive = receive
        let subscription = subscribe { receive(()) }
        return AnyCancellable { _ = subscription }
    }
}

/// A subscription to an object's changes, cancelled when released.
public final class ObjectSubscription: @unchecked Sendable {

    private let cancel: () -> Void

    init(cancel: @escaping () -> Void) {
        self.cancel = cancel
    }

    deinit {
        cancel()
    }
}

/// A publisher that publishes changes from observable objects.
public final class ObservableObjectPublisher: ObjectWillChangePublishing, @unchecked Sendable {

    private let lock = NSLock()

    private var subscribers: [Int: @Sendable () -> Void] = [:]

    private var nextID = 0

    public init() { }

    /// Sends the changed value to the downstream subscribers.
    public func send() {
        lock.lock()
        let actions = Array(subscribers.values)
        lock.unlock()
        for action in actions {
            action()
        }
    }

    public func subscribe(_ action: @escaping @Sendable () -> Void) -> ObjectSubscription {
        lock.lock()
        let id = nextID
        nextID += 1
        subscribers[id] = action
        lock.unlock()
        return ObjectSubscription { [weak self] in
            guard let self else { return }
            self.lock.lock()
            self.subscribers[id] = nil
            self.lock.unlock()
        }
    }
}

extension ObservableObject where ObjectWillChangePublisher == ObservableObjectPublisher {

    /// A publisher that emits before the object has changed, one per object.
    public var objectWillChange: ObservableObjectPublisher {
        ObjectPublishers.shared.publisher(for: self)
    }
}

/// The publishers of objects that don't store their own.
private final class ObjectPublishers: @unchecked Sendable {

    static let shared = ObjectPublishers()

    private struct Entry {
        weak var object: AnyObject?
        let publisher: ObservableObjectPublisher
    }

    private let lock = NSLock()

    private var entries: [ObjectIdentifier: Entry] = [:]

    func publisher(for object: AnyObject) -> ObservableObjectPublisher {
        lock.lock()
        defer { lock.unlock() }
        let id = ObjectIdentifier(object)
        if let entry = entries[id], entry.object === object {
            return entry.publisher
        }
        // Forget objects that are gone, now and then.
        if entries.count > 64, entries.count.isMultiple(of: 64) {
            entries = entries.filter { $0.value.object != nil }
        }
        let publisher = ObservableObjectPublisher()
        entries[id] = Entry(object: object, publisher: publisher)
        return publisher
    }
}

/// A type that publishes a property marked with an attribute.
@propertyWrapper
public struct Published<Value> {

    private var value: Value

    /// What `$property` publishes to, made when first asked for.
    private var subject: CurrentValueSubject<Value, Never>?

    /// Creates the published instance with an initial wrapped value.
    public init(wrappedValue: Value) {
        self.value = wrappedValue
    }

    /// A publisher of the property's values.
    public var projectedValue: Publisher {
        mutating get {
            if let subject {
                return Publisher(subject: subject)
            }
            let subject = CurrentValueSubject<Value, Never>(value)
            self.subject = subject
            return Publisher(subject: subject)
        }
    }

    /// Creates the published instance with an initial value.
    public init(initialValue: Value) {
        self.init(wrappedValue: initialValue)
    }

    @available(*, unavailable, message: "@Published is only available on properties of classes")
    public var wrappedValue: Value {
        get { fatalError() }
        set { fatalError() }
    }

    public static subscript<EnclosingSelf: ObservableObject>(
        _enclosingInstance object: EnclosingSelf,
        wrapped wrappedKeyPath: ReferenceWritableKeyPath<EnclosingSelf, Value>,
        storage storageKeyPath: ReferenceWritableKeyPath<EnclosingSelf, Published<Value>>
    ) -> Value {
        get {
            object[keyPath: storageKeyPath].value
        }
        set {
            (object.objectWillChange as? ObservableObjectPublisher)?.send()
            object[keyPath: storageKeyPath].subject?.send(newValue)
            object[keyPath: storageKeyPath].value = newValue
        }
    }
}

extension Published: @unchecked Sendable where Value: Sendable { }

/// Subscribes to an object's changes, returning what keeps the subscription.
internal func subscribe<T: ObservableObject>(_ object: T, _ action: @escaping @Sendable () -> Void) -> AnyObject {
    object.objectWillChange.subscribe(action)
}
#endif

// MARK: - Subscribing nodes

extension ViewNode {

    /// Updates the node when an object changes, replacing the subscription
    /// stored under `label`.
    func subscribe(to object: AnyObject?, using subscribe: ((@escaping @Sendable () -> Void) -> AnyObject)?, label: String) {
        let key = "subscription." + label
        let existing = dynamicStorage[key] as? NodeSubscription
        if let object, existing?.object === object {
            return
        }
        guard let object, let subscribe else {
            dynamicStorage[key] = nil
            return
        }
        let queue = UncheckedSendable(graph.invalidations)
        let node = WeakNode(self)
        let subscription = subscribe {
            // Changes may come from any thread; the queue hops to the main actor.
            queue.value.enqueue(node.node, transaction: Transaction.current)
        }
        dynamicStorage[key] = NodeSubscription(object: object, subscription: subscription)
    }
}

private final class NodeSubscription {

    weak var object: AnyObject?

    let subscription: AnyObject

    init(object: AnyObject, subscription: AnyObject) {
        self.object = object
        self.subscription = subscription
    }
}

/// A function subscribing to an object's changes.
private func subscriber<T: ObservableObject>(of object: T) -> (@escaping @Sendable () -> Void) -> AnyObject {
    { action in subscribe(object, action) }
}

// MARK: - StateObject

/// A property wrapper type that instantiates an observable object.
@propertyWrapper
public struct StateObject<ObjectType: ObservableObject>: DynamicProperty {

    internal let box: StateObjectBox<ObjectType>

    /// Creates a new state object with an initial wrapped value.
    public init(wrappedValue thunk: @autoclosure @escaping () -> ObjectType) {
        self.box = StateObjectBox(thunk)
    }

    /// The underlying value referenced by the state object.
    public var wrappedValue: ObjectType {
        box.object
    }

    /// A projection of the state object that creates bindings to its properties.
    public var projectedValue: ObservedObject<ObjectType>.Wrapper {
        ObservedObject<ObjectType>.Wrapper(object: box.object)
    }
}

extension StateObject: DynamicPropertyInstaller {

    func install(in node: ViewNode, label: String) {
        let persisted: StateObjectBox<ObjectType>
        if let existing = node.dynamicStorage[label] as? StateObjectBox<ObjectType> {
            persisted = existing
            if existing !== box {
                box.target = existing
            }
        } else {
            persisted = box
            node.dynamicStorage[label] = box
        }
        let object = persisted.object
        node.subscribe(to: object, using: subscriber(of: object), label: label)
    }
}

/// Storage for a state object: created once, the first time it's read at
/// its node.
internal final class StateObjectBox<ObjectType: AnyObject> {

    private let thunk: () -> ObjectType

    private var stored: ObjectType?

    var target: StateObjectBox<ObjectType>?

    init(_ thunk: @escaping () -> ObjectType) {
        self.thunk = thunk
    }

    var object: ObjectType {
        if let target {
            return target.object
        }
        if let stored {
            return stored
        }
        let object = thunk()
        stored = object
        return object
    }
}

// MARK: - ObservedObject

/// A property wrapper type that subscribes to an observable object and
/// invalidates a view whenever the observable object changes.
@propertyWrapper
public struct ObservedObject<ObjectType: ObservableObject>: DynamicProperty {

    /// A wrapper of the underlying observable object that can create
    /// bindings to its properties.
    @dynamicMemberLookup
    public struct Wrapper {

        let object: ObjectType

        /// Gets a binding to the value of a specified key path.
        public subscript<Subject>(dynamicMember keyPath: ReferenceWritableKeyPath<ObjectType, Subject>) -> Binding<Subject> {
            let object = self.object
            return Binding(get: { object[keyPath: keyPath] }, set: { object[keyPath: keyPath] = $0 })
        }
    }

    /// The underlying value that the observed object references.
    public var wrappedValue: ObjectType

    /// Creates an observed object with an initial wrapped value.
    public init(wrappedValue: ObjectType) {
        self.wrappedValue = wrappedValue
    }

    /// Creates an observed object with an initial value.
    public init(initialValue: ObjectType) {
        self.init(wrappedValue: initialValue)
    }

    /// A projection of the observed object that creates bindings to its properties.
    public var projectedValue: Wrapper {
        Wrapper(object: wrappedValue)
    }
}

extension ObservedObject: DynamicPropertyInstaller {

    func install(in node: ViewNode, label: String) {
        node.subscribe(to: wrappedValue, using: subscriber(of: wrappedValue), label: label)
    }
}

// MARK: - EnvironmentObject

/// A property wrapper type for an observable object that a parent or
/// ancestor view supplies.
@propertyWrapper
public struct EnvironmentObject<ObjectType: ObservableObject>: DynamicProperty {

    internal let box = EnvironmentBox()

    public init() { }

    /// The underlying value referenced by the environment object.
    public var wrappedValue: ObjectType {
        guard let object = box.values?.object(of: ObjectType.self) else {
            fatalError("No ObservableObject of type \(ObjectType.self) found. A View.environmentObject(_:) for \(ObjectType.self) may be missing as an ancestor of this view.")
        }
        return object
    }

    /// A projection of the environment object that creates bindings to its
    /// properties.
    public var projectedValue: ObservedObject<ObjectType>.Wrapper {
        ObservedObject<ObjectType>.Wrapper(object: wrappedValue)
    }
}

extension EnvironmentObject: DynamicPropertyInstaller {

    func install(in node: ViewNode, label: String) {
        box.values = node.environment
        let object = node.environment.object(of: ObjectType.self)
        node.subscribe(to: object, using: object.map { subscriber(of: $0) }, label: label)
    }
}

internal struct _EnvironmentObjectModifier<T: ObservableObject>: ViewModifier, _EnvironmentModifier {

    let object: T

    func modify(_ environment: inout EnvironmentValues) {
        environment.setObject(object, of: T.self)
    }

    typealias Body = Never
}

extension View {

    /// Supplies an observable object to a view's hierarchy.
    public func environmentObject<T: ObservableObject>(_ object: T) -> some View {
        modifier(_EnvironmentObjectModifier(object: object))
    }
}

// MARK: - Bindable

/// A property wrapper type that supports creating bindings to the mutable
/// properties of observable objects.
@dynamicMemberLookup
@propertyWrapper
public struct Bindable<Value> {

    /// The wrapped object.
    public var wrappedValue: Value

    /// Creates a bindable object from an observable object.
    public init(wrappedValue: Value) {
        self.wrappedValue = wrappedValue
    }

    /// The bindable wrapper for the object that creates bindings to its properties.
    public var projectedValue: Bindable<Value> {
        self
    }

    /// Returns a binding to the value of a given key path.
    public subscript<Subject>(dynamicMember keyPath: ReferenceWritableKeyPath<Value, Subject>) -> Binding<Subject> where Value: AnyObject {
        let object = wrappedValue
        return Binding(get: { object[keyPath: keyPath] }, set: { object[keyPath: keyPath] = $0 })
    }
}

extension Bindable where Value: AnyObject, Value: Observable {

    /// Creates a bindable object from an observable object.
    public init(_ wrappedValue: Value) {
        self.wrappedValue = wrappedValue
    }

    /// Creates a bindable from the value of another bindable.
    public init(projectedValue: Bindable<Value>) {
        self = projectedValue
    }
}

extension Bindable: DynamicProperty { }

// MARK: - AppStorage

/// A property wrapper type that reflects a value from `UserDefaults` and
/// invalidates a view on a change in value in that user default.
@propertyWrapper
public struct AppStorage<Value>: DynamicProperty {

    let key: String

    let defaultValue: Value

    let store: StorageBackend

    let read: (Any?) -> Value?

    let write: (Value) -> Any?

    /// The value of the stored default, or the default value.
    public var wrappedValue: Value {
        get { store.value(forKey: key).flatMap(read) ?? defaultValue }
        nonmutating set { store.set(write(newValue), forKey: key) }
    }

    /// A binding to the stored value.
    public var projectedValue: Binding<Value> {
        let storage = self
        return Binding(get: { storage.wrappedValue }, set: { storage.wrappedValue = $0 })
    }

    init(key: String, defaultValue: Value, store: UserDefaults?, read: @escaping (Any?) -> Value?, write: @escaping (Value) -> Any?) {
        self.key = key
        self.defaultValue = defaultValue
        self.store = .defaults(store ?? .standard)
        self.read = read
        self.write = write
    }

    init(scene key: String, defaultValue: Value, read: @escaping (Any?) -> Value?, write: @escaping (Value) -> Any?) {
        self.key = key
        self.defaultValue = defaultValue
        self.store = .scene
        self.read = read
        self.write = write
    }
}

extension AppStorage {

    public init(wrappedValue: Value, _ key: String, store: UserDefaults? = nil) where Value == Bool {
        self.init(key: key, defaultValue: wrappedValue, store: store, read: { $0 as? Bool }, write: { $0 })
    }

    public init(wrappedValue: Value, _ key: String, store: UserDefaults? = nil) where Value == Int {
        self.init(key: key, defaultValue: wrappedValue, store: store, read: { ($0 as? NSNumber)?.intValue ?? $0 as? Int }, write: { $0 })
    }

    public init(wrappedValue: Value, _ key: String, store: UserDefaults? = nil) where Value == Double {
        self.init(key: key, defaultValue: wrappedValue, store: store, read: { ($0 as? NSNumber)?.doubleValue ?? $0 as? Double }, write: { $0 })
    }

    public init(wrappedValue: Value, _ key: String, store: UserDefaults? = nil) where Value == String {
        self.init(key: key, defaultValue: wrappedValue, store: store, read: { $0 as? String }, write: { $0 })
    }

    public init(wrappedValue: Value, _ key: String, store: UserDefaults? = nil) where Value == URL {
        self.init(key: key, defaultValue: wrappedValue, store: store, read: { ($0 as? String).flatMap(URL.init(string:)) }, write: { $0.absoluteString })
    }

    public init(wrappedValue: Value, _ key: String, store: UserDefaults? = nil) where Value == Data {
        self.init(key: key, defaultValue: wrappedValue, store: store, read: { $0 as? Data }, write: { $0 })
    }

    public init(wrappedValue: Value, _ key: String, store: UserDefaults? = nil) where Value: RawRepresentable, Value.RawValue == Int {
        self.init(key: key, defaultValue: wrappedValue, store: store, read: { (($0 as? NSNumber)?.intValue ?? $0 as? Int).flatMap(Value.init(rawValue:)) }, write: { $0.rawValue })
    }

    public init(wrappedValue: Value, _ key: String, store: UserDefaults? = nil) where Value: RawRepresentable, Value.RawValue == String {
        self.init(key: key, defaultValue: wrappedValue, store: store, read: { ($0 as? String).flatMap(Value.init(rawValue:)) }, write: { $0.rawValue })
    }
}

extension AppStorage: DynamicPropertyInstaller {

    func install(in node: ViewNode, label: String) {
        // Writes from any view update every view using the key.
        let id = "\(store.identifier).\(key)"
        StorageObservers.shared.observe(id, node: node, label: label)
    }
}

/// Where app and scene storage keep values.
internal enum StorageBackend: @unchecked Sendable {

    case defaults(UserDefaults)

    /// Values kept for the scene while the app runs.
    case scene

    var identifier: String {
        switch self {
        case let .defaults(defaults): "defaults.\(ObjectIdentifier(defaults).hashValue)"
        case .scene: "scene"
        }
    }

    func value(forKey key: String) -> Any? {
        switch self {
        case let .defaults(defaults): defaults.object(forKey: key)
        case .scene: SceneValues.shared.values[key]
        }
    }

    func set(_ value: Any?, forKey key: String) {
        switch self {
        case let .defaults(defaults): defaults.set(value, forKey: key)
        case .scene: SceneValues.shared.values[key] = value
        }
        StorageObservers.shared.changed("\(identifier).\(key)")
    }
}

/// Values of scene storage.
private final class SceneValues: @unchecked Sendable {

    static let shared = SceneValues()

    var values: [String: Any] = [:]
}

/// The views using each stored key.
private final class StorageObservers: @unchecked Sendable {

    static let shared = StorageObservers()

    private let lock = NSLock()

    private var nodes: [String: [String: (node: WeakNode, queue: InvalidationQueue?)]] = [:]

    @MainActor
    func observe(_ key: String, node: ViewNode, label: String) {
        lock.lock()
        defer { lock.unlock() }
        nodes[key, default: [:]]["\(node.id).\(label)"] = (WeakNode(node), node.graph.invalidations)
    }

    func changed(_ key: String) {
        lock.lock()
        let observers = nodes[key]?.values.map { $0 } ?? []
        lock.unlock()
        for observer in observers {
            observer.queue?.enqueue(observer.node.node, transaction: Transaction.current)
        }
    }
}

/// A property wrapper type that reads and writes to persisted, per-scene storage.
@propertyWrapper
public struct SceneStorage<Value>: DynamicProperty {

    let storage: AppStorage<Value>

    /// The underlying value referenced by the state variable.
    public var wrappedValue: Value {
        get { storage.wrappedValue }
        nonmutating set { storage.wrappedValue = newValue }
    }

    /// A binding to the state value.
    public var projectedValue: Binding<Value> {
        storage.projectedValue
    }
}

extension SceneStorage {

    public init(wrappedValue: Value, _ key: String) where Value == Bool {
        storage = AppStorage(scene: key, defaultValue: wrappedValue, read: { $0 as? Bool }, write: { $0 })
    }

    public init(wrappedValue: Value, _ key: String) where Value == Int {
        storage = AppStorage(scene: key, defaultValue: wrappedValue, read: { $0 as? Int }, write: { $0 })
    }

    public init(wrappedValue: Value, _ key: String) where Value == Double {
        storage = AppStorage(scene: key, defaultValue: wrappedValue, read: { $0 as? Double }, write: { $0 })
    }

    public init(wrappedValue: Value, _ key: String) where Value == String {
        storage = AppStorage(scene: key, defaultValue: wrappedValue, read: { $0 as? String }, write: { $0 })
    }

    public init(wrappedValue: Value, _ key: String) where Value: RawRepresentable, Value.RawValue == String {
        storage = AppStorage(scene: key, defaultValue: wrappedValue, read: { ($0 as? String).flatMap(Value.init(rawValue:)) }, write: { $0.rawValue })
    }

    public init(wrappedValue: Value, _ key: String) where Value: RawRepresentable, Value.RawValue == Int {
        storage = AppStorage(scene: key, defaultValue: wrappedValue, read: { ($0 as? Int).flatMap(Value.init(rawValue:)) }, write: { $0.rawValue })
    }
}

extension SceneStorage: DynamicPropertyInstaller {

    func install(in node: ViewNode, label: String) {
        storage.install(in: node, label: label)
    }
}

// MARK: - task

internal struct _TaskModifier<ID: Equatable>: ViewModifier, PrimitiveViewModifier {

    let id: ID

    let priority: TaskPriority

    let action: @Sendable () async -> Void

    func resolve(content: any View, in context: ResolveContext) -> Resolution {
        let node = context.node
        let state = (node.dynamicStorage["task"] as? TaskState<ID>) ?? TaskState<ID>()
        node.dynamicStorage["task"] = state
        let priority = self.priority, action = self.action
        let start = { [weak state] in
            guard let state else { return }
            state.task?.cancel()
            state.task = Task(priority: priority) { @MainActor in
                await action()
            }
        }
        // A new id restarts a running task.
        if state.task != nil, let previous = state.id, previous != id {
            node.graph.deferAction(start)
        }
        state.id = id
        var attributes = NodeAttributes()
        attributes.onAppear = start
        attributes.onDisappear = { [weak state] in
            state?.task?.cancel()
            state?.task = nil
        }
        return Resolution(children: [ChildView(key: 0, view: content)], attributes: attributes)
    }

    typealias Body = Never
}

private final class TaskState<ID> {

    var id: ID?

    var task: Task<Void, Never>?

    deinit {
        task?.cancel()
    }
}

extension View {

    /// Adds an asynchronous task to perform before this view appears.
    public func task(
        priority: TaskPriority = .userInitiated,
        _ action: @escaping @Sendable () async -> Void
    ) -> some View {
        modifier(_TaskModifier(id: 0, priority: priority, action: action))
    }

    /// Adds a task to perform before this view appears or when a specified
    /// value changes.
    public func task<T: Equatable>(
        id value: T,
        priority: TaskPriority = .userInitiated,
        _ action: @escaping @Sendable () async -> Void
    ) -> some View {
        modifier(_TaskModifier(id: value, priority: priority, action: action))
    }
}

/// A weak reference to a node that any thread can hold.
internal final class WeakNode: @unchecked Sendable {

    weak var node: ViewNode?

    init(_ node: ViewNode) {
        self.node = node
    }
}
