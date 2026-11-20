//
//  ProposedViewSize.swift
//  Cacao
//
//  Created by Alsey Coleman Miller on 11/13/26.
//

import CacaoRender
import Foundation
#if canImport(CoreGraphics)
import CoreGraphics
#endif

extension ProposedViewSize {

    internal subscript(axis: Axis) -> CGFloat? {
        get { axis == .horizontal ? width : height }
        set {
            if axis == .horizontal { width = newValue } else { height = newValue }
        }
    }

    internal init(_ major: CGFloat?, in axis: Axis, by minor: CGFloat?) {
        self = axis == .horizontal
            ? ProposedViewSize(width: major, height: minor)
            : ProposedViewSize(width: minor, height: major)
    }

    internal func inset(by insets: EdgeInsets) -> ProposedViewSize {
        ProposedViewSize(
            width: width.map { Swift.max($0 - insets.horizontal, 0) },
            height: height.map { Swift.max($0 - insets.vertical, 0) }
        )
    }
}
