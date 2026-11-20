//
//  PreviewSnapshots.swift
//  CacaoSDL
//
//  Created by Alsey Coleman Miller on 11/20/26.
//

import CacaoRender
import Cacao
import CacaoHost
import Foundation
#if canImport(CoreGraphics)
import CoreGraphics
#endif

/// Draws the previews that `#Preview` declares to images, in place of a
/// preview canvas: in a debug build, into the build folder next to the
/// program, when an app launches.
@MainActor
internal enum PreviewSnapshots {

    /// The size a preview is drawn at, in points.
    static let size = CGSize(width: 400, height: 600)

    /// Where the snapshots go: `Previews`, next to the program.
    static var directory: URL? {
        #if os(iOS) || os(tvOS) || os(visionOS)
        // An app's bundle there isn't a build folder, nor writable.
        return nil
        #else
        return Bundle.main.executableURL?.deletingLastPathComponent().appendingPathComponent("Previews", isDirectory: true)
        #endif
    }

    /// The file name of a preview's snapshot: its file, line and name.
    static func fileName(for preview: any _PreviewRegistration.Type) -> String {
        let file = preview.fileID.split(separator: "/").last.map(String.init) ?? preview.fileID
        var parts = [file.hasSuffix(".swift") ? String(file.dropLast(6)) : file, String(preview.line)]
        if let name = preview.name, !name.isEmpty {
            parts.append(String(name.map { $0.isLetter || $0.isNumber ? $0 : "-" }))
        }
        return parts.joined(separator: "-") + ".png"
    }

    /// Draws each preview whose snapshot is missing or older than the
    /// program. Does nothing in a release build.
    static func generate(textEngine: any TextEngine) {
        #if DEBUG
        let previews = PreviewRegistry.all
        guard !previews.isEmpty, let directory else { return }
        let manager = FileManager.default
        let built = Bundle.main.executableURL
            .flatMap { try? manager.attributesOfItem(atPath: $0.path)[.modificationDate] as? Date }
        do {
            try manager.createDirectory(at: directory, withIntermediateDirectories: true)
        } catch {
            print("Cacao: previews not saved: \(error)")
            return
        }
        var saved = 0
        for preview in previews {
            let url = directory.appendingPathComponent(fileName(for: preview))
            if let built, let drawn = try? manager.attributesOfItem(atPath: url.path)[.modificationDate] as? Date, drawn >= built {
                continue
            }
            let description = preview.windowDescription(size: size)
            let wasSaved = HostRuntime.snapshot(size: size, to: url.path) { window in
                WindowScene(description: description, window: window, textEngine: textEngine)
            }
            if wasSaved {
                saved += 1
            }
        }
        if saved > 0 {
            print("Cacao: saved \(saved) preview\(saved == 1 ? "" : "s") to \(directory.path)")
        }
        #endif
    }
}
