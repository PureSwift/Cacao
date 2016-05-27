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
    
    public final var frame: Rect
        { didSet { layoutSubviews(); setNeedsDisplay() } }
    
    public final var backgroundColor: UIColor = UIColor(cgColor: Color.white)
        { didSet { setNeedsDisplay() } }
    
    public final var alpha: Double = 1.0
        { didSet { setNeedsDisplay() } }
    
    public final var hidden: Bool = false
        { didSet { setNeedsDisplay() } }
    
    public final var subviews: [UIView] = []
        { didSet { layoutSubviews(); setNeedsDisplay() } }
    
    public final var userInteractionEnabled: Bool = true
    
    public final var multipleTouchEnabled: Bool = false
    
    public final var contentMode = UIViewContentMode()
        { didSet { setNeedsDisplay() } }
    
    public final var tag: Int = 0
    
    // MARK: - Subclassable Properties
    
    public var intrinsicContentSize: Size {
        
        return frame.size
    }
    
    //public var needsLayout: Bool = false
    
    // MARK: - Initialization
    
    public init(frame: Rect = Rect()) {
        
        self.frame = frame
    }
    
    // MARK: - Subclassable Methods
    
    public func draw(_ rect: Rect) { /* implemented by subclasses */ }
    
    public func layoutSubviews() { /* implemented by subclasses */ }
    
    public func sizeThatFits(_ size: Size) -> Size {
        
        return frame.size
    }
    
    // MARK: - Final Methods
    
    public final func addSubview(_ subview: UIView) {
        
        assert(subview is UIWindow == false, "Cannot add UIWindow as a subview")
        
        subviews.append(subview)
    }
    
    public final func removeSubview(_ subview: UIView) {
        
        guard let subviewIndex = subviews.index(where: { $0 === subview })
            else { fatalError("Cannot remove subview that is not in the view hierarchy.") }
        
        subviews.remove(at: subviewIndex)
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

// MARK: - Supporting Types

public enum UIViewContentMode {
    
    public init() { self = .ScaleToFill }
    
    case ScaleToFill
    case ScaleAspectFit
    case ScaleAspectFill
    case Redraw
    case Center
    case Top
    case Bottom
    case Left
    case Right
    case TopLeft
    case TopRight
    case BottomLeft
    case BottomRight
}
