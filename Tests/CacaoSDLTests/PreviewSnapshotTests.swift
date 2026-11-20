import Foundation
import Testing
@testable import Cacao
@testable import CacaoSDL

@MainActor
@Suite struct PreviewSnapshotTests {

    struct Named: _PreviewRegistration {
        static var name: String? { "Dark mode / large" }
        static var fileID: String { "App/Screens.swift" }
        static var line: Int { 42 }
        static func makeView() -> AnyView { AnyView(EmptyView()) }
    }

    struct Unnamed: _PreviewRegistration {
        static var name: String? { nil }
        static var fileID: String { "App/Screens.swift" }
        static var line: Int { 7 }
        static func makeView() -> AnyView { AnyView(EmptyView()) }
    }

    @Test func snapshotsAreNamedForTheirFileLineAndName() {
        #expect(PreviewSnapshots.fileName(for: Unnamed.self) == "Screens-7.png")
        #expect(PreviewSnapshots.fileName(for: Named.self) == "Screens-42-Dark-mode---large.png")
    }

    @Test func snapshotsGoNextToTheProgram() throws {
        let directory = try #require(PreviewSnapshots.directory)
        #expect(directory.lastPathComponent == "Previews")
        #expect(directory.deletingLastPathComponent() == Bundle.main.executableURL?.deletingLastPathComponent())
    }
}
