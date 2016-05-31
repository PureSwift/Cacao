//
//  TextRendering.swift
//  Cacao
//
//  Created by Alsey Coleman Miller on 5/31/16.
//  Copyright © 2016 PureSwift. All rights reserved.
//

import Silica

// MARK: - Methods

public extension String {
    
    func draw(in rect: Rect, context: Silica.Context, attributes: TextAttributes = TextAttributes()) {
        
        // set context values
        context.fontSize = attributes.font.size
        context.setFont(attributes.font.silicaFont)
        context.fillColor = attributes.color
        
        // render
        
        let textRect = self.contentFrame(for: rect, context: context, attributes: attributes)
        
        context.textPosition = textRect.origin
        
        context.show(text: self)
    }
    
    func singleLineWidth(font: Cacao.Font, context: Silica.Context) -> Double {
        
        let scaledFont = font.silicaFont.scaledFont
        
        let size = font.size
        
        let glyphs = self.unicodeScalars.map { scaledFont[UInt($0.value)] }
        
        let textWidth = context.advances(for: glyphs).reduce(Double(0), combine: { $0.0 +  $0.1.width })
        
        return textWidth
    }
    
    func contentFrame(for bounds: Rect, context: Silica.Context, attributes: TextAttributes = TextAttributes()) -> Rect {
        
        // calculate frame
        
        let scaledFont = attributes.font.silicaFont.scaledFont
        
        let glyphs = self.unicodeScalars.map { scaledFont[UInt($0.value)] }
        
        let textWidth = context.advances(for: glyphs).reduce(Double(0), combine: { $0.0 +  $0.1.width })
        
        var textRect = Rect(x: bounds.x, y: bounds.y, width: textWidth, height: attributes.font.size) // height == font.size
        
        switch attributes.paragraphStyle.alignment {
            
        case .left: break // always left by default
            
        case .center: textRect.x = (bounds.width - textRect.width) / 2
            
        case .right: textRect.x = bounds.width - textRect.width
        }
        
        return textRect
    }
}

// MARK: - Supporting Types

public struct TextAttributes {
    
    public init() { }
    
    public var font = Font(name: "Helvetica", size: 17)!
    
    public var color = Color.black
    
    public var paragraphStyle = ParagraphStyle()
}

public struct ParagraphStyle {
    
    public init() { }
    
    public var alignment = TextAlignment()
}

public enum TextAlignment {
    
    public init() { self = .left }
    
    case left
    case center
    case right
}

// MARK: - Extensions

public extension Silica.Context {
    
    func setTextAttributes(_ attributes: TextAttributes) {
        
        self.fontSize = attributes.font.size
        self.setFont(attributes.font.silicaFont)
        self.fillColor = attributes.color
    }
}
