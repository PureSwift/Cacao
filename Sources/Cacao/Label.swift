//
//  Label.swift
//  Cacao
//
//  Created by Alsey Coleman Miller on 5/29/16.
//  Copyright © 2016 PureSwift. All rights reserved.
//

import Silica

public final class Label: Drawable, Appearance {
    
    public static var appearance = Label.Appearance()
    
    // MARK: - Properties
    
    public var frame: Rect { didSet { layoutSubviews() } }
    
    public var userInteractionEnabled: Bool { return false }
    
    public var clipsToBounds: Bool { return false }
    
    public var hidden: Bool = false
    
    public var text: String
    
    public var font: Font = Label.appearance.font
    
    public var color: Color = Label.appearance.color
    
    public var textAlignment: TextAlignment = .left
    
    // MARK: - Initialization
    
    public init(frame: Rect = Rect(), text: String = "") {
        
        self.frame = frame
        self.text = text
    }
    
    // MARK: - Draw
    
    public func draw(context: Context) {
        
        let bounds = Rect(size: frame.size)
        
        var attributes = TextAttributes()
        attributes.font = font
        attributes.color = color
        attributes.paragraphStyle.alignment = textAlignment
        
        text.draw(in: bounds, context: context, attributes: attributes)
    }
    
    // MARK: - Size
    
    
}

// MARK: - Appearance

public extension Label {
    
    public struct Appearance {
        
        public var font: Cacao.Font = Font(name: "Helvetica", size: 17)!
        
        public var color: Color = Color.black
    }
}
