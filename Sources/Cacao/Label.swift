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
    
    public var font: Font
    
    // MARK: - Initialization
    
    public init(frame: Rect = Rect(), text: String = "", font: Cacao.Font? = nil) {
        
        self.frame = frame
        self.text = text
        self.font = font ?? Label.appearance.font
    }
    
    // MARK: - Draw
    
    public func draw(context: Context) {
        
        
    }
}

// MARK: - Appearance

public extension Label {
    
    public struct Appearance {
        
        public var font: Cacao.Font = Font(name: "Helvetica", size: 17)!
    }
}