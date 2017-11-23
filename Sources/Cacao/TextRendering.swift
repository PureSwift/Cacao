//
//  TextRendering.swift
//  Cacao
//
//  Created by Alsey Coleman Miller on 5/31/16.
//  Copyright © 2016 PureSwift. All rights reserved.
//

import Foundation
import Silica

// MARK: - Methods

public extension String {
    
    func draw(in rect: CGRect, context: Silica.CGContext, attributes: TextAttributes = TextAttributes()) {
        
        // set context values
        context.setTextAttributes(attributes)
        
        // render
        let textRect = self.contentFrame(for: rect, textMatrix: context.textMatrix, attributes: attributes)
        
        context.textPosition = textRect.origin
        
        context.show(text: self)
    }
    
    func contentFrame(for bounds: CGRect, textMatrix: CGAffineTransform = .identity, attributes: TextAttributes = TextAttributes()) -> CGRect {
        
        // assume horizontal layout (not rendering non-latin languages)
        
        // calculate frame
        
        let textWidth = attributes.font.cgFont.singleLineWidth(text: self, fontSize: attributes.font.pointSize, textMatrix: textMatrix)
        
        let lines: CGFloat = 1.0
        
        let textHeight = attributes.font.pointSize * lines
        
        var textRect = CGRect(x: bounds.origin.x,
                              y: bounds.origin.y,
                              width: textWidth,
                              height: textHeight) // height == font.size
        
        switch attributes.paragraphStyle.alignment {
            
        case .left: break // always left by default
            
        case .center: textRect.origin.x = (bounds.width - textRect.width) / 2
            
        case .right: textRect.origin.x = bounds.width - textRect.width
        }
        
        return textRect
    }
}

// MARK: - Supporting Types

public struct TextAttributes {
    
    public init() { }
    
    public var font = UIFont(name: "Helvetica", size: 17)!
    
    public var color = UIColor.black
    
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

public extension Silica.CGContext {
    
    func setTextAttributes(_ attributes: TextAttributes) {
        
        self.fontSize = attributes.font.pointSize
        self.setFont(attributes.font.cgFont)
        self.fillColor = attributes.color.cgColor
    }
}
