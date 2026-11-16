//
//  LayoutParityTests.swift
//  CacaoLayoutParityTests
//
//  Lays out every case of the shared corpus with Apple's SwiftUI and with
//  Cacao, and expects the same frames.
//

import CacaoParityApple
import CacaoParityCacao
import Foundation
import Testing

@MainActor
@Suite struct LayoutParityTests {

    /// The largest difference allowed between frames, in points; SwiftUI
    /// rounds frames to its pixel grid.
    static let tolerance = 0.5

    @Test func casesMatchSwiftUI() {
        let names = CacaoLayout.caseNames
        #expect(!names.isEmpty)
        for name in names {
            let apple = AppleLayout.frames(of: name)
            let cacao = CacaoLayout.frames(of: name)
            #expect(!apple.isEmpty, "SwiftUI recorded no frames for \(name)")
            #expect(Set(apple.keys) == Set(cacao.keys), "\(name): probes differ")
            for (probe, expected) in apple.sorted(by: { $0.key < $1.key }) {
                guard let actual = cacao[probe] else { continue }
                let matches = abs(expected.minX - actual.minX) <= Self.tolerance
                    && abs(expected.minY - actual.minY) <= Self.tolerance
                    && abs(expected.width - actual.width) <= Self.tolerance
                    && abs(expected.height - actual.height) <= Self.tolerance
                #expect(matches, "\(name).\(probe): SwiftUI \(expected), Cacao \(actual)")
            }
        }
    }
}
