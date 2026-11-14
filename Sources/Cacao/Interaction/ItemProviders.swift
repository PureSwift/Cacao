//
//  ItemProviders.swift
//  Cacao
//
//  Created by Alsey Coleman Miller on 11/14/26.
//

import Foundation
#if canImport(CoreGraphics)
import CoreGraphics
#endif

#if !canImport(Darwin)
// Where Foundation has no item providers, Cacao provides the part of
// `NSItemProvider` that drag and drop uses: representations as data, and
// strings and URLs as objects. Loads complete before they return.

/// Who can load a representation of an item provider.
public enum NSItemProviderRepresentationVisibility: Int, Sendable {
    case all = 0
    case team = 1
    case group = 2
    case ownProcess = 3
}

/// An item provider for conveying data or a file between processes during
/// drag-and-drop or copy-and-paste activities.
open class NSItemProvider: NSObject, @unchecked Sendable {

    public typealias DataLoadHandler = @Sendable (@escaping @Sendable (Data?, (any Error)?) -> Void) -> Progress?

    private var representations: [(type: String, load: DataLoadHandler)] = []

    /// A name for the item, like a file name without its extension.
    open var suggestedName: String?

    public override init() {
        super.init()
    }

    /// Creates an item provider for a string.
    public convenience init(object: NSString) {
        self.init(string: object.description)
    }

    /// Creates an item provider for a URL.
    public convenience init(object: NSURL) {
        self.init(url: object as URL)
    }

    /// Creates an item provider for the contents of a file.
    public convenience init?(contentsOf fileURL: URL?) {
        guard let fileURL, fileURL.isFileURL else {
            return nil
        }
        self.init(url: fileURL)
        suggestedName = fileURL.deletingPathExtension().lastPathComponent
        registerDataRepresentation(forTypeIdentifier: "public.data", visibility: .all) { completion in
            do {
                completion(try Data(contentsOf: fileURL), nil)
            } catch {
                completion(nil, error)
            }
            return nil
        }
    }

    internal convenience init(string: String) {
        self.init()
        let data = Data(string.utf8)
        registerDataRepresentation(forTypeIdentifier: "public.utf8-plain-text", visibility: .all) { completion in
            completion(data, nil)
            return nil
        }
    }

    internal convenience init(url: URL) {
        self.init()
        let data = Data(url.absoluteString.utf8)
        let type = url.isFileURL ? "public.file-url" : "public.url"
        registerDataRepresentation(forTypeIdentifier: type, visibility: .all) { completion in
            completion(data, nil)
            return nil
        }
    }

    /// The identifiers of the types the provider has, in the order they
    /// were registered.
    open var registeredTypeIdentifiers: [String] {
        representations.map(\.type)
    }

    /// Registers a representation of the item as data of a type.
    open func registerDataRepresentation(
        forTypeIdentifier typeIdentifier: String,
        visibility: NSItemProviderRepresentationVisibility,
        loadHandler: @escaping DataLoadHandler
    ) {
        representations.append((typeIdentifier, loadHandler))
    }

    /// Whether the provider has a representation that conforms to a type.
    open func hasItemConformingToTypeIdentifier(_ typeIdentifier: String) -> Bool {
        representations.contains { UTType.identifier($0.type, conformsTo: typeIdentifier) }
    }

    /// Loads the first representation that conforms to a type, as data.
    @discardableResult
    open func loadDataRepresentation(
        forTypeIdentifier typeIdentifier: String,
        completionHandler: @escaping @Sendable (Data?, (any Error)?) -> Void
    ) -> Progress {
        let progress = Progress(totalUnitCount: 1)
        guard let representation = representations.first(where: { UTType.identifier($0.type, conformsTo: typeIdentifier) }) else {
            completionHandler(nil, CocoaError(.fileReadUnknown))
            return progress
        }
        _ = representation.load { data, error in
            progress.completedUnitCount = 1
            completionHandler(data, error)
        }
        return progress
    }

    /// Whether the provider can load a string.
    open func canLoadObject(ofClass aClass: String.Type) -> Bool {
        hasItemConformingToTypeIdentifier("public.text") || hasItemConformingToTypeIdentifier("public.url")
    }

    /// Whether the provider can load a URL.
    open func canLoadObject(ofClass aClass: URL.Type) -> Bool {
        hasItemConformingToTypeIdentifier("public.url")
    }

    /// Loads the item as a string.
    @discardableResult
    open func loadObject(ofClass aClass: String.Type, completionHandler: @escaping @Sendable (String?, (any Error)?) -> Void) -> Progress {
        let type = hasItemConformingToTypeIdentifier("public.text") ? "public.text" : "public.url"
        return loadDataRepresentation(forTypeIdentifier: type) { data, error in
            completionHandler(data.flatMap { String(data: $0, encoding: .utf8) }, error)
        }
    }

