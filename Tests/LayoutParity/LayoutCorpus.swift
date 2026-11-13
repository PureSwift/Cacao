//
//  LayoutCorpus.swift
//  Cacao
//
//  Layout cases written in the API Cacao and Apple's SwiftUI share. This
//  file is compiled twice: into CacaoParityApple against SwiftUI, and into
//  CacaoParityCacao against Cacao. Each module provides `probe(_:)`, which
//  records a view's frame in the root's coordinate space under a name.
//

#if PARITY_APPLE
import SwiftUI
#else
import Cacao
#endif
import Foundation
#if canImport(CoreGraphics)
import CoreGraphics
#endif

/// A view laid out in a container of a fixed size.
@MainActor
public struct LayoutCase {

    public let name: String

    public let size: CGSize

    public let view: AnyView

    init<V: View>(_ name: String, width: CGFloat, height: CGFloat, @ViewBuilder view: () -> V) {
        self.name = name
        self.size = CGSize(width: width, height: height)
        self.view = AnyView(view())
    }
}

/// A layout that places its subviews along a diagonal at their ideal sizes.
struct DiagonalLayout: Layout {

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout Void) -> CGSize {
        subviews.reduce(CGSize(width: 0, height: 0)) { size, subview in
            let child = subview.sizeThatFits(.unspecified)
            return CGSize(width: size.width + child.width, height: size.height + child.height)
        }
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout Void) {
        var point = bounds.origin
        for subview in subviews {
            let child = subview.sizeThatFits(.unspecified)
            subview.place(at: point, proposal: .unspecified)
            point.x += child.width
            point.y += child.height
        }
    }
}

@MainActor
public enum LayoutCorpus {

