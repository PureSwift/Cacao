//
//  Documents.swift
//  Cacao
//
//  Created by Alsey Coleman Miller on 11/15/26.
//

import Foundation
import Observation

#if !canImport(Darwin)
// Where Foundation has no file wrappers, Cacao provides them: a regular
// file's contents, or a directory of file wrappers.

/// A representation of a node (a file, directory, or symbolic link) in the
/// file system.
open class FileWrapper: NSObject, @unchecked Sendable {

    /// Options for reading a file wrapper.
    public struct ReadingOptions: OptionSet, Sendable {
        public let rawValue: UInt
        public init(rawValue: UInt) { self.rawValue = rawValue }
        public static let immediate = ReadingOptions(rawValue: 1 << 0)
        public static let withoutMapping = ReadingOptions(rawValue: 1 << 1)
    }

    /// Options for writing a file wrapper.
    public struct WritingOptions: OptionSet, Sendable {
        public let rawValue: UInt
        public init(rawValue: UInt) { self.rawValue = rawValue }
        public static let atomic = WritingOptions(rawValue: 1 << 0)
        public static let withNameUpdating = WritingOptions(rawValue: 1 << 1)
    }

    private var contents: Data?

    private var children: [String: FileWrapper]?

    /// The file name of the file wrapper, once written or read.
    open var filename: String?

    /// The preferred file name for the file wrapper.
    open var preferredFilename: String?

    /// Creates a regular-file file wrapper with the given contents.
    public init(regularFileWithContents contents: Data) {
        self.contents = contents
        super.init()
    }

    /// Creates a directory file wrapper that contains the given file wrappers.
    public init(directoryWithFileWrappers childrenByPreferredName: [String: FileWrapper]) {
        self.children = childrenByPreferredName
        super.init()
        for (name, child) in childrenByPreferredName where child.preferredFilename == nil {
            child.preferredFilename = name
        }
    }

    /// Creates a file wrapper for the file or directory at a URL.
    public init(url: URL, options: ReadingOptions = []) throws {
        var isDirectory: ObjCBool = false
        guard FileManager.default.fileExists(atPath: url.path, isDirectory: &isDirectory) else {
            throw CocoaError(.fileReadNoSuchFile, userInfo: [NSURLErrorKey: url])
        }
        if isDirectory.boolValue {
            var children: [String: FileWrapper] = [:]
            for name in try FileManager.default.contentsOfDirectory(atPath: url.path) {
                children[name] = try FileWrapper(url: url.appendingPathComponent(name), options: options)
            }
            self.children = children
        } else {
            self.contents = try Data(contentsOf: url)
        }
        super.init()
        filename = url.lastPathComponent
        preferredFilename = url.lastPathComponent
    }

    /// Whether the file wrapper is for a regular file.
    open var isRegularFile: Bool { contents != nil }

    /// Whether the file wrapper is for a directory.
    open var isDirectory: Bool { children != nil }

    /// The contents of a regular-file file wrapper.
    open var regularFileContents: Data? { contents }

    /// The file wrappers of a directory file wrapper, by file name.
    open var fileWrappers: [String: FileWrapper]? { children }

    /// Adds a file wrapper to a directory file wrapper, returning its name.
    @discardableResult
    open func addFileWrapper(_ child: FileWrapper) -> String {
        let name = child.preferredFilename ?? UUID().uuidString
        children?[name] = child
        return name
    }

    /// Writes the file wrapper's contents to a URL.
    open func write(to url: URL, options: WritingOptions = [], originalContentsURL: URL?) throws {
        if let contents {
            try contents.write(to: url, options: options.contains(.atomic) ? .atomic : [])
        } else if let children {
            try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
            for (name, child) in children {
                try child.write(to: url.appendingPathComponent(name), options: options, originalContentsURL: nil)
            }
        }
        if options.contains(.withNameUpdating) {
            filename = url.lastPathComponent
        }
    }
}

extension UTType {

    /// File name extensions of the types Cacao knows.
    private static let extensions: [String: String] = [
        "public.plain-text": "txt",
        "public.utf8-plain-text": "txt",
        "public.text": "txt",
        "public.json": "json",
        "public.png": "png",
        "public.jpeg": "jpeg",
        "com.adobe.pdf": "pdf",
    ]

    /// The preferred file name extension of the type.
    public var preferredFilenameExtension: String? {
        Self.extensions[identifier] ?? UTType.declaredExtensions[identifier]
    }

