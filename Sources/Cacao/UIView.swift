//
//  UIView.swift
//  Cacao
//
//  Created by Alsey Coleman Miller on 5/12/16.
//  Copyright © 2016 PureSwift. All rights reserved.
//

import Silica

public class UIView {
    
    // MARK: - Properties
    
    public var frame: Rect
    
    public var backgroundColor = UIColor(cgColor: Color.white)
    
    public var alpha: Double = 1.0
    
    public var hidden = false
    
    public var subviews: [UIView] = []
    
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
    
    // MARK: - Private Methods
    
    
}
