//
//  Image.swift
//  Cacao
//
//  Created by Alsey Coleman Miller on 11/13/26.
//

import CacaoRender
import Foundation
#if canImport(CoreGraphics)
import CoreGraphics
#endif

/// A view that displays an image.
///
/// Named images are PNG files in a bundle, with `@2x` and `@3x` variants for
/// higher display scales.
public struct Image: Equatable, Sendable {

    internal enum Source: Equatable, Sendable {
        case named(String, bundlePath: String?)
        case systemName(String)
        case data(ImageSource)
    }

    internal var source: Source

    internal var isResizable = false

    internal var capInsets = EdgeInsets()

    internal var renderingMode: TemplateRenderingMode?

    internal var interpolation: Interpolation = .medium

    /// Creates a labeled image that you can use as content for controls.
    public init(_ name: String, bundle: Bundle? = nil) {
        self.source = .named(name, bundlePath: bundle?.bundlePath)
    }

    /// Creates an unlabeled, decorative image.
    public init(decorative name: String, bundle: Bundle? = nil) {
        self.init(name, bundle: bundle)
    }

    /// Creates a system symbol image.
    ///
    /// Cacao draws its own versions of common symbols, in the foreground
    /// style at the size of the current font; others are empty, sized like
    /// a glyph.
    public init(systemName: String) {
        self.source = .systemName(systemName)
    }

    /// Creates an image from PNG data.
    public init(pngData data: Data, scale: CGFloat = 1) {
        self.source = .data(ImageSource(data: data, scale: scale))
    }

    /// Creates an image from pixels: 8-bit RGBA with premultiplied alpha,
    /// rows top to bottom, `bytesPerRow` apart.
    ///
    /// Each image made this way is new to a renderer, which uploads it
    /// once, so it suits content that changes every frame, such as video or
    /// a GL surface read back.
    public init(pixels data: Data, width: Int, height: Int, bytesPerRow: Int, scale: CGFloat = 1) {
        precondition(width >= 0 && height >= 0 && bytesPerRow >= width * 4 && data.count >= bytesPerRow * height,
                     "pixel data too small for \(width) × \(height) at \(bytesPerRow) bytes a row")
        self.source = .data(ImageSource(pixels: ImageSource.Pixels(data: data, bytesPerRow: bytesPerRow), width: width, height: height, scale: scale))
    }

    /// Sets the mode by which SwiftUI resizes an image to fit its space.
    public func resizable(capInsets: EdgeInsets = EdgeInsets(), resizingMode: ResizingMode = .stretch) -> Image {
        var image = self
        image.isResizable = true
        image.capInsets = capInsets
        return image
    }

    /// Indicates whether SwiftUI renders an image as-is, or by using a
    /// different mode.
    public func renderingMode(_ renderingMode: TemplateRenderingMode?) -> Image {
        var image = self
        image.renderingMode = renderingMode
        return image
    }

    /// Specifies the current level of quality for rendering an image that
    /// requires interpolation.
    public func interpolation(_ interpolation: Interpolation) -> Image {
        var image = self
        image.interpolation = interpolation
        return image
    }

    /// The modes that SwiftUI uses to resize an image to fit within its
    /// containing view.
    public enum ResizingMode: Hashable, Sendable {
        case tile
        case stretch
    }

    /// A type that indicates how SwiftUI renders images.
    public enum TemplateRenderingMode: Hashable, Sendable {
        case template
        case original
    }

    /// The level of quality for rendering an image that requires
    /// interpolation, such as a scaled image.
    public typealias Interpolation = ImageInterpolation
}

// MARK: - ImageSource

// MARK: - View

extension Image: View, PrimitiveView {

    public typealias Body = Never

    func resolve(in context: ResolveContext) -> Resolution {
        let environment = context.environment
        if environment.redactionReasons.contains(.placeholder) {
            return Resolution(children: [redactedPlaceholder(of: self, in: environment)])
        }
        if case let .systemName(name) = self.source {
            let font = (environment.font ?? .body).resolve()
            let scale: CGFloat = switch environment.imageScale {
            case .small: 0.8
            case .medium: 1
            case .large: 1.3
            }
            let original = renderingMode == .original
            return Resolution(behavior: SymbolBehavior(
                parts: Symbols.parts(name),
                isResizable: isResizable,
                size: (font.size * scale).rounded(),
                color: original ? Color.primary.resolve(in: environment) : environment.resolvedForeground,
                gradient: original ? nil : environment.resolvedForegroundGradient,
                weight: font.weight
            ))
        }
        let source: ImageSource?
        switch self.source {
        case let .named(name, bundlePath):
            source = ImageSource.named(name, bundlePath: bundlePath, scale: environment.displayScale)
        case .systemName:
            source = nil
        case let .data(data):
            source = data
        }
        let tint: Color.Resolved? = renderingMode == .template ? environment.resolvedForeground : nil
        let fallbackSize = (environment.font ?? .body).resolve().size
        return Resolution(behavior: ImageBehavior(
            source: source,
            isResizable: isResizable,
            tint: tint,
            interpolation: interpolation,
            fallbackSize: CGSize(width: fallbackSize, height: fallbackSize)
        ))
    }
}