    /// The type of files with a file name extension, if Cacao knows one.
    public init?(filenameExtension: String) {
        let name = filenameExtension.lowercased()
        let builtin = ["txt": "public.plain-text", "text": "public.plain-text", "json": "public.json", "png": "public.png",
                       "jpg": "public.jpeg", "jpeg": "public.jpeg", "pdf": "com.adobe.pdf"]
        if let identifier = builtin[name] ?? UTType.declaredExtensions.first(where: { $0.value == name })?.key {
            self.init(identifier)
        } else {
            return nil
        }
    }

    /// Whether the type is another, or conforms to it.
    public func conforms(to type: UTType) -> Bool {
        UTType.identifier(identifier, conformsTo: type.identifier)
    }

    /// Extensions declared for app types with `declareFilenameExtension`.
    nonisolated(unsafe) private static var declaredExtensions: [String: String] = [:]

    /// Declares the file name extension of a type the app exports or
    /// imports, as an app's Info.plist does on Apple platforms.
    public static func declareFilenameExtension(_ filenameExtension: String, for type: UTType) {
        declaredExtensions[type.identifier] = filenameExtension.lowercased()
    }
}
#endif

// MARK: - FileDocument

/// The configuration for reading file contents.
public struct FileDocumentReadConfiguration {

    /// The expected uniform type of the file contents.
    public let contentType: UTType

    /// The file wrapper containing the document content.
    public let file: FileWrapper
}

/// The configuration for serializing file contents.
public struct FileDocumentWriteConfiguration {

    /// The expected uniform type of the file contents.
    public let contentType: UTType

    /// The file wrapper containing the current document content, if any.
    public let existingFile: FileWrapper?
}

/// A type that you use to serialize documents to and from file.
@preconcurrency
public protocol FileDocument {

    /// The file and data types that the document reads from.
    static var readableContentTypes: [UTType] { get }

    /// The file types that the document supports saving or exporting to.
    static var writableContentTypes: [UTType] { get }

    typealias ReadConfiguration = FileDocumentReadConfiguration

    typealias WriteConfiguration = FileDocumentWriteConfiguration

    /// Creates a document and initializes it with the contents of a file.
    init(configuration: ReadConfiguration) throws

    /// Serializes a document snapshot to a file wrapper.
    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper
}

extension FileDocument {

    public static var writableContentTypes: [UTType] { readableContentTypes }
}

/// A type that you use to serialize reference type documents to and from
/// file.
@preconcurrency
public protocol ReferenceFileDocument: ObservableObject {

    /// A type that represents the document's stored content.
    associatedtype Snapshot

    static var readableContentTypes: [UTType] { get }

    static var writableContentTypes: [UTType] { get }

    typealias ReadConfiguration = FileDocumentReadConfiguration

    typealias WriteConfiguration = FileDocumentWriteConfiguration

    init(configuration: ReadConfiguration) throws

    /// Creates a snapshot that represents the current state of the document.
    func snapshot(contentType: UTType) throws -> Snapshot

    /// Serializes a document snapshot to a file wrapper.
    func fileWrapper(snapshot: Snapshot, configuration: WriteConfiguration) throws -> FileWrapper
}

extension ReferenceFileDocument {

    public static var writableContentTypes: [UTType] { readableContentTypes }
}

/// The properties of an open file document.
public struct FileDocumentConfiguration<Document: FileDocument> {

    /// The current document model.
    @Binding public var document: Document

    /// The URL of the open file document, or `nil` if it's never been saved.
    public var fileURL: URL?

    /// Whether you can edit the document.
    public var isEditable: Bool
}

/// The properties of an open reference file document.
public struct ReferenceFileDocumentConfiguration<Document: ReferenceFileDocument> {

    /// The current document model.
    @ObservedObject public var document: Document

    /// The URL of the open file document, or `nil` if it's never been saved.
    public var fileURL: URL?

    /// Whether you can edit the document.
    public var isEditable: Bool
}

// MARK: - File dialogs

/// The file dialogs a host shows.
package struct FileDialogs {

    /// Asks for files to open of the types, calling back with none if
    /// cancelled.
    package var open: (_ types: [UTType], _ allowsMultiple: Bool, _ completion: @escaping @MainActor ([URL]) -> Void) -> Void

    /// Asks where to save a file of the types, calling back with `nil` if
    /// cancelled.
    package var save: (_ defaultName: String, _ types: [UTType], _ completion: @escaping @MainActor (URL?) -> Void) -> Void

    package init(
        open: @escaping (_ types: [UTType], _ allowsMultiple: Bool, _ completion: @escaping @MainActor ([URL]) -> Void) -> Void,
        save: @escaping (_ defaultName: String, _ types: [UTType], _ completion: @escaping @MainActor (URL?) -> Void) -> Void
    ) {
        self.open = open
        self.save = save
    }
}

