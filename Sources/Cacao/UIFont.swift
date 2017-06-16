//
//  UIFont.swift
//  Cacao
//
//  Created by Alsey Coleman Miller on 5/31/16.
//  Copyright © 2016 PureSwift. All rights reserved.
//

import struct Foundation.CGFloat
import Silica

public final class UIFont: Equatable {
    
    // MARK: - Properties
    
    public let cgFont: CGFont
    
    // MARK: Font Name Attributes
    
    public var fontName: String { return cgFont.name }
    
    public var familyName: String { return cgFont.family }
    
    // MARK: Font Metrics
    
    public let pointSize: CGFloat
    
    public lazy var descender: CGFloat = (CGFloat(self.cgFont.scaledFont.descent) * self.pointSize) / CGFloat(self.cgFont.scaledFont.unitsPerEm)
    
    public lazy var ascender: CGFloat = (CGFloat(self.cgFont.scaledFont.ascent) * self.pointSize) / CGFloat(self.cgFont.scaledFont.unitsPerEm)
    
    // MARK: - Initialization
    
    public init?(name: String, size: CGFloat) {
        
        guard let cgFont = CGFont(name: name)
            else { return nil }
        
        self.cgFont = cgFont
        self.pointSize = size
    }
}

// MARK: - Equatable

public func == (lhs: UIFont, rhs: UIFont) -> Bool {
    
    return lhs.fontName == rhs.fontName
        && lhs.pointSize == rhs.pointSize
}

