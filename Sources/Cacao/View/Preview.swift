//
//  Preview.swift
//  Cacao
//
//  Created by Alsey Coleman Miller on 11/20/26.
//

import CacaoRender
import Foundation
#if canImport(CoreGraphics)
import CoreGraphics
#endif
#if canImport(Darwin)
import Darwin
import MachO
#endif

/// Creates a preview of a SwiftUI view.
///
/// Cacao has no preview canvas. In a debug build a preview is registered,
/// and an app draws each one to an image in the build folder when it
/// launches; in a release build a preview declares nothing.
@freestanding(declaration, names: named(_CacaoPreview))
public macro Preview(
    _ name: String? = nil,
    @ViewBuilder body: @escaping @MainActor () -> any View
) = #externalMacro(module: "CacaoMacros", type: "PreviewMacro")

/// A preview that `#Preview` declares in a debug build.
@MainActor
@preconcurrency
public protocol _PreviewRegistration {

    /// The preview's name, if it has one.
    static var name: String? { get }

    /// The file that declares it, as `Module/File.swift`.
    static var fileID: String { get }

    /// The line that declares it.
    static var line: Int { get }

    /// The view it shows.
    static func makeView() -> AnyView
}

extension _PreviewRegistration {

    /// A window that shows the preview, for a host to draw it.
    package static func windowDescription(size: CGSize) -> WindowDescription {
        WindowDescription(title: name ?? "", id: nil, defaultSize: size, rootView: makeView())
    }
}

/// The previews declared in the running program.
@MainActor
package enum PreviewRegistry {

    /// What the types `#Preview` declares have in their names.
    package static let marker = "_CacaoPreview"

    /// Every preview, in the order of their files and lines.
    package static var all: [any _PreviewRegistration.Type] {
        var found: [any _PreviewRegistration.Type] = []
        for type in TypeMetadata.types(named: marker) {
            if let preview = type as? any _PreviewRegistration.Type {
                found.append(preview)
            }
        }
        return found.sorted { ($0.fileID, $0.line) < ($1.fileID, $1.line) }
    }
}

/// The types the Swift runtime knows of, from the records each image has of
/// its types.
internal enum TypeMetadata {

    /// The structures that aren't generic and have `marker` in their names.
    static func types(named marker: String) -> [Any.Type] {
        var types: [Any.Type] = []
        for section in sections() {
            // Each record is a relative pointer to a type's descriptor.
            let count = section.count / MemoryLayout<Int32>.size
            for index in 0..<count {
                let record = section.baseAddress! + index * MemoryLayout<Int32>.size
                let value = record.loadUnaligned(as: Int32.self)
                var descriptor = UnsafeRawPointer(record) + Int(value & ~0x3)
                // Through another pointer, for a type of another image.
                if value & 0x3 == 1 {
                    guard let direct = descriptor.loadUnaligned(as: UnsafeRawPointer?.self) else { continue }
                    descriptor = direct
                } else if value & 0x3 != 0 {
                    continue
                }
                let flags = descriptor.loadUnaligned(as: UInt32.self)
                let isStruct = flags & 0x1F == 17
                let isGeneric = flags & 0x80 != 0
                guard isStruct, !isGeneric else { continue }
                let nameField = descriptor + 8
                let name = String(cString: (nameField + Int(nameField.loadUnaligned(as: Int32.self))).assumingMemoryBound(to: CChar.self))
                guard name.contains(marker) else { continue }
                let accessorField = descriptor + 12
                let offset = Int(accessorField.loadUnaligned(as: Int32.self))
                guard offset != 0 else { continue }
                // The function that returns the type's metadata.
                typealias Accessor = @convention(thin) (Int) -> (UnsafeRawPointer, Int)
                let accessor = unsafeBitCast(accessorField + offset, to: Accessor.self)
                types.append(unsafeBitCast(accessor(0).0, to: Any.Type.self))
            }
        }
        return types
    }

    /// The type records of every image loaded.
    private static func sections() -> [UnsafeRawBufferPointer] {
        #if canImport(Darwin)
        var sections: [UnsafeRawBufferPointer] = []
        for image in 0..<_dyld_image_count() {
            guard let header = _dyld_get_image_header(image) else { continue }
            var size: UInt = 0
            let start = header.withMemoryRebound(to: mach_header_64.self, capacity: 1) {
                getsectiondata($0, "__TEXT", "__swift5_types", &size)
            }
            if let start, size > 0 {
                sections.append(UnsafeRawBufferPointer(start: start, count: Int(size)))
            }
        }
        return sections
        #elseif os(Linux) || os(Android) || os(FreeBSD)
        let found = SectionList()
        swift_enumerateAllMetadataSections({ sections, context in
            // After a version, a base address and two unused words come
            // ranges of a start and a length: protocols, conformances, types.
            let words = sections.assumingMemoryBound(to: UInt.self)
            let start = words[8], length = words[9]
            if let context, let pointer = UnsafeRawPointer(bitPattern: start), length > 0 {
                Unmanaged<SectionList>.fromOpaque(context).takeUnretainedValue().sections
                    .append(UnsafeRawBufferPointer(start: pointer, count: Int(length)))
            }
            return true
        }, Unmanaged.passUnretained(found).toOpaque())
        return found.sections
        #else
        return []
        #endif
    }
}

#if os(Linux) || os(Android) || os(FreeBSD)
private final class SectionList {
    var sections: [UnsafeRawBufferPointer] = []
}

/// Calls `body` with the metadata sections of each image loaded, until it
/// returns `false`.
@_silgen_name("swift_enumerateAllMetadataSections")
private func swift_enumerateAllMetadataSections(
    _ body: @convention(c) (_ sections: UnsafeRawPointer, _ context: UnsafeMutableRawPointer?) -> Bool,
    _ context: UnsafeMutableRawPointer?
)
#endif
