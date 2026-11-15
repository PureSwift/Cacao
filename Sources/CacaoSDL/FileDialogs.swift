//
//  FileDialogs.swift
//  CacaoSDL
//
//  Created by Alsey Coleman Miller on 11/15/26.
//

import Foundation
import Cacao
import CSDL3

/// The system's open and save dialogs, through SDL, for a window.
@MainActor
enum SDLFileDialogs {

    static func dialogs(for window: OpaquePointer) -> FileDialogs {
        FileDialogs(
            open: { types, allowsMultiple, completion in
                let request = DialogRequest(types: types) { urls in completion(urls) }
                SDL_ShowOpenFileDialog(dialogCallback, request.retained(), window, request.filters, Int32(request.filterCount), nil, allowsMultiple)
            },
            save: { defaultName, types, completion in
                let request = DialogRequest(types: types) { urls in completion(urls.first) }
                let location = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(defaultName).path
                SDL_ShowSaveFileDialog(dialogCallback, request.retained(), window, request.filters, Int32(request.filterCount), location)
            }
        )
    }
}

/// A dialog being shown: its filters, which SDL reads until it calls back,
/// and what to do with the files chosen.
private final class DialogRequest: @unchecked Sendable {

    let completion: @MainActor ([URL]) -> Void

    /// One filter per type with a known file name extension.
    let filters: UnsafeMutablePointer<SDL_DialogFileFilter>?

    let filterCount: Int

    private var strings: [UnsafeMutablePointer<CChar>] = []

    init(types: [UTType], completion: @escaping @MainActor ([URL]) -> Void) {
        self.completion = completion
        let named = types.compactMap { type in
            filenameExtension(of: type).map { (name: type.description, pattern: $0) }
        }
        filterCount = named.count
        guard !named.isEmpty else {
            filters = nil
            return
        }
        let filters = UnsafeMutablePointer<SDL_DialogFileFilter>.allocate(capacity: named.count)
        for (index, filter) in named.enumerated() {
            let name = strdup(filter.name)!, pattern = strdup(filter.pattern)!
            strings += [name, pattern]
            filters[index] = SDL_DialogFileFilter(name: name, pattern: pattern)
        }
        self.filters = filters
    }

    deinit {
        strings.forEach { free($0) }
        filters?.deallocate()
    }

    func retained() -> UnsafeMutableRawPointer {
        Unmanaged.passRetained(self).toOpaque()
    }
}

/// Called by SDL, perhaps on another thread, with the files chosen: none
/// when cancelled.
private let dialogCallback: SDL_DialogFileCallback = { userdata, list, _ in
    guard let userdata else { return }
    let request = Unmanaged<DialogRequest>.fromOpaque(userdata).takeRetainedValue()
    var urls: [URL] = []
    if let list {
        var index = 0
        while let path = list[index] {
            urls.append(URL(fileURLWithPath: String(cString: path)))
            index += 1
        }
    }
    let chosen = urls
    DispatchQueue.main.async {
        MainActor.assumeIsolated {
            request.completion(chosen)
        }
    }
}