internal struct ImageBehavior: NodeBehavior {

    let source: ImageSource?

    let isResizable: Bool

    let tint: Color.Resolved?

    let interpolation: Image.Interpolation

    /// The size of an image that couldn't be loaded.
    let fallbackSize: CGSize

    private var naturalSize: CGSize {
        source?.size ?? fallbackSize
    }

    /// A fixed image takes its natural size; a resizable one takes the
    /// proposal, and its natural size along unspecified dimensions.
    func sizeThatFits(_ proposal: ProposedViewSize, node: ViewNode) -> CGSize {
        isResizable ? proposal.replacingUnspecifiedDimensions(by: naturalSize) : naturalSize
    }

    func displayContent(node: ViewNode) -> DisplayList.Content? {
        guard let source else { return nil }
        return .image(ImageContent(source: source, tint: tint, interpolation: interpolation))
    }
}

// MARK: - Aspect ratio

/// Constants that define how a view's content fills the available space.
public enum ContentMode: Hashable, CaseIterable, Sendable {

    /// An option that resizes the content so it's all within the available
    /// space, both vertically and horizontally.
    case fit

    /// An option that resizes the content so it occupies all available space,
    /// both vertically and horizontally.
    case fill
}

internal struct AspectRatioBehavior: UnaryLayoutBehavior {

    /// Width over height, or `nil` for the child's ideal aspect ratio.
    let aspectRatio: CGFloat?

    let contentMode: ContentMode

    private func ratio(_ child: LayoutProxy) -> CGFloat {
        if let aspectRatio {
            return aspectRatio
        }
        let ideal = child.size(in: .unspecified)
        return ideal.height > 0 ? ideal.width / ideal.height : 1
    }

    /// The largest size with the ratio within the proposal, to fit, or the
    /// smallest that covers it, to fill.
    private func targetSize(_ proposal: ProposedViewSize, child: LayoutProxy) -> CGSize {
        let ratio = ratio(child)
        let width = proposal.width.flatMap { $0.isFinite ? $0 : nil }
        let height = proposal.height.flatMap { $0.isFinite ? $0 : nil }
        switch (width, height) {
        case let (width?, height?):
            let fitsWidth = width / height <= ratio
            switch contentMode {
            case .fit:
                return fitsWidth ? CGSize(width: width, height: width / ratio) : CGSize(width: height * ratio, height: height)
            case .fill:
                return fitsWidth ? CGSize(width: height * ratio, height: height) : CGSize(width: width, height: width / ratio)
            }
        case let (width?, nil):
            return CGSize(width: width, height: width / ratio)
        case let (nil, height?):
            return CGSize(width: height * ratio, height: height)
        case (nil, nil):
            let ideal = child.size(in: .unspecified)
            return CGSize(width: ideal.width, height: ideal.width / ratio)
        }
    }

    func sizeThatFits(_ proposal: ProposedViewSize, child: LayoutProxy) -> CGSize {
        child.size(in: ProposedViewSize(targetSize(proposal, child: child)))
    }

    func placement(of child: LayoutProxy, size: CGSize, proposal: ProposedViewSize) -> (proposal: ProposedViewSize, origin: CGPoint) {
        let childProposal = ProposedViewSize(targetSize(proposal, child: child))
        let childSize = child.size(in: childProposal)
        return (childProposal, CGPoint(x: (size.width - childSize.width) / 2, y: (size.height - childSize.height) / 2))
    }
}

internal struct _AspectRatioLayout: ViewModifier, LayoutModifier {

    let aspectRatio: CGFloat?

    let contentMode: ContentMode

    var behavior: any NodeBehavior { AspectRatioBehavior(aspectRatio: aspectRatio, contentMode: contentMode) }

    typealias Body = Never
}

extension View {

    /// Constrains this view's dimensions to the specified aspect ratio.
    public func aspectRatio(_ aspectRatio: CGFloat? = nil, contentMode: ContentMode) -> some View {
        modifier(_AspectRatioLayout(aspectRatio: aspectRatio, contentMode: contentMode))
    }

    /// Constrains this view's dimensions to the aspect ratio of the given size.
    public func aspectRatio(_ aspectRatio: CGSize, contentMode: ContentMode) -> some View {
        self.aspectRatio(aspectRatio.height > 0 ? aspectRatio.width / aspectRatio.height : nil, contentMode: contentMode)
    }

    /// Scales this view to fit its parent.
    public func scaledToFit() -> some View {
        aspectRatio(contentMode: .fit)
    }

    /// Scales this view to fill its parent.
    public func scaledToFill() -> some View {
        aspectRatio(contentMode: .fill)
    }
}
