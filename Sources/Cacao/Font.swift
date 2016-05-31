//
//  Font.swift
//  Cacao
//
//  Created by Alsey Coleman Miller on 5/31/16.
//  Copyright © 2016 PureSwift. All rights reserved.
//

import Silica

public struct Font: Equatable {
    
    // MARK: - Properties
    
    public var silicaFont: Silica.Font { return storage.silicaFont }
    
    // MARK: Font Name Attributes
    
    public var name: String { return silicaFont.name }
    
    public var family: String { return silicaFont.family }
    
    // MARK: Font Metrics
    
    public var size: Double { return storage.size }
    
    public var descender: Double { return storage.descender }
    
    public var ascender: Double { return storage.ascender }
    
    // MARK: - Private Properties
    
    private let storage: Storage
    
    // MARK: - Initialization
    
    public init?(name: String, size: Double) {
        
        guard let silicaFont = Silica.Font(name: name)
            else { return nil }
        
        self.storage = Storage(silicaFont: silicaFont, size: size)
    }
}

// MARK: - Equatable

public func == (lhs: Font, rhs: Font) -> Bool {
    
    return lhs.name == rhs.name
        && lhs.size == rhs.size
}

// MARK: - Private

private extension Font {
    
    private final class Storage {
        
        // MARK: - Properties
        
        let silicaFont: Silica.Font
        
        let size: Double
        
        // MARK: - Initialization
        
        private init(silicaFont: Silica.Font, size: Double) {
            
            self.silicaFont = silicaFont
            self.size = size
        }
        
        // MARK: - Lazy Computed Properties
        
        lazy var descender: Double = (Double(self.silicaFont.scaledFont.descent) * self.size) / Double(self.silicaFont.scaledFont.unitsPerEm)
        
        lazy var ascender: Double = (Double(self.silicaFont.scaledFont.ascent) * self.size) / Double(self.silicaFont.scaledFont.unitsPerEm)
    }
}