/// A file type's name extension, for the host's dialog filters.
package func filenameExtension(of type: UTType) -> String? {
    type.preferredFilenameExtension
}

/// The type of a file at a URL among `types`: the first it conforms to by
/// its extension, or the first of them.
internal func contentType(of url: URL, among types: [UTType]) -> UTType? {
    if let type = UTType(filenameExtension: url.pathExtension), let match = types.first(where: { type.conforms(to: $0) }) {
        return match
    }
    return types.first
}

// MARK: - Document windows

/// What a document window can do, for its commands and the host.
@MainActor
internal final class DocumentController {

    var fileURL: URL?

    var isEdited = false {
        didSet { if isEdited != oldValue { titleChanged() } }
    }

    let isEditable: Bool

    let writableTypes: [UTType]

    /// Writes the document to a URL as a type.
    var write: (_ url: URL, _ type: UTType) throws -> Void = { _, _ in }

    /// Called when the file URL changes, to update the view.
    var fileURLChanged: () -> Void = { }

    /// The last error reading or writing the document.
    var error: (any Error)?

    weak var graph: ViewGraph?

    init(fileURL: URL?, isEditable: Bool, writableTypes: [UTType]) {
        self.fileURL = fileURL
        self.isEditable = isEditable
        self.writableTypes = writableTypes
    }

    /// The window's title: the file's name, or Untitled, and whether it's
    /// edited.
    var title: String {
        let name = fileURL?.deletingPathExtension().lastPathComponent ?? "Untitled"
        return isEdited ? name + " — Edited" : name
    }

    func titleChanged() {
        graph?.windowTitle = title
    }

    /// Saves to the document's file, or asks where if it has none.
    func save() {
        guard isEditable else { return }
        guard let fileURL else {
            saveAs()
            return
        }
        write(to: fileURL)
    }

    /// Asks where to save, then saves there.
    func saveAs() {
        guard isEditable, let dialogs = graph?.fileDialogs else { return }
        let name = fileURL?.lastPathComponent ?? "Untitled"
        dialogs.save(name, writableTypes) { [weak self] url in
            guard let self, var url else { return }
            if url.pathExtension.isEmpty, let ext = self.writableTypes.first.flatMap(filenameExtension(of:)) {
                url.appendPathExtension(ext)
            }
            self.write(to: url)
        }
    }

    private func write(to url: URL) {
        let type = contentType(of: url, among: writableTypes) ?? writableTypes.first
        guard let type else { return }
        do {
            try write(url, type)
            error = nil
            let moved = url != fileURL
            fileURL = url
            isEdited = false
            titleChanged()
            if moved { fileURLChanged() }
        } catch {
            self.error = error
        }
    }
}

/// The state of a document window: the document, loaded once.
@MainActor
@Observable
internal final class _DocumentState<Document> {

    var document: Document?

    var fileURL: URL?

    var error: (any Error)?

    @ObservationIgnored
    var controller: DocumentController?

    @ObservationIgnored
    var subscription: AnyObject?

    init() { }
}

/// Registers a document window's controller with its graph.
private struct _DocumentWindowRegistration: View, PrimitiveView {

    let controller: DocumentController

    let content: AnyView

    func resolve(in context: ResolveContext) -> Resolution {
        let graph = context.graph
        if graph.documentController !== controller {
            graph.documentController = controller
            controller.graph = graph
            graph.windowTitle = controller.title
        }
        return Resolution(children: [ChildView(key: 0, view: content)])
    }

    typealias Body = Never
}

/// A window showing a value type document: new, or read from a file.
internal struct _FileDocumentWindow<Document: FileDocument, Content: View>: View {

    let url: URL?

    let newDocument: () -> Document

    let isEditable: Bool

    let editor: (FileDocumentConfiguration<Document>) -> Content

    @State private var state = _DocumentState<Document>()

