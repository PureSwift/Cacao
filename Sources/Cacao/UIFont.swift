//
//  UIFont.swift
//  Cacao
//
//  Created by Alsey Coleman Miller on 5/29/16.
//  Copyright © 2016 PureSwift. All rights reserved.
//

import Silica

public final class UIFont {
    
    // MARK: - Class Methods
    
    public static func labelFontSize() -> CGFloat { return 17 }
    
    // MARK: - Properties
    
    public var fontName: String { return CGFont.name }
    
    public var familyName: String { return CGFont.family }
    
    public let size: CGFloat
    
    public var CGFont: Silica.CGFont
    
    // MARK: - Initialization
    
    public init?(name: String, size: CGFloat) {
        
        guard let internalFont = Silica.Font(name: name)
            else { return nil }
        
        self.CGFont = internalFont
        self.size = size
    }
    
    // MARK: - Lazy Computed Properties
    
    public lazy var descender: Double = (Double(self.CGFont.scaledFont.descent) * self.size) / Double(self.CGFont.scaledFont.unitsPerEm)
    
    public lazy var ascender: Double = (Double(self.CGFont.scaledFont.ascent) * self.size) / Double(self.CGFont.scaledFont.unitsPerEm)
}

// MARK: - Supporting Types



