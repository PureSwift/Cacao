//
//  UITouchesEvent.swift
//  Cacao
//
//  Created by Alsey Coleman Miller on 11/19/17.
//

import Foundation

internal final class UITouchesEvent: UIEvent {
    
    public override var type: UIEventType { return .touches }
    
    public override var allTouches: Set<UITouch>? { return touches }
    
    internal private(set) var touches = Set<UITouch>()
    
    internal func addTouch(_ touch: UITouch) {
        
        touches.insert(touch)
        
        if let view = touch.view {
            
            addGestureRecognizers(for: view, to: touch)
        }
    }
    
    private func invalidateGestureRecognizerForWindowCache() {
        
        
    }
    
    private func addGestureRecognizers(for view: UIView, to touch: UITouch) {
        
        
    }
    
    internal func views(for window: UIWindow) -> Set<UIView> {
        
        let views = self.touches(for: window)?.compactMap { $0.view } ?? []
        return Set(views)
    }
    
    internal override func gestureRecognizers(for window: UIWindow) -> Set<UIGestureRecognizer> {
        
        let touches = self.touches(for: window) ?? []
        return Set(touches.reduce([], { $0 + ($1.gestureRecognizers ?? []) }))
    }
}