    var body: some View {
        let state = self.state
        if state.controller == nil {
            load(state)
        }
        return _DocumentWindowRegistration(controller: state.controller!, content: AnyView(Group {
            if state.document != nil {
                editor(FileDocumentConfiguration(
                    document: Binding(
                        get: { state.document! },
                        set: { value in
                            state.document = value
                            state.controller?.isEdited = true
                        }
                    ),
                    fileURL: state.fileURL,
                    isEditable: isEditable
                ))
            } else {
                _DocumentErrorView(url: url, error: state.error)
            }
        }))
    }

    private func load(_ state: _DocumentState<Document>) {
        let controller = DocumentController(fileURL: url, isEditable: isEditable, writableTypes: Document.writableContentTypes)
        state.controller = controller
        state.fileURL = url
        if let url {
            do {
                let wrapper = try FileWrapper(url: url, options: .immediate)
                let type = contentType(of: url, among: Document.readableContentTypes) ?? .data
                state.document = try Document(configuration: FileDocumentReadConfiguration(contentType: type, file: wrapper))
            } catch {
                state.error = error
            }
        } else {
            state.document = newDocument()
        }
        controller.write = { [weak state] url, type in
            guard let document = state?.document else { return }
            let existing = try? FileWrapper(url: url, options: .immediate)
            let wrapper = try document.fileWrapper(configuration: FileDocumentWriteConfiguration(contentType: type, existingFile: existing))
            try wrapper.write(to: url, options: .atomic, originalContentsURL: existing == nil ? nil : url)
        }
        controller.fileURLChanged = { [weak state, weak controller] in
            state?.fileURL = controller?.fileURL
        }
    }
}

/// A window showing a reference type document: new, or read from a file.
internal struct _ReferenceDocumentWindow<Document: ReferenceFileDocument, Content: View>: View {

    let url: URL?

    let newDocument: () -> Document

    let isEditable: Bool

    let editor: (ReferenceFileDocumentConfiguration<Document>) -> Content

    @State private var state = _DocumentState<Document>()

    var body: some View {
        let state = self.state
        if state.controller == nil {
            load(state)
        }
        return _DocumentWindowRegistration(controller: state.controller!, content: AnyView(Group {
            if let document = state.document {
                editor(ReferenceFileDocumentConfiguration(document: document, fileURL: state.fileURL, isEditable: isEditable))
            } else {
                _DocumentErrorView(url: url, error: state.error)
            }
        }))
    }

    private func load(_ state: _DocumentState<Document>) {
        let controller = DocumentController(fileURL: url, isEditable: isEditable, writableTypes: Document.writableContentTypes)
        state.controller = controller
        state.fileURL = url
        if let url {
            do {
                let wrapper = try FileWrapper(url: url, options: .immediate)
                let type = contentType(of: url, among: Document.readableContentTypes) ?? .data
                state.document = try Document(configuration: FileDocumentReadConfiguration(contentType: type, file: wrapper))
            } catch {
                state.error = error
            }
        } else {
            state.document = newDocument()
        }
        // A change to the document's published properties edits it.
        if let document = state.document {
            state.subscription = subscribe(document) { [weak controller] in
                MainActor.assumeIsolated {
                    controller?.isEdited = true
                }
            }
        }
        controller.write = { [weak state] url, type in
            guard let document = state?.document else { return }
            let existing = try? FileWrapper(url: url, options: .immediate)
            let snapshot = try document.snapshot(contentType: type)
            let wrapper = try document.fileWrapper(snapshot: snapshot, configuration: FileDocumentWriteConfiguration(contentType: type, existingFile: existing))
            try wrapper.write(to: url, options: .atomic, originalContentsURL: existing == nil ? nil : url)
        }
        controller.fileURLChanged = { [weak state, weak controller] in
            state?.fileURL = controller?.fileURL
        }
    }
}

/// What a document window shows when its file couldn't be read.
private struct _DocumentErrorView: View {

    let url: URL?

    let error: (any Error)?

    var body: some View {
        VStack(spacing: 8) {
            Text("The document “\(url?.lastPathComponent ?? "Untitled")” could not be opened.")
                .font(.headline)
            if let error {
                Text(String(describing: error))
                    .foregroundStyle(.secondary)
            }
        }
        .padding()
    }
}

// MARK: - DocumentGroup

/// A scene that enables support for opening, creating, and saving
/// documents.
///
/// Its windows show one document each: a new one at launch and from
/// File > New, or one opened from File > Open. File > Save writes the
/// document, asking where the first time, and the window's title shows its
/// file's name and whether it's edited.
public struct DocumentGroup<Document, Content: View>: Scene, PrimitiveScene {

    internal let id: String

