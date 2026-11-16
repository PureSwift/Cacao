//
//  DragDrop.swift
//  Cacao
//
//  Created by Alsey Coleman Miller on 11/13/26.
//

import Foundation
#if canImport(CoreGraphics)
import CoreGraphics
#endif

#if canImport(CoreTransferable)
@_exported import CoreTransferable
@_exported import UniformTypeIdentifiers
#else

// Where there's no CoreTransferable, Cacao provides enough of it for
// conformances to compile. Within an app, dragged values move as values;
// from the system, drops arrive as file URLs and text.

/// A structure that represents a type of data to load, send, or receive.
public struct UTType: Hashable, Sendable, CustomStringConvertible {

    public let identifier: String

    public init?(_ identifier: String) {
        self.identifier = identifier
    }

    public init(exportedAs identifier: String, conformingTo parent: UTType? = nil) {
        self.identifier = identifier
    }

    public init(importedAs identifier: String, conformingTo parent: UTType? = nil) {
        self.identifier = identifier
    }

    public var description: String { identifier }

    public static let item = UTType(exportedAs: "public.item")
    public static let data = UTType(exportedAs: "public.data")
    public static let text = UTType(exportedAs: "public.text")
    public static let plainText = UTType(exportedAs: "public.plain-text")
    public static let utf8PlainText = UTType(exportedAs: "public.utf8-plain-text")
    public static let url = UTType(exportedAs: "public.url")
    public static let fileURL = UTType(exportedAs: "public.file-url")
    public static let json = UTType(exportedAs: "public.json")
    public static let image = UTType(exportedAs: "public.image")
    public static let png = UTType(exportedAs: "public.png")
    public static let jpeg = UTType(exportedAs: "public.jpeg")
    public static let pdf = UTType(exportedAs: "com.adobe.pdf")
}

/// A protocol that describes how a type interacts with transport APIs such
/// as drag and drop.
public protocol Transferable {

    associatedtype Representation: TransferRepresentation

    @TransferRepresentationBuilder<Self>
    static var transferRepresentation: Representation { get }
}

/// A declarative description of the process of importing and exporting a
/// transferable item.
public protocol TransferRepresentation<Item> {

    associatedtype Item: Transferable
}

/// Representations combined by a builder.
public struct _TransferRepresentations<Item: Transferable>: TransferRepresentation { }

/// Creates a transfer representation by composing existing transfer
/// representations.
@resultBuilder
public enum TransferRepresentationBuilder<Item: Transferable> {

    public static func buildExpression<R: TransferRepresentation>(_ representation: R) -> _TransferRepresentations<Item> where R.Item == Item {
        _TransferRepresentations()
    }

    public static func buildBlock(_ components: _TransferRepresentations<Item>...) -> _TransferRepresentations<Item> {
        _TransferRepresentations()
    }

    public static func buildOptional(_ component: _TransferRepresentations<Item>?) -> _TransferRepresentations<Item> {
        _TransferRepresentations()
    }

    public static func buildEither(first component: _TransferRepresentations<Item>) -> _TransferRepresentations<Item> {
        component
    }

    public static func buildEither(second component: _TransferRepresentations<Item>) -> _TransferRepresentations<Item> {
        component
    }
}

/// A transfer representation for types that participate in Swift's
/// protocols for encoding and decoding.
public struct CodableRepresentation<Item: Transferable & Codable>: TransferRepresentation {

    public init(for itemType: Item.Type = Item.self, contentType: UTType) { }

    public init(for itemType: Item.Type = Item.self, contentType: UTType, encoder: JSONEncoder, decoder: JSONDecoder) { }
}

/// A transfer representation for types that provide their own binary data
/// conversion.
public struct DataRepresentation<Item: Transferable>: TransferRepresentation {

    public init(contentType: UTType, exporting: @escaping @Sendable (Item) async throws -> Data, importing: @escaping @Sendable (Data) async throws -> Item) { }

    public init(exportedContentType: UTType, exporting: @escaping @Sendable (Item) async throws -> Data) { }

    public init(importedContentType: UTType, importing: @escaping @Sendable (Data) async throws -> Item) { }
}

/// A transfer representation that uses another type's transfer
/// representation as its own.
public struct ProxyRepresentation<Item: Transferable, ProxyRepresentation: Transferable>: TransferRepresentation {

    public init(exporting: @escaping @Sendable (Item) throws -> ProxyRepresentation) { }

    public init(exporting: @escaping @Sendable (Item) throws -> ProxyRepresentation, importing: @escaping @Sendable (ProxyRepresentation) throws -> Item) { }

    public init(importing: @escaping @Sendable (ProxyRepresentation) throws -> Item) { }
}

/// A file that a transfer moves.
public struct SentTransferredFile: Sendable {

    public let file: URL

    public init(_ file: URL, allowAccessingOriginalFile: Bool = false) {
        self.file = file
    }
}

