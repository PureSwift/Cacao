import CacaoRender
import Foundation
#if canImport(CoreGraphics)
import CoreGraphics
#endif
import Testing
@testable import Cacao

struct NoteDocument: FileDocument {

    static var readableContentTypes: [UTType] { [.plainText] }

    var text: String

    init(text: String = "") {
        self.text = text
    }

    init(configuration: ReadConfiguration) throws {
        text = String(data: configuration.file.regularFileContents ?? Data(), encoding: .utf8) ?? ""
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: Data(text.utf8))
    }
}

final class CounterDocument: ReferenceFileDocument {

    static var readableContentTypes: [UTType] { [.plainText] }

    @Published var count: Int

    init(count: Int = 0) {
        self.count = count
    }

    init(configuration: ReadConfiguration) throws {
        count = Int(String(data: configuration.file.regularFileContents ?? Data(), encoding: .utf8) ?? "") ?? 0
    }

    func snapshot(contentType: UTType) throws -> Int {
        count
    }

    func fileWrapper(snapshot: Int, configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: Data("\(snapshot)".utf8))
    }
}

struct NoteEditor: View {
    @Binding var document: NoteDocument
    let fileURL: URL?
    var body: some View {
        VStack {
            Text(document.text)
            Text(fileURL?.lastPathComponent ?? "unsaved")
            Button("Append") { document.text += "!" }
        }
    }
}

struct CounterEditor: View {
    @ObservedObject var document: CounterDocument
    var body: some View {
        VStack {
            Text("Count \(document.count)")
            Button("Increment") { document.count += 1 }
        }
    }
}

struct NotesApp: App {
    var body: some Scene {
        DocumentGroup(newDocument: NoteDocument(text: "Hello")) { configuration in
            NoteEditor(document: configuration.$document, fileURL: configuration.fileURL)
        }
    }
}

struct CounterApp: App {
    var body: some Scene {
        DocumentGroup(newDocument: { CounterDocument() }) { configuration in
            CounterEditor(document: configuration.document)
        }
    }
}

/// File dialogs that answer when a test says.
@MainActor
final class FakeDialogs {
    var opens: [(types: [UTType], complete: ([URL]) -> Void)] = []
    var saves: [(name: String, complete: (URL?) -> Void)] = []

    var dialogs: FileDialogs {
        FileDialogs(
            open: { types, _, completion in self.opens.append((types, completion)) },
            save: { name, _, completion in self.saves.append((name, completion)) }
        )
    }
}

@MainActor
@Suite struct DocumentTests {

    let directory: URL = {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("CacaoDocuments-\(UUID().uuidString)")
        try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }()

    #if os(macOS)
    let command: KeyModifiers = .command
    #else
    let command: KeyModifiers = .control
    #endif

    @Test func newDocumentEditsAndSaves() throws {
        let window = NotesApp().body.windowDescriptions()[0]
        let graph = ViewGraph(rootView: window.rootView)
        let fake = FakeDialogs()
        graph.fileDialogs = fake.dialogs
        graph.layout(in: CGSize(width: 400, height: 300))
        #expect(graph.windowTitle == "Untitled")
        #expect(graph.texts.contains("Hello"))
        #expect(graph.commandMenus().first { $0.name == "File" }?.items.map(\.title) == ["New", "Open…", "Save", "Save As…"])

        graph.tapText("Append")
        graph.settle()
        #expect(graph.texts.contains("Hello!"))
        #expect(graph.windowTitle == "Untitled — Edited")

        // Saving a new document asks where, adding the type's extension.
        graph.keyDown(.character("s"), modifiers: command)
        #expect(fake.saves.map(\.name) == ["Untitled"])
        fake.saves[0].complete(directory.appendingPathComponent("Notes"))
        graph.settle()
        let file = directory.appendingPathComponent("Notes.txt")
        #expect(try String(contentsOf: file, encoding: .utf8) == "Hello!")
        #expect(graph.windowTitle == "Notes")
        #expect(graph.texts.contains("Notes.txt"))

        // Saving again writes to the same file without asking.
        graph.tapText("Append")
        graph.settle()
        graph.keyDown(.character("s"), modifiers: command)
        graph.settle()
        #expect(fake.saves.count == 1)
        #expect(try String(contentsOf: file, encoding: .utf8) == "Hello!!")
        #expect(graph.windowTitle == "Notes")
    }

