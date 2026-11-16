//
//  AppleLayout.swift
//  CacaoParityApple
//
//  Lays out the corpus with Apple's SwiftUI in an NSHostingView.
//

import AppKit
import SwiftUI

private struct ProbeKey: PreferenceKey {

    static let defaultValue: [String: CGRect] = [:]

    static func reduce(value: inout [String: CGRect], nextValue: () -> [String: CGRect]) {
        value.merge(nextValue()) { first, _ in first }
    }
}

extension View {

    /// Records the view's frame in the root's coordinate space.
    func probe(_ name: String) -> some View {
        background {
            GeometryReader { proxy in
                Color.clear.preference(key: ProbeKey.self, value: [name: proxy.frame(in: .named("root"))])
            }
        }
    }
}

@MainActor
private final class Recorder {

    var frames: [String: CGRect]?
}

@MainActor
public enum AppleLayout {

    /// The names of the corpus's cases.
    public static var caseNames: [String] {
        LayoutCorpus.cases.map(\.name)
    }

    /// The frames of the probed views in a case, laid out by SwiftUI.
    public static func frames(of name: String) -> [String: CGRect] {
        guard let layoutCase = LayoutCorpus.cases.first(where: { $0.name == name }) else {
            return [:]
        }
        let size = layoutCase.size
        let recorder = Recorder()
        let root = layoutCase.view
            .frame(width: size.width, height: size.height)
            .coordinateSpace(name: "root")
            .onPreferenceChange(ProbeKey.self) { frames in
                MainActor.assumeIsolated {
                    recorder.frames = frames
                }
            }
        let host = NSHostingView(rootView: root)
        host.frame = CGRect(origin: .zero, size: size)
        host.layoutSubtreeIfNeeded()
        let deadline = Date().addingTimeInterval(2)
        while recorder.frames == nil, Date() < deadline {
            RunLoop.main.run(until: Date().addingTimeInterval(0.01))
            host.layoutSubtreeIfNeeded()
        }
        return recorder.frames ?? [:]
    }
}
