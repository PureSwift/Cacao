//
//  HostFileDialogs.swift
//  CacaoHost
//
//  Created by Alsey Coleman Miller on 11/13/26.
//

import Foundation
import CSDL3

/// A kind of file a dialog offers: a name shown to the user, and the file
/// name extensions it matches, without dots.
public struct HostFileFilter: Hashable, Sendable {

    public var name: String

    public var extensions: [String]

    public init(name: String, extensions: [String]) {
        self.name = name
        self.extensions = extensions
    }
}

extension HostWindow {

    /// Shows the system's open dialog over the window, and calls back on
    /// the main actor with the files chosen: none if cancelled.
    public func showOpenDialog(
        filters: [HostFileFilter] = [],
        allowsMultiple: Bool = false,
        completion: @escaping @MainActor ([URL]) -> Void
    ) {
        let request = DialogRequest(filters: filters, completion: completion)
        SDL_ShowOpenFileDialog(dialogCallback, request.retained(), sdlWindow, request.filters, Int32(request.filterCount), nil, allowsMultiple)
    }

    /// Shows the system's save dialog over the window, offering a file
    /// name, and calls back on the main actor with where to save: `nil` if
    /// cancelled.
    public func showSaveDialog(
        defaultName: String,
        filters: [HostFileFilter] = [],
        completion: @escaping @MainActor (URL?) -> Void
    ) {
        let request = DialogRequest(filters: filters) { urls in completion(urls.first) }
        let location = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(defaultName).path
        SDL_ShowSaveFileDialog(dialogCallback, request.retained(), sdlWindow, request.filters, Int32(request.filterCount), location)
    }
}

/// A dialog being shown: its filters, which SDL reads until it calls back,
/// and what to do with the files chosen.
private final class DialogRequest: @unchecked Sendable {

    let completion: @MainActor ([URL]) -> Void

    let filters: UnsafeMutablePointer<SDL_DialogFileFilter>?

    let filterCount: Int

    private var strings: [UnsafeMutablePointer<CChar>] = []

    init(filters: [HostFileFilter], completion: @escaping @MainActor ([URL]) -> Void) {
        self.completion = completion
        let named = filters.filter { !$0.extensions.isEmpty }
        filterCount = named.count
        guard !named.isEmpty else {
            self.filters = nil
            return
        }
        let pointer = UnsafeMutablePointer<SDL_DialogFileFilter>.allocate(capacity: named.count)
        for (index, filter) in named.enumerated() {
            // SDL takes a filter's extensions separated by semicolons.
            let name = strdup(filter.name)!, pattern = strdup(filter.extensions.joined(separator: ";"))!
            strings += [name, pattern]
            pointer[index] = SDL_DialogFileFilter(name: name, pattern: pattern)
        }
        self.filters = pointer
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
