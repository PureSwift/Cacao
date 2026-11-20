//
//  HostFileDialogs.swift
//  CacaoHost
//
//  Created by Alsey Coleman Miller on 11/13/26.
//

import Foundation
import SDL3Swift

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
        SDL.showOpenFileDialog(
            window: window,
            filters: filters.map(\.dialogFilter),
            allowsMultiple: allowsMultiple
        ) { result in
            Self.deliver(result, to: completion)
        }
    }

    /// Shows the system's save dialog over the window, offering a file
    /// name, and calls back on the main actor with where to save: `nil` if
    /// cancelled.
    public func showSaveDialog(
        defaultName: String,
        filters: [HostFileFilter] = [],
        completion: @escaping @MainActor (URL?) -> Void
    ) {
        // Where the dialog opens: the home folder, or the app's documents
        // where apps have no home folder to write to.
        #if os(macOS) || os(Linux)
        let folder = FileManager.default.homeDirectoryForCurrentUser
        #else
        let folder = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory
        #endif
        let location = folder.appendingPathComponent(defaultName).path
        SDL.showSaveFileDialog(
            window: window,
            filters: filters.map(\.dialogFilter),
            defaultLocation: location
        ) { result in
            Self.deliver(result) { urls in completion(urls.first) }
        }
    }

    /// Passes a dialog's files to the main actor: SDL may call back on
    /// another thread. A dialog that failed chose nothing.
    private nonisolated static func deliver(_ result: SDLDialogResult, to completion: @escaping @MainActor ([URL]) -> Void) {
        let urls: [URL]
        switch result {
        case let .selected(paths):
            urls = paths.map { URL(fileURLWithPath: $0) }
        case .cancelled:
            urls = []
        case let .failed(error):
            print("Cacao: the file dialog failed: \(error)")
            urls = []
        }
        DispatchQueue.main.async {
            MainActor.assumeIsolated {
                completion(urls)
            }
        }
    }
}

extension HostFileFilter {

    fileprivate var dialogFilter: SDLDialogFileFilter {
        SDLDialogFileFilter(name: name, extensions: extensions)
    }
}
