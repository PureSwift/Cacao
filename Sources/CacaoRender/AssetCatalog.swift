//
//  AssetCatalog.swift
//  CacaoRender
//
//  Created by Alsey Coleman Miller on 11/20/26.
//

import Foundation
#if canImport(CoreGraphics)
import CoreGraphics
#endif
#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

/// The image sets of the asset catalogs in a bundle.
///
/// An asset catalog here is the folder Xcode edits, `Assets.xcassets`,
/// copied into the bundle as it is: each `Name.imageset` folder has a
/// `Contents.json` that lists its files by scale. That's what a bundle holds
/// where nothing compiles catalogs, as on Linux. A catalog that Xcode
/// compiled, `Assets.car`, is read by the system on Apple platforms.
internal struct AssetCatalog {

    /// A file of an image set, for a scale.
    struct Variant: Equatable {
        var url: URL
        var scale: Int
    }

    /// The files of each image set, by its name.
    private(set) var imageSets: [String: [Variant]] = [:]

    /// The catalogs in a folder: every `.xcassets` in it.
    init(directories: [URL]) {
        let manager = FileManager.default
        for directory in directories {
            let contents = (try? manager.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil)) ?? []
            for catalog in contents where catalog.pathExtension == "xcassets" {
                add(catalog: catalog)
            }
        }
    }

    /// Adds the image sets of a catalog, in its groups too. An image set
    /// found first keeps its name.
    private mutating func add(catalog: URL) {
        guard let enumerator = FileManager.default.enumerator(at: catalog, includingPropertiesForKeys: nil) else { return }
        for case let url as URL in enumerator where url.pathExtension == "imageset" {
            enumerator.skipDescendants()
            let name = url.deletingPathExtension().lastPathComponent
            guard imageSets[name] == nil else { continue }
            let variants = Self.variants(ofImageSet: url)
            if !variants.isEmpty {
                imageSets[name] = variants
            }
        }
    }

    private struct Contents: Decodable {
        struct Image: Decodable {
            var filename: String?
            var scale: String?
        }
        var images: [Image]
    }

    /// The files an image set's `Contents.json` lists, with their scales:
    /// `"2x"` is 2, and a file for every scale is 1.
    static func variants(ofImageSet url: URL) -> [Variant] {
        guard let data = try? Data(contentsOf: url.appendingPathComponent("Contents.json")),
              let contents = try? JSONDecoder().decode(Contents.self, from: data) else {
            return []
        }
        return contents.images.compactMap { image in
            guard let filename = image.filename else { return nil }
            let scale = image.scale.flatMap { Int($0.dropLast()) } ?? 1
            return Variant(url: url.appendingPathComponent(filename), scale: max(scale, 1))
        }
    }

    /// The file of an image set closest to a scale, preferring a larger one.
    func variant(named name: String, scale: Int) -> Variant? {
        imageSets[name]?.min { lhs, rhs in
            let left = abs(lhs.scale - scale), right = abs(rhs.scale - scale)
            return left == right ? lhs.scale > rhs.scale : left < right
        }
    }

    // MARK: Bundles

    /// Where a bundle's catalogs may be: its resources, and for the main
    /// bundle the resource bundles next to the program, where SwiftPM puts
    /// a target's resources.
    static func directories(for bundle: Bundle) -> [URL] {
        var directories = [bundle.resourceURL ?? bundle.bundleURL]
        if bundle == .main, let folder = bundle.executableURL?.deletingLastPathComponent() {
            if !directories.contains(folder) {
                directories.append(folder)
            }
            let siblings = (try? FileManager.default.contentsOfDirectory(at: folder, includingPropertiesForKeys: nil)) ?? []
            for sibling in siblings.sorted(by: { $0.path < $1.path })
            where ["resources", "bundle"].contains(sibling.pathExtension) {
                directories.append(sibling)
                // A bundle's resources on Apple platforms.
                directories.append(sibling.appendingPathComponent("Contents/Resources"))
            }
        }
        return directories
    }

    /// An image from the catalog the system compiled into a bundle, as PNG
    /// data and its scale. Only on Apple platforms.
    static func systemImage(named name: String, in bundle: Bundle) -> (data: Data, scale: CGFloat)? {
        #if canImport(UIKit)
        guard let image = UIImage(named: name, in: bundle, compatibleWith: nil), let data = image.pngData() else {
            return nil
        }
        return (data, image.scale)
        #elseif canImport(AppKit)
        guard let image = bundle.image(forResource: NSImage.Name(name)),
              let tiff = image.tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: tiff),
              let data = bitmap.representation(using: .png, properties: [:]) else {
            return nil
        }
        let scale = image.size.width > 0 ? CGFloat(bitmap.pixelsWide) / image.size.width : 1
        return (data, max(scale, 1))
        #else
        return nil
        #endif
    }
}
