//
//  ExternalSurfaceView.swift
//  Cacao
//
//  Created by Alsey Coleman Miller on 11/19/26.
//

import CacaoRender
import Foundation
#if canImport(CoreGraphics)
import CoreGraphics
#endif

/// A view that shows frames drawn outside Cacao: a GL or Metal drawable's,
/// a web view's, a video's.
///
/// The frames' producer publishes them to the surface from any thread, and
/// the view shows the newest, stretched to its frame. It takes the size
/// it's offered, and the surface's own size along any dimension left
/// unspecified. This isn't part of SwiftUI.
public struct ExternalSurfaceView: View, PrimitiveView {

    /// The surface whose frames the view shows.
    public var surface: ExternalSurface

    /// The pixels of the surface per point, or `nil` for the display's.
    public var scale: CGFloat?

    /// Whether frames are smoothed when they're scaled.
    public var isSmooth: Bool

    /// What the surface's producer does with input; see `onInput`.
    internal var input: ExternalInputHandler?

    public init(_ surface: ExternalSurface, scale: CGFloat? = nil, isSmooth: Bool = true) {
        self.surface = surface
        self.scale = scale
        self.isSmooth = isSmooth
    }

    public typealias Body = Never

    func resolve(in context: ResolveContext) -> Resolution {
        var attributes = NodeAttributes()
        if let input, context.environment.isEnabled {
            attributes.externalInput = input
            // Focusable, so a click or Tab sends keys and text its way.
            attributes.focus = FocusTarget(
                acceptsText: input.acceptsText,
                insertText: { input.handle(.text($0)) },
                focusChanged: { input.handle(.focus($0)) }
            )
        }
        return Resolution(
            behavior: ExternalSurfaceBehavior(
                surface: surface,
                scale: scale ?? context.environment.displayScale,
                isSmooth: isSmooth
            ),
            attributes: attributes
        )
    }
}

internal struct ExternalSurfaceBehavior: NodeBehavior {

    let surface: ExternalSurface

    let scale: CGFloat

    let isSmooth: Bool

    /// The surface's size in points, or SwiftUI's 10 points before it has
    /// a frame.
    private var naturalSize: CGSize {
        let pixels = surface.pixelSize
        guard pixels.width > 0, pixels.height > 0, scale > 0 else {
            return CGSize(width: 10, height: 10)
        }
        return CGSize(width: pixels.width / scale, height: pixels.height / scale)
    }

    func sizeThatFits(_ proposal: ProposedViewSize, node: ViewNode) -> CGSize {
        proposal.replacingUnspecifiedDimensions(by: naturalSize)
    }

    func displayContent(node: ViewNode) -> DisplayList.Content? {
        .external(ExternalContent(surface: surface, isSmooth: isSmooth))
    }
}