/// A file that a transfer received.
public struct ReceivedTransferredFile: Sendable {

    public let file: URL

    public let isOriginalFile: Bool
}

/// A transfer representation for types that transfer as a file URL.
public struct FileRepresentation<Item: Transferable>: TransferRepresentation {

    public init(contentType: UTType, exporting: @escaping @Sendable (Item) async throws -> SentTransferredFile, importing: @escaping @Sendable (ReceivedTransferredFile) async throws -> Item) { }

    public init(exportedContentType: UTType, exporting: @escaping @Sendable (Item) async throws -> SentTransferredFile) { }

    public init(importedContentType: UTType, importing: @escaping @Sendable (ReceivedTransferredFile) async throws -> Item) { }
}

/// The built-in representation of standard types.
public struct _BuiltinRepresentation<Item: Transferable>: TransferRepresentation { }

extension String: Transferable {
    public static var transferRepresentation: _TransferRepresentations<String> { _BuiltinRepresentation() }
}

extension URL: Transferable {
    public static var transferRepresentation: _TransferRepresentations<URL> { _BuiltinRepresentation() }
}

extension Data: Transferable {
    public static var transferRepresentation: _TransferRepresentations<Data> { _BuiltinRepresentation() }
}

#endif

// MARK: - Drop targets

/// A view that takes drops: what it accepts and what it does with them.
@MainActor
internal struct DropTarget {

    /// Whether the target takes an item.
    let accepts: (Any) -> Bool

    /// Performs a drop of the items it accepts, at a point in the view's
    /// coordinate space, returning whether it took them.
    let perform: ([Any], CGPoint) -> Bool

    /// Called when a drag enters or leaves the view.
    let targeted: (Bool) -> Void

    /// Called as a drag over the target moves, with its location in the
    /// target's frame.
    var updated: ((CGPoint) -> Void)? = nil
}

/// Converts a dragged item to a type the destination asks for: as itself,
/// or between file URLs and text.
internal func convertDropItem<T>(_ item: Any, to type: T.Type) -> T? {
    if let value = item as? T {
        return value
    }
    if let url = item as? URL {
        if T.self == String.self {
            return (url.isFileURL ? url.path : url.absoluteString) as? T
        }
        if T.self == Data.self, url.isFileURL {
            return (try? Data(contentsOf: url)) as? T
        }
    }
    if let string = item as? String {
        if T.self == URL.self {
            return (string.hasPrefix("/") ? URL(fileURLWithPath: string) : URL(string: string)) as? T
        }
        if T.self == Data.self {
            return Data(string.utf8) as? T
        }
    }
    return nil
}

// MARK: - Drag session

/// A drag in progress: what's dragged, where, and over which target.
@MainActor
internal final class DragSession {

    /// The dragged values.
    let items: [Any]

    /// The dragged view's drawing, following the pointer, for drags within
    /// the window.
    let preview: [DisplayList.Item]

    /// Where the drag started, in the window.
    let start: CGPoint

    var location: CGPoint

    /// The node under the pointer that takes the items.
    weak var target: ViewNode?

    init(items: [Any], preview: [DisplayList.Item], start: CGPoint) {
        self.items = items
        self.preview = preview
        self.start = start
        self.location = start
    }
}

/// How a drag from the system goes.
package enum DropPhase: Sendable {
    /// The drag moved over the window.
    case moved
    /// The items were dropped.
    case dropped
    /// The drag left the window or was cancelled.
    case cancelled
}

extension ViewGraph {

    /// The front-most view at a point that takes all of the items.
    func dropTarget(at point: CGPoint, items: [Any]) -> ViewNode? {
        guard let path = root.hitTest(point) else { return nil }
        for node in path.reversed() {
            // Before a system drop, the items aren't known yet.
            if let target = node.attributes.dropTarget, items.isEmpty || items.contains(where: target.accepts) {
                return node
            }
        }
        return nil
    }

    /// Moves the drag to a point, telling targets it enters and leaves.
    func moveDrag(_ session: DragSession, to point: CGPoint) {
        session.location = point
        let target = dropTarget(at: point, items: session.items)
        if target !== session.target {
            session.target?.attributes.dropTarget?.targeted(false)
            session.target = target
            target?.attributes.dropTarget?.targeted(true)
        }
        if let target, let updated = target.attributes.dropTarget?.updated {
            let frame = target.windowFrame
            updated(CGPoint(x: point.x - frame.minX, y: point.y - frame.minY))
        }
        setNeedsDisplay()
    }