    /// Loads the item as a URL.
    @discardableResult
    open func loadObject(ofClass aClass: URL.Type, completionHandler: @escaping @Sendable (URL?, (any Error)?) -> Void) -> Progress {
        loadDataRepresentation(forTypeIdentifier: "public.url") { data, error in
            completionHandler(data.flatMap { String(data: $0, encoding: .utf8) }.flatMap { URL(string: $0) }, error)
        }
    }
}

extension UTType {

    /// The types that each type conforms to directly.
    private static let parents: [String: [String]] = [
        "public.utf8-plain-text": ["public.plain-text"],
        "public.plain-text": ["public.text"],
        "public.json": ["public.text"],
        "public.text": ["public.data", "public.content"],
        "public.file-url": ["public.url"],
        "public.url": ["public.data"],
        "public.png": ["public.image"],
        "public.jpeg": ["public.image"],
        "public.image": ["public.data", "public.content"],
        "com.adobe.pdf": ["public.data", "public.content"],
        "public.data": ["public.item"],
        "public.content": ["public.item"],
    ]

    /// Whether a type is another, or conforms to it.
    static func identifier(_ type: String, conformsTo target: String) -> Bool {
        if type == target || target == "public.item" {
            return true
        }
        return parents[type, default: []].contains { identifier($0, conformsTo: target) }
    }
}
#endif

// MARK: - Items as providers

/// An item of a drag as an item provider: values from within the app and
/// system drops are wrapped in one.
internal func itemProvider(for item: Any) -> NSItemProvider? {
    switch item {
    case let provider as NSItemProvider:
        return provider
    case let string as String:
        return NSItemProvider(object: string as NSString)
    case let url as URL:
        if url.isFileURL, let provider = NSItemProvider(contentsOf: url) {
            return provider
        }
        return NSItemProvider(object: url as NSURL)
    case let data as Data:
        let provider = NSItemProvider()
        provider.registerDataRepresentation(forTypeIdentifier: "public.data", visibility: .all) { completion in
            completion(data, nil)
            return nil
        }
        return provider
    default:
        return nil
    }
}

internal func itemProvider(_ provider: NSItemProvider, conformsToAnyOf types: [UTType]) -> Bool {
    types.contains { provider.hasItemConformingToTypeIdentifier($0.identifier) }
}

// MARK: - Drop delegates

/// The current state of a drop.
@MainActor
public struct DropInfo {

    /// The location of the drag in the coordinate space of the drop view.
    public let location: CGPoint

    internal let providers: [NSItemProvider]

    /// Whether any items conform to at least one of the types.
    public func hasItemsConforming(to contentTypes: [UTType]) -> Bool {
        providers.contains { itemProvider($0, conformsToAnyOf: contentTypes) }
    }

    /// The item providers for items that conform to at least one of the
    /// types.
    public func itemProviders(for contentTypes: [UTType]) -> [NSItemProvider] {
        providers.filter { itemProvider($0, conformsToAnyOf: contentTypes) }
    }
}

/// Operation types that determine how a drag and drop session handles
/// transferring data.
public enum DropOperation: Hashable, Sendable {

    /// Cancel the drag operation and transfer no data.
    case cancel

    /// The drop activity is not allowed at this location.
    case forbidden

    /// Copy the data to the modified view.
    case copy

    /// Move the data represented by the drag items instead of copying it.
    case move
}

/// The behavior of a drop.
public struct DropProposal: Sendable {

    /// The drop operation that the drop proposes to perform.
    public let operation: DropOperation

    public init(operation: DropOperation) {
        self.operation = operation
    }
}

/// An interface that you implement to interact with a drop operation in a
/// view modified to accept drops.
@MainActor
@preconcurrency
public protocol DropDelegate {

    /// Tells the delegate that a drop containing items conforming to one of
    /// the expected types entered a view that accepts drops.
    func validateDrop(info: DropInfo) -> Bool

    /// Tells the delegate it can request the item provider data from the
    /// drop info, returning whether it handled the drop.
    func performDrop(info: DropInfo) -> Bool

    /// Tells the delegate a validated drop has entered the modified view.
    func dropEntered(info: DropInfo)

    /// Tells the delegate that a validated drop moved inside the modified
    /// view.
    func dropUpdated(info: DropInfo) -> DropProposal?

    /// Tells the delegate a validated drop operation has exited the
    /// modified view.
    func dropExited(info: DropInfo)
}

extension DropDelegate {