    public static var cases: [LayoutCase] {
        [
            LayoutCase("root-centering", width: 400, height: 300) {
                Color.red.frame(width: 100, height: 50).probe("a")
            },
            LayoutCase("hstack-fixed", width: 300, height: 200) {
                HStack {
                    Color.red.frame(width: 50, height: 50).probe("a")
                    Color.blue.frame(width: 30, height: 80).probe("b")
                }
                .probe("stack")
            },
            LayoutCase("hstack-flexible", width: 300, height: 100) {
                HStack {
                    Color.red.probe("a")
                    Color.blue.frame(width: 40).probe("b")
                    Color.green.probe("c")
                }
            },
            LayoutCase("vstack-flexible", width: 200, height: 300) {
                VStack(spacing: 4) {
                    Color.red.probe("a")
                    Color.blue.frame(height: 40).probe("b")
                    Color.green.frame(maxHeight: 50).probe("c")
                }
            },
            LayoutCase("vstack-alignment", width: 200, height: 200) {
                VStack(alignment: .leading, spacing: 10) {
                    Color.red.frame(width: 100, height: 20).probe("a")
                    Color.blue.frame(width: 40, height: 20).probe("b")
                }
                .probe("stack")
            },
            LayoutCase("hstack-alignment", width: 200, height: 200) {
                HStack(alignment: .bottom) {
                    Color.red.frame(width: 20, height: 60).probe("a")
                    Color.blue.frame(width: 20, height: 20).probe("b")
                    Color.green.frame(width: 20, height: 40).probe("c")
                }
            },
            LayoutCase("spacer", width: 300, height: 100) {
                HStack {
                    Color.red.frame(width: 20, height: 20).probe("a")
                    Spacer().probe("spacer")
                    Color.blue.frame(width: 20, height: 20).probe("b")
                }
            },
            LayoutCase("spacer-fixed", width: 300, height: 100) {
                HStack {
                    Color.red.frame(width: 20, height: 20)
                    Spacer()
                    Color.blue.frame(width: 20, height: 20)
                }
                .fixedSize()
                .probe("stack")
            },
            LayoutCase("spacer-min-length", width: 300, height: 300) {
                VStack {
                    Color.red.frame(width: 20, height: 20).probe("a")
                    Spacer(minLength: 30)
                    Color.blue.frame(width: 20, height: 20).probe("b")
                }
                .fixedSize()
            },
            LayoutCase("priority", width: 300, height: 50) {
                HStack(spacing: 0) {
                    Color.red.frame(minWidth: 50).probe("a")
                    Color.blue.frame(minWidth: 50).layoutPriority(1).probe("b")
                }
            },
            LayoutCase("padding", width: 200, height: 200) {
                Color.red.frame(width: 40, height: 40).probe("inner")
                    .padding(10)
                    .padding(.horizontal, 5)
                    .probe("outer")
            },
            LayoutCase("padding-in-stack", width: 200, height: 200) {
                VStack {
                    Color.red.frame(width: 40, height: 40).padding(4).probe("a")
                    Color.blue.frame(width: 40, height: 40).probe("b")
                }
            },
            LayoutCase("flex-frame-min", width: 300, height: 200) {
                Color.red.frame(width: 30, height: 30).probe("inner")
                    .frame(minWidth: 100, minHeight: 60, alignment: .topLeading)
                    .probe("frame")
            },
            LayoutCase("flex-frame-max", width: 300, height: 100) {
                VStack {
                    Color.red.frame(width: 50, height: 50).probe("inner")
                        .frame(maxWidth: .infinity, alignment: .trailing)
                        .probe("wide")
                }
            },
            LayoutCase("flex-frame-min-max", width: 300, height: 100) {
                Color.red.frame(width: 20, height: 20)
                    .frame(minWidth: 50, maxWidth: 120, minHeight: 10, maxHeight: 40)
                    .probe("frame")
            },
            LayoutCase("fixed-frame-alignment", width: 200, height: 200) {
                Color.red.frame(width: 20, height: 20).probe("inner")
                    .frame(width: 100, height: 60, alignment: .bottomLeading)
                    .probe("frame")
            },
            LayoutCase("zstack", width: 200, height: 200) {
                ZStack(alignment: .bottomTrailing) {
                    Color.red.frame(width: 100, height: 80).probe("a")
                    Color.blue.frame(width: 30, height: 20).probe("b")
                }
            },
            LayoutCase("background-overlay", width: 100, height: 100) {
                Color.red.frame(width: 60, height: 40).probe("a")
                    .background(alignment: .topLeading) {
                        Color.blue.frame(width: 20, height: 20).probe("background")
                    }
                    .overlay { Color.green.probe("overlay") }
            },
            LayoutCase("alignment-guide", width: 200, height: 200) {
                VStack(alignment: .leading, spacing: 0) {
                    Color.red.frame(width: 50, height: 20).probe("a")
                    Color.blue.frame(width: 50, height: 20)
                        .alignmentGuide(.leading) { _ in 20 }
                        .probe("b")
                }
                .probe("stack")
            },
            LayoutCase("offset", width: 200, height: 100) {
                HStack(spacing: 0) {
                    Color.red.frame(width: 40, height: 40).probe("inner").offset(x: 10, y: 5).probe("a")
                    Color.blue.frame(width: 40, height: 40).probe("b")
                }
            },
            LayoutCase("ideal-size", width: 200, height: 100) {
                HStack {
                    Color.red
                    Color.blue
                }
                .fixedSize()
                .probe("stack")
            },
            LayoutCase("nested-stacks", width: 320, height: 240) {
                VStack(spacing: 12) {
                    HStack {
                        Color.red.frame(width: 40, height: 40).probe("a")
                        Spacer()
                        Color.blue.frame(width: 40, height: 40).probe("b")
                    }
                    .padding(.horizontal, 16)
                    HStack(spacing: 0) {
                        Color.green.probe("c")
                        Color.orange.frame(width: 100).probe("d")
                    }
                    .frame(height: 50)
                }
                .probe("stack")
            },
            LayoutCase("custom-layout", width: 100, height: 100) {
                DiagonalLayout {
                    Color.red.frame(width: 10, height: 20).probe("a")
                    Color.blue.frame(width: 30, height: 10).probe("b")
                }
            },
        ]
    }
}
