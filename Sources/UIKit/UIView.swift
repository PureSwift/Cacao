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

public class UIView: View {
    
    // MARK: - Properties
    
    public var frame: Rect
    
    public var backgroundColor: UIColor = UIColor(cgColor: Color.white)
    
    public var subviews: [View] = []
    
    public var needsLayout: Bool = false
    
    // MARK: - Initialization
    
    public init(frame: Rect = Rect()) {
        
        self.frame = frame
    }
    
    // MARK: - Methods
    
    final public func draw(context: Silica.Context) {
        
        UIGraphicsPushContext(context)
        
        /// with (0,0) origin
        let bounds = Rect(size: frame.size)
        
        drawBackgroundColor(context: context)
        
        self.draw(bounds)
        
        UIGraphicsPopContext()
    }
    
    public func draw(_ rect: Rect) { /* implemented by subclasses */ }
    
    public func layoutSubviews() { }
    
    // MARK: - Private Methods
    
    private func drawBackgroundColor(context: Context) {
        
        context.fillColor = backgroundColor.CGColor
        context.add(rect: Rect(size: frame.size))
        try! context.fill()
    }
}
