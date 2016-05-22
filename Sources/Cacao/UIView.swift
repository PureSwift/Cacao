//
//  UIView.swift
//  Cacao
//
//  Created by Alsey Coleman Miller on 5/12/16.
//  Copyright © 2016 PureSwift. All rights reserved.
//

import Silica

public class UIView: UIResponder {
    
    // MARK: - Properties
    
    public var frame: Rect
        { didSet { layoutSubviews(); setNeedsDisplay() } }
    
    public var backgroundColor = UIColor(cgColor: Color.white)
        { didSet { setNeedsDisplay() } }
    
    public var alpha: Double = 1.0
        { didSet { setNeedsDisplay() } }
    
    public var hidden = false
        { didSet { setNeedsDisplay() } }
    
    public var subviews: [UIView] = []
        { didSet { layoutSubviews(); setNeedsDisplay() } }
    
    public var userInteractionEnabled = true
    
    public var tag: Int = 0
    
    //public var needsLayout: Bool = false
    
    // MARK: - Initialization
    
    public init(frame: Rect = Rect()) {
        
        self.frame = frame
    }
    
    // MARK: - Subclassable Methods
    
    public func draw(_ rect: Rect) { /* implemented by subclasses */ }
    
    public func layoutSubviews() { /* implemented by subclasses */ }
    
    // MARK: - Final Methods
    
    public final func addSubview(_ subview: UIView) {
        
        subviews.append(subview)
    }
    
    public final func setNeedsDisplay() {
        
        UIScreen.main?.needsDisplay = true
    }
    
    public final func setNeedsLayout() {
        
        UIScreen.main?.needsLayout = true
        
        setNeedsDisplay()
    }
    
    // MARK: - Private Methods
    
    
}
