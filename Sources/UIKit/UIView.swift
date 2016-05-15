//
//  UIView.swift
//  Cacao
//
//  Created by Alsey Coleman Miller on 5/12/16.
//  Copyright © 2016 PureSwift. All rights reserved.
//

import SwiftCoreGraphics
import Silica
import Cacao

public class UIView: DrawableView {
    
    // MARK: - Properties
    
    public var frame: Rect
    
    public var backgroundColor: UIColor = UIColor(cgColor: Color.white)
    
    public var subviews: [View] = []
    
    // MARK: - Initialization
    
    public init(frame: Rect = Rect()) {
        
        self.frame = frame
    }
    
    // MARK: - Methods
    
    final public func draw(context: SwiftCoreGraphics.CGContext) {
        
        UIGraphicsPushContext(context)
        
        /// with (0,0) origin
        let bounds = Rect(size: frame.size)
        
        context.fillColor = backgroundColor.CGColor
        try! context.fill()
        
        self.draw(bounds)
        
        UIGraphicsPopContext()
    }
    
    public func draw(_ rect: Rect) { /* implemented by subclasses */ }
}
