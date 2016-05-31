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
        context.setTextAttributes(attributes)
        
        // render
        let textRect = self.contentFrame(for: rect, textMatrix: context.textMatrix, attributes: attributes)
        
        context.textPosition = textRect.origin
        
        context.show(text: self)
    }
    
    func contentFrame(for bounds: Rect, textMatrix: AffineTransform = AffineTransform.identity, attributes: TextAttributes = TextAttributes()) -> Rect {
        
        // assume horizontal layout (not rendering non-latin languages)
        
        // calculate frame
        
        let textWidth = attributes.font.silicaFont.singleLineWidth(text: self, fontSize: attributes.font.size, textMatrix: textMatrix)
        
        let lines = 1
        
        let textHeight = attributes.font.size * Double(lines)
        
        var textRect = Rect(x: bounds.x, y: bounds.y, width: textWidth, height: textHeight) // height == font.size
        
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
