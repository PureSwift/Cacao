//
//  Material.swift
//  Cacao
//
//  Created by Alsey Coleman Miller on 11/20/26.
//

import CacaoRender
import Foundation
#if canImport(CoreGraphics)
import CoreGraphics
#endif

/// A background material type: what's behind a view, blurred, under a
/// translucent tint. Thinner materials let more of it through.
public struct Material: ShapeStyle, Hashable, Sendable {

    internal enum Thickness: Hashable, Sendable {
        case ultraThin, thin, regular, thick, ultraThick, bar
    }

    internal let thickness: Thickness

    /// A mostly translucent material.
    public static let ultraThin = Material(thickness: .ultraThin)

    /// A material that's more translucent than opaque.
    public static let thin = Material(thickness: .thin)

    /// A material that's somewhat translucent.
    public static let regular = Material(thickness: .regular)

    /// A material that's more opaque than translucent.
    public static let thick = Material(thickness: .thick)

    /// A mostly opaque material.
    public static let ultraThick = Material(thickness: .ultraThick)

    /// A material matching the style of system toolbars.
    public static let bar = Material(thickness: .bar)

    /// How opaque the tint over the blurred backdrop is.
    internal var tintOpacity: Double {
        switch thickness {
        case .ultraThin: 0.3
        case .thin: 0.45
        case .regular: 0.6
        case .thick: 0.75
        case .ultraThick: 0.88
        case .bar: 0.8
        }
    }

    /// The blur of what's behind, in points.
    internal static let blurRadius: CGFloat = 20

    /// The backdrop keeps more than its color, as system materials do.
    internal static let saturation = 1.8

    /// The tint over the backdrop: light in a light scheme, dark in a dark.
    internal func tint(in environment: EnvironmentValues) -> Color {
        (environment.colorScheme == .dark ? Color(white: 0.14) : Color(white: 0.97)).opacity(tintOpacity)
    }
}

extension Material: ResolvableShapeStyle {

    /// The tint alone, where the material styles something that isn't
    /// drawn over a backdrop, as text is.
    func resolveColor(in environment: EnvironmentValues) -> Color.Resolved {
        tint(in: environment).resolve(in: environment)
    }
}

extension ShapeStyle where Self == Material {

    /// A material that's somewhat translucent.
    public static var regularMaterial: Material { .regular }

    /// A material that's more opaque than translucent.
    public static var thickMaterial: Material { .thick }

    /// A material that's more translucent than opaque.
    public static var thinMaterial: Material { .thin }

    /// A mostly translucent material.
    public static var ultraThinMaterial: Material { .ultraThin }

    /// A mostly opaque material.
    public static var ultraThickMaterial: Material { .ultraThick }

    /// A material matching the style of system toolbars.
    public static var bar: Material { .bar }
}

// MARK: - Drawing

/// How a material's corners are rounded, from the shape it fills.
internal enum MaterialCorners: Hashable, Sendable {

    /// A radius, in points.
    case radius(CGFloat)

    /// Half the shorter side, as a capsule's and a circle's are.
    case capsule

    /// The corners of a shape. Backdrops are rounded rectangles, so other
    /// shapes get square corners under their tint.
    init(_ shape: some Shape) {
        switch shape {
        case let rounded as RoundedRectangle:
            self = .radius(max(min(rounded.cornerSize.width, rounded.cornerSize.height), 0))
        case is Capsule, is Circle:
            self = .capsule
        default:
            self = .radius(0)
        }
    }
}

/// A material in a shape: the backdrop, then the tint filling the shape.
internal struct _MaterialView<S: Shape>: View {

    let shape: S

    let material: Material

    @Environment(\.self) private var environment

    var body: some View {
        ZStack {
            _BackdropView(corners: MaterialCorners(shape))
            _ShapeView(shape: shape, style: material.tint(in: environment), drawing: .fill(FillStyle()))
        }
    }
}

/// What's drawn behind the view, blurred.
internal struct _BackdropView: View, PrimitiveView {

    let corners: MaterialCorners

    typealias Body = Never

    func resolve(in context: ResolveContext) -> Resolution {
        Resolution(behavior: BackdropBehavior(corners: corners))
    }
}

internal struct BackdropBehavior: NodeBehavior {

    let corners: MaterialCorners

    func sizeThatFits(_ proposal: ProposedViewSize, node: ViewNode) -> CGSize {
        proposal.replacingUnspecifiedDimensions()
    }

    func displayContent(node: ViewNode) -> DisplayList.Content? {
        let size = node.graph.presentationFrame(of: node).size
        let radius: CGFloat = switch corners {
        case let .radius(radius): min(radius, min(size.width, size.height) / 2)
        case .capsule: min(size.width, size.height) / 2
        }
        return .backdrop(BackdropContent(
            blurRadius: Material.blurRadius,
            saturation: Material.saturation,
            cornerRadius: radius
        ))
    }

    /// The tint over the backdrop takes the hits.
    func hitTest(_ point: CGPoint, node: ViewNode) -> Bool {
        false
    }
}