    /// Ends the drag, dropping its items on the target under the pointer,
    /// and returns whether the target took them.
    @discardableResult
    func endDrag(_ session: DragSession, at point: CGPoint, drops: Bool) -> Bool {
        moveDrag(session, to: point)
        var accepted = false
        if drops, let node = session.target, let target = node.attributes.dropTarget {
            let frame = node.windowFrame
            let local = CGPoint(x: point.x - frame.minX, y: point.y - frame.minY)
            accepted = target.perform(session.items.filter(target.accepts), local)
        }
        session.target?.attributes.dropTarget?.targeted(false)
        session.target = nil
        if dragSession === session {
            dragSession = nil
        }
        setNeedsDisplay()
        return accepted
    }

    /// A drag from the system, like files from a file manager: moves over
    /// the window, then drops or leaves. Returns whether a view took the
    /// items, when they're dropped.
    @discardableResult
    package func systemDrop(_ phase: DropPhase, items: [Any], at point: CGPoint) -> Bool {
        let session: DragSession
        if let current = systemDragSession {
            session = current
        } else {
            session = DragSession(items: items, preview: [], start: point)
            systemDragSession = session
        }
        switch phase {
        case .moved:
            moveDrag(session, to: point)
            return false
        case .dropped:
            systemDragSession = nil
            let dropped = DragSession(items: items.isEmpty ? session.items : items, preview: [], start: point)
            dropped.target = session.target
            return endDrag(dropped, at: point, drops: true)
        case .cancelled:
            systemDragSession = nil
            endDrag(session, at: point, drops: false)
            return false
        }
    }

    /// The dragged view's drawing at the pointer, over the window's content.
    func dragPreviewItems() -> [DisplayList.Item] {
        guard let session = dragSession, !session.preview.isEmpty else { return [] }
        let dx = session.location.x - session.start.x, dy = session.location.y - session.start.y
        let identity = Int.min / 2
        let bounds = session.preview.map(\.frame).reduce(CGRect.null) { $0.union($1) }
        return [DisplayList.Item(
            frame: bounds,
            identity: identity,
            version: 0,
            value: .effect(.transform(.translation(dx, dy)), DisplayList(items: [DisplayList.Item(
                frame: bounds,
                identity: identity + 1,
                version: 0,
                value: .effect(.opacity(0.75), DisplayList(items: session.preview))
            )]))
        )]
    }
}

// MARK: - Modifiers

internal struct _DraggableModifier: ViewModifier, PrimitiveViewModifier {

    let payload: () -> Any

    func resolve(content: any View, in context: ResolveContext) -> Resolution {
        weak let node = context.node
        let payload = self.payload
        let gesture = DragGesture(minimumDistance: 4, coordinateSpace: .global)
            .onChanged { value in
                guard let node else { return }
                let graph = node.graph
                if graph.dragSession == nil {
                    graph.dragSession = DragSession(items: [payload()], preview: node.displayItems(), start: value.startLocation)
                }
                if let session = graph.dragSession {
                    graph.moveDrag(session, to: value.location)
                }
            }
            .onEnded { value in
                guard let graph = node?.graph, let session = graph.dragSession else { return }
                graph.endDrag(session, at: value.location, drops: true)
            }
        return Resolution(children: [ChildView(key: 0, view: AnyView(content).gesture(gesture))])
    }

    typealias Body = Never
}

internal struct _DropDestinationModifier<T>: ViewModifier, PrimitiveViewModifier {

    let action: ([T], CGPoint) -> Bool

    let isTargeted: (Bool) -> Void

    func resolve(content: any View, in context: ResolveContext) -> Resolution {
        let action = self.action
        var attributes = NodeAttributes()
        attributes.dropTarget = DropTarget(
            accepts: { convertDropItem($0, to: T.self) != nil },
            perform: { items, location in
                let values = items.compactMap { convertDropItem($0, to: T.self) }
                return !values.isEmpty && action(values, location)
            },
            targeted: isTargeted
        )
        // The whole frame takes drops, as it does hits for gestures.
        attributes.contentShape = { Path($0) }
        return Resolution(children: [ChildView(key: 0, view: content)], attributes: attributes)
    }

    typealias Body = Never
}

extension View {

    /// Activates this view as the source of a drag and drop operation.
    public func draggable<T: Transferable>(_ payload: @autoclosure @escaping () -> T) -> some View {
        modifier(_DraggableModifier(payload: payload))
    }

    /// Activates this view as the source of a drag and drop operation; the
    /// window shows the view itself as it's dragged.
    public func draggable<V: View, T: Transferable>(_ payload: @autoclosure @escaping () -> T, @ViewBuilder preview: () -> V) -> some View {
        modifier(_DraggableModifier(payload: payload))
    }

    /// Defines the destination of a drag and drop operation that handles
    /// the dropped content with a closure that you specify.
    public func dropDestination<T: Transferable>(
        for payloadType: T.Type = T.self,
        action: @escaping (_ items: [T], _ location: CGPoint) -> Bool,
        isTargeted: @escaping (Bool) -> Void = { _ in }
    ) -> some View {
        modifier(_DropDestinationModifier(action: action, isTargeted: isTargeted))
    }
}
