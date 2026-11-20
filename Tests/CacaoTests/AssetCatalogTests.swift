import CacaoRender
import Foundation
#if canImport(CoreGraphics)
import CoreGraphics
#endif
import Testing
@testable import Cacao

@MainActor
@Suite struct AssetCatalogTests {

    /// A PNG of one transparent pixel.
    private static let png = Data(base64Encoded: "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNkYPhfDwAChwGA60e6kgAAAABJRU5ErkJggg==")!

    /// A folder with an asset catalog as Xcode keeps it: an image set with
    /// a file for every scale, and in a group one with files for two scales.
    private func makeBundle() throws -> URL {
        let manager = FileManager.default
        let bundle = manager.temporaryDirectory.appendingPathComponent("CacaoAssets-\(UUID().uuidString)", isDirectory: true)
        let catalog = bundle.appendingPathComponent("Assets.xcassets", isDirectory: true)
        let poster = catalog.appendingPathComponent("poster.imageset", isDirectory: true)
        let icon = catalog.appendingPathComponent("Icons/icon.imageset", isDirectory: true)
        try manager.createDirectory(at: poster, withIntermediateDirectories: true)
        try manager.createDirectory(at: icon, withIntermediateDirectories: true)
        try Self.png.write(to: poster.appendingPathComponent("poster.png"))
        try Data(#"{"images":[{"filename":"poster.png","idiom":"universal"}],"info":{"author":"xcode","version":1}}"#.utf8)
            .write(to: poster.appendingPathComponent("Contents.json"))
        try Self.png.write(to: icon.appendingPathComponent("small.png"))
        try Self.png.write(to: icon.appendingPathComponent("large.png"))
        try Data(#"{"images":[{"filename":"small.png","idiom":"universal","scale":"1x"},{"filename":"large.png","idiom":"universal","scale":"2x"},{"idiom":"universal","scale":"3x"}]}"#.utf8)
            .write(to: icon.appendingPathComponent("Contents.json"))
        return bundle
    }

    @Test func aNamedImageComesFromAnImageSet() throws {
        let bundle = try makeBundle()
        defer { try? FileManager.default.removeItem(at: bundle) }
        let poster = try #require(ImageSource.named("poster", bundlePath: bundle.path, scale: 2))
        #expect(poster.pixelSize == CGSize(width: 1, height: 1))
        // A file for every scale is drawn as one point a pixel.
        #expect(poster.scale == 1)
    }

    @Test func anImageSetsFileForTheScaleIsChosen() throws {
        let bundle = try makeBundle()
        defer { try? FileManager.default.removeItem(at: bundle) }
        // In a group of the catalog, and by scale; the nearest when there's none for it.
        #expect(ImageSource.named("icon", bundlePath: bundle.path, scale: 1)?.scale == 1)
        #expect(ImageSource.named("icon", bundlePath: bundle.path, scale: 2)?.scale == 2)
        #expect(ImageSource.named("icon", bundlePath: bundle.path, scale: 3)?.scale == 2)
    }

    @Test func anImageThatIsNotThereIsNotFound() throws {
        let bundle = try makeBundle()
        defer { try? FileManager.default.removeItem(at: bundle) }
        #expect(ImageSource.named("missing", bundlePath: bundle.path, scale: 2) == nil)
    }
}