    internal let readableTypes: [UTType]

    internal let isEditable: Bool

    internal let makeWindow: (URL?) -> AnyView

    public typealias Body = Never

    public var body: Never {
        fatalError("DocumentGroup is a primitive scene")
    }

    func windows(modifiers: SceneModifiers) -> [WindowDescription] {
        let id = self.id
        collectedCommands.append(CommandMenuContent(
            name: "File",
            content: AnyView(_DocumentCommands(sceneID: id, readableTypes: readableTypes, isEditable: isEditable))
        ))
        let makeWindow = self.makeWindow
        return [WindowDescription(
            title: "Untitled",
            id: id,
            defaultSize: modifiers.defaultSize,
            rootView: makeWindow(nil),
            makeRootView: { value in makeWindow(value?.base as? URL) }
        )]
    }
}

extension DocumentGroup where Document: FileDocument {

    /// Creates a document group for creating and editing file documents.
    public init(
        newDocument: @autoclosure @escaping () -> Document,
        @ViewBuilder editor: @escaping (FileDocumentConfiguration<Document>) -> Content
    ) {
        self.id = "cacao.document.\(Document.self)"
        self.readableTypes = Document.readableContentTypes
        self.isEditable = true
        self.makeWindow = { url in
            AnyView(_FileDocumentWindow(url: url, newDocument: newDocument, isEditable: true, editor: editor))
        }
    }

    /// Creates a document group capable of viewing file documents.
    public init(
        viewing documentType: Document.Type,
        @ViewBuilder viewer: @escaping (FileDocumentConfiguration<Document>) -> Content
    ) {
        self.id = "cacao.document.\(Document.self)"
        self.readableTypes = Document.readableContentTypes
        self.isEditable = false
        self.makeWindow = { url in
            AnyView(_FileDocumentWindow(url: url, newDocument: { fatalError("A viewing document group has no new documents") }, isEditable: false, editor: viewer))
        }
    }
}

extension DocumentGroup where Document: ReferenceFileDocument {

    /// Creates a document group for creating and editing reference file
    /// documents.
    public init(
        newDocument: @escaping () -> Document,
        @ViewBuilder editor: @escaping (ReferenceFileDocumentConfiguration<Document>) -> Content
    ) {
        self.id = "cacao.document.\(Document.self)"
        self.readableTypes = Document.readableContentTypes
        self.isEditable = true
        self.makeWindow = { url in
            AnyView(_ReferenceDocumentWindow(url: url, newDocument: newDocument, isEditable: true, editor: editor))
        }
    }

    /// Creates a document group capable of viewing reference file documents.
    public init(
        viewing documentType: Document.Type,
        @ViewBuilder viewer: @escaping (ReferenceFileDocumentConfiguration<Document>) -> Content
    ) {
        self.id = "cacao.document.\(Document.self)"
        self.readableTypes = Document.readableContentTypes
        self.isEditable = false
        self.makeWindow = { url in
            AnyView(_ReferenceDocumentWindow(url: url, newDocument: { fatalError("A viewing document group has no new documents") }, isEditable: false, editor: viewer))
        }
    }
}

/// The File menu's document commands: New, Open, Save and Save As.
private struct _DocumentCommands: View {

    let sceneID: String

    let readableTypes: [UTType]

    let isEditable: Bool

    @Environment(\.openWindow) private var openWindow

    var body: some View {
        let openWindow = self.openWindow
        let sceneID = self.sceneID
        if isEditable {
            Button("New") { openWindow.handler(sceneID, nil) }
                .keyboardShortcut("n", modifiers: .command)
        }
        _GraphButton("Open…") { graph in
            graph.fileDialogs?.open(readableTypes, true) { urls in
                for url in urls {
                    openWindow.handler(sceneID, AnyHashable(url))
                }
            }
        }
        .keyboardShortcut("o", modifiers: .command)
        if isEditable {
            _GraphButton("Save") { $0.documentController?.save() }
                .keyboardShortcut("s", modifiers: .command)
            _GraphButton("Save As…") { $0.documentController?.saveAs() }
                .keyboardShortcut("s", modifiers: [.command, .shift])
        }
    }
}

/// A button whose action uses its window's graph.
private struct _GraphButton: View, PrimitiveView {

    let title: String

    let action: @MainActor (ViewGraph) -> Void

    init(_ title: String, action: @escaping @MainActor (ViewGraph) -> Void) {
        self.title = title
        self.action = action
    }