    public func validateDrop(info: DropInfo) -> Bool { true }

    public func dropEntered(info: DropInfo) { }

    public func dropUpdated(info: DropInfo) -> DropProposal? { nil }

    public func dropExited(info: DropInfo) { }
}

/// Where a drop over a delegate's view is, between calls.
@MainActor
private final class DropDelegateState {
    var isInside = false
    var info = DropInfo(location: .zero, providers: [])
}

// MARK: - Modifiers

internal struct _ItemProviderDropModifier: ViewModifier, PrimitiveViewModifier {

    let types: [UTType]

    let delegate: any DropDelegate

    let isTargeted: Binding<Bool>?

    func resolve(content: any View, in context: ResolveContext) -> Resolution {
        let types = self.types, delegate = self.delegate, isTargeted = self.isTargeted
        let state = DropDelegateState()
        weak let node = context.node
        var attributes = NodeAttributes()
        attributes.dropTarget = DropTarget(
            accepts: { item in
                itemProvider(for: item).map { itemProvider($0, conformsToAnyOf: types) } ?? false
            },
            perform: { items, location in
                let info = DropInfo(location: location, providers: items.compactMap(itemProvider(for:)))
                state.isInside = false
                guard delegate.validateDrop(info: info) else { return false }
                return delegate.performDrop(info: info)
            },
            targeted: { targeted in
                isTargeted?.wrappedValue = targeted
                if !targeted, state.isInside {
                    state.isInside = false
                    delegate.dropExited(info: state.info)
                }
            },
            updated: { location in
                guard !state.isInside || location != state.info.location,
                      let graph = node?.graph, let session = graph.dragSession ?? graph.systemDragSession else { return }
                let providers = session.items.compactMap(itemProvider(for:)).filter { itemProvider($0, conformsToAnyOf: types) }
                state.info = DropInfo(location: location, providers: providers)
                if !state.isInside {
                    guard delegate.validateDrop(info: state.info) else { return }
                    state.isInside = true
                    delegate.dropEntered(info: state.info)
                }
                _ = delegate.dropUpdated(info: state.info)
            }
        )
        // The whole frame takes drops, as it does hits for gestures.
        attributes.contentShape = { Path($0) }
        return Resolution(children: [ChildView(key: 0, view: content)], attributes: attributes)
    }

    typealias Body = Never
}

/// A drop delegate that performs an action with the item providers.
private struct ActionDropDelegate: DropDelegate {

    let types: [UTType]

    let action: ([NSItemProvider], CGPoint) -> Bool

    func performDrop(info: DropInfo) -> Bool {
        let providers = info.itemProviders(for: types)
        return !providers.isEmpty && action(providers, info.location)
    }
}

extension View {

    /// Activates this view as the source of a drag and drop operation,
    /// providing the dragged item with an item provider.
    public func onDrag(_ data: @escaping () -> NSItemProvider) -> some View {
        modifier(_DraggableModifier(payload: data))
    }

    /// Activates this view as the source of a drag and drop operation, with
    /// a preview of the dragged item.
    public func onDrag<V: View>(_ data: @escaping () -> NSItemProvider, @ViewBuilder preview: () -> V) -> some View {
        modifier(_DraggableModifier(payload: data))
    }

    /// Defines the destination of a drag and drop operation that handles
    /// the dropped content with the item providers of the given types.
    public func onDrop(
        of supportedContentTypes: [UTType],
        isTargeted: Binding<Bool>?,
        perform action: @escaping (_ providers: [NSItemProvider]) -> Bool
    ) -> some View {
        modifier(_ItemProviderDropModifier(
            types: supportedContentTypes,
            delegate: ActionDropDelegate(types: supportedContentTypes) { providers, _ in action(providers) },
            isTargeted: isTargeted
        ))
    }

    /// Defines the destination of a drag and drop operation that handles
    /// the dropped content with the item providers of the given types, and
    /// the drop's location in the view.
    public func onDrop(
        of supportedContentTypes: [UTType],
        isTargeted: Binding<Bool>?,
        perform action: @escaping (_ providers: [NSItemProvider], _ location: CGPoint) -> Bool
    ) -> some View {
        modifier(_ItemProviderDropModifier(
            types: supportedContentTypes,
            delegate: ActionDropDelegate(types: supportedContentTypes, action: action),
            isTargeted: isTargeted
        ))
    }

    /// Defines the destination of a drag and drop operation using behavior
    /// controlled by the delegate.
    public func onDrop(of supportedContentTypes: [UTType], delegate: any DropDelegate) -> some View {
        modifier(_ItemProviderDropModifier(types: supportedContentTypes, delegate: delegate, isTargeted: nil))
    }
}