    @Test func openingShowsTheFilesDocument() throws {
        let file = directory.appendingPathComponent("Letter.txt")
        try Data("Dear reader".utf8).write(to: file)
        let window = NotesApp().body.windowDescriptions()[0]

        // File > Open asks for files, then opens a window for each.
        var opened: [AnyHashable?] = []
        let graph = ViewGraph(rootView: window.rootView.environment(\.openWindow, OpenWindowAction { _, value in
            opened.append(value)
        }))
        let fake = FakeDialogs()
        graph.fileDialogs = fake.dialogs
        graph.layout(in: CGSize(width: 400, height: 300))
        graph.keyDown(.character("o"), modifiers: command)
        #expect(fake.opens.first?.types == [.plainText])
        fake.opens[0].complete([file])
        #expect(opened == [AnyHashable(file)])

        let document = ViewGraph(rootView: window.makeRootView!(AnyHashable(file)))
        document.layout(in: CGSize(width: 400, height: 300))
        #expect(document.texts.contains("Dear reader"))
        #expect(document.texts.contains("Letter.txt"))
        #expect(document.windowTitle == "Letter")
    }

    @Test func unreadableFilesShowAnError() {
        let window = NotesApp().body.windowDescriptions()[0]
        let graph = ViewGraph(rootView: window.makeRootView!(AnyHashable(directory.appendingPathComponent("Missing.txt"))))
        graph.layout(in: CGSize(width: 400, height: 300))
        #expect(graph.texts.contains("The document “Missing.txt” could not be opened."))
    }

    @Test func referenceDocumentsSaveSnapshots() throws {
        let window = CounterApp().body.windowDescriptions()[0]
        let graph = ViewGraph(rootView: window.rootView)
        let fake = FakeDialogs()
        graph.fileDialogs = fake.dialogs
        graph.layout(in: CGSize(width: 400, height: 300))
        graph.tapText("Increment")
        graph.settle()
        #expect(graph.texts.contains("Count 1"))
        #expect(graph.windowTitle == "Untitled — Edited")
        graph.keyDown(.character("s"), modifiers: [command, .shift])
        fake.saves[0].complete(directory.appendingPathComponent("Count.txt"))
        graph.settle()
        #expect(try String(contentsOf: directory.appendingPathComponent("Count.txt"), encoding: .utf8) == "1")
        #expect(graph.windowTitle == "Count")
    }

    @Test func fileImporterAndExporter() throws {
        struct Files: View {
            let log: Box<[String]>
            @State private var importing = false
            @State private var exporting = false
            var body: some View {
                VStack {
                    Button("Import") { importing = true }
                    Button("Export") { exporting = true }
                }
                .fileImporter(isPresented: $importing, allowedContentTypes: [.plainText]) { result in
                    log.value.append((try? result.get().lastPathComponent) ?? "failed")
                }
                .fileExporter(isPresented: $exporting, document: NoteDocument(text: "Exported"), contentType: .plainText, defaultFilename: "Out") { result in
                    log.value.append((try? result.get().lastPathComponent) ?? "failed")
                }
            }
        }
        let log = Box<[String]>([])
        let graph = ViewGraph(rootView: Files(log: log))
        let fake = FakeDialogs()
        graph.fileDialogs = fake.dialogs
        graph.layout(in: CGSize(width: 400, height: 300))
        graph.tapText("Import")
        graph.settle()
        #expect(fake.opens.count == 1)
        fake.opens[0].complete([directory.appendingPathComponent("In.txt")])
        graph.settle()
        #expect(log.value == ["In.txt"])

        graph.tapText("Export")
        graph.settle()
        #expect(fake.saves.map(\.name) == ["Out"])
        fake.saves[0].complete(directory.appendingPathComponent("Out"))
        graph.settle()
        #expect(log.value == ["In.txt", "Out.txt"])
        #expect(try String(contentsOf: directory.appendingPathComponent("Out.txt"), encoding: .utf8) == "Exported")
        // Presenting again after a dialog closes works.
        graph.tapText("Import")
        graph.settle()
        #expect(fake.opens.count == 2)
    }
}