    func resolve(in context: ResolveContext) -> Resolution {
        weak let graph = context.graph
        let action = self.action
        return Resolution(children: [ChildView(key: 0, view: Button(title) {
            if let graph { action(graph) }
        })])
    }

    typealias Body = Never
}

// MARK: - File importer and exporter

/// Presents the host's open dialog while a binding is true.
private struct _FileImporterModifier: ViewModifier, PrimitiveViewModifier {

    let isPresented: Binding<Bool>

    let types: [UTType]

    let allowsMultiple: Bool

    let completion: ([URL]) -> Void

    func resolve(content: any View, in context: ResolveContext) -> Resolution {
        if isPresented.wrappedValue, context.node.dynamicStorage["presenting"] == nil, let dialogs = context.graph.fileDialogs {
            weak let node = context.node
            node?.dynamicStorage["presenting"] = NSNull()
            let isPresented = self.isPresented, completion = self.completion
            dialogs.open(types, allowsMultiple) { urls in
                node?.dynamicStorage["presenting"] = nil
                isPresented.wrappedValue = false
                if !urls.isEmpty {
                    completion(urls)
                }
            }
        }
        return Resolution(children: [ChildView(key: 0, view: content)])
    }

    typealias Body = Never
}

/// Presents the host's save dialog while a binding is true, then writes the
/// document.
private struct _FileExporterModifier: ViewModifier, PrimitiveViewModifier {

    let isPresented: Binding<Bool>

    let defaultFilename: String

    let types: [UTType]

    let write: (URL, UTType) throws -> Void

    let completion: (Result<URL, any Error>) -> Void

    func resolve(content: any View, in context: ResolveContext) -> Resolution {
        if isPresented.wrappedValue, context.node.dynamicStorage["presenting"] == nil, let dialogs = context.graph.fileDialogs {
            weak let node = context.node
            node?.dynamicStorage["presenting"] = NSNull()
            let isPresented = self.isPresented, completion = self.completion, write = self.write, types = self.types
            dialogs.save(defaultFilename, types) { url in
                node?.dynamicStorage["presenting"] = nil
                isPresented.wrappedValue = false
                guard var url else { return }
                if url.pathExtension.isEmpty, let ext = types.first.flatMap(filenameExtension(of:)) {
                    url.appendPathExtension(ext)
                }
                do {
                    try write(url, contentType(of: url, among: types) ?? types[0])
                    completion(.success(url))
                } catch {
                    completion(.failure(error))
                }
            }
        }
        return Resolution(children: [ChildView(key: 0, view: content)])
    }

    typealias Body = Never
}

extension View {

    /// Presents a system interface for allowing the user to import an
    /// existing file.
    public func fileImporter(
        isPresented: Binding<Bool>,
        allowedContentTypes: [UTType],
        onCompletion: @escaping (_ result: Result<URL, any Error>) -> Void
    ) -> some View {
        modifier(_FileImporterModifier(isPresented: isPresented, types: allowedContentTypes, allowsMultiple: false) { urls in
            onCompletion(.success(urls[0]))
        })
    }

    /// Presents a system interface for allowing the user to import multiple
    /// files.
    public func fileImporter(
        isPresented: Binding<Bool>,
        allowedContentTypes: [UTType],
        allowsMultipleSelection: Bool,
        onCompletion: @escaping (_ result: Result<[URL], any Error>) -> Void
    ) -> some View {
        modifier(_FileImporterModifier(isPresented: isPresented, types: allowedContentTypes, allowsMultiple: allowsMultipleSelection) { urls in
            onCompletion(.success(urls))
        })
    }

    /// Presents a system interface for exporting a document that's stored
    /// in a value type, like a structure, to a file on disk.
    public func fileExporter<D: FileDocument>(
        isPresented: Binding<Bool>,
        document: D?,
        contentType: UTType,
        defaultFilename: String? = nil,
        onCompletion: @escaping (_ result: Result<URL, any Error>) -> Void
    ) -> some View {
        modifier(_FileExporterModifier(
            isPresented: isPresented,
            defaultFilename: defaultFilename ?? "Untitled",
            types: [contentType],
            write: { url, type in
                guard let document else { throw CocoaError(.fileWriteUnknown) }
                try document.fileWrapper(configuration: FileDocumentWriteConfiguration(contentType: type, existingFile: nil))
                    .write(to: url, options: .atomic, originalContentsURL: nil)
            },
            completion: onCompletion
        ))
    }
}
