//
//  ScrollView.swift
//  Cacao
//
//  Created by Alsey Coleman Miller on 5/28/16.
//  Copyright © 2016 PureSwift. All rights reserved.
//

#if os(macOS)
    import Darwin.C.math
#elseif os(Linux)
    import Glibc
#endif

import struct Foundation.CGFloat
import struct Foundation.CGPoint
import struct Foundation.CGSize
import struct Foundation.CGRect
import Silica

open class UIScrollView: UIView {
    
    // MARK: - Initialization
    
    public override init(frame: CGRect) {
        super.init(frame: frame)
        
        let action = UIGestureRecognizer.TargetAction(action: self.panGesture, name: "panGesture")
        
        self.panGestureRecognizer = UIPanGestureRecognizer(targetAction: action)
        
        self.addGestureRecognizer(panGestureRecognizer)
    }
    
    // MARK: - Responding to Scroll View Interactions
    
    /// The delegate of the scroll-view object.
    public weak var delegate: UIScrollViewDelegate?
    
    // MARK: - Managing the Display of Content
    
    /// The point at which the origin of the content view is offset from the origin of the scroll view.
    public var contentOffset: CGPoint {
        get { return bounds.origin }
        set { setContentOffset(newValue, animated: false) }
    }
    
    /// Sets the offset from the content view’s origin that corresponds to the receiver’s origin.
    public func setContentOffset(_ contentOffset: CGPoint, animated: Bool) {
        
        if animated {
            var animation: UIScrollViewAnimationScroll? = nil
            if (scrollAnimation? is UIScrollViewAnimationScroll) {
                animation = (scrollAnimation as? UIScrollViewAnimationScroll)
            }
            if !animation || !theOffset.equalTo(animation?.endContentOffset) {
                _setScrollAnimation(UIScrollViewAnimationScroll(self, fromContentOffset: contentOffset, toContentOffset: theOffset, duration: UIScrollViewAnimationDuration, curve: UIScrollViewAnimationScrollCurveLinear))
            }
        }
        else {
            contentOffset.x = roundf(contentOffset.x)
            contentOffset.y = roundf(contentOffset.y)
            updateBounds()
            
            delegate?.scrollViewDidScroll(self)
        }
    }
    
    /// The size of the content view.
    public var contentSize: CGSize = .zero {
        
        didSet {  }
    }
    
    /// The distance that the content view is inset from the enclosing scroll view.
    ///
    /// Use this property to add to the scrolling area around the content.
    /// The unit of size is points. The default value is `.zero`.
    public var contentInset: UIEdgeInsets = .zero
    
    // MARK: - Managing Scrolling
    
    /// A Boolean value that determines whether scrolling is enabled.
    ///
    /// If the value of this property is `true`, scrolling is enabled, and if it is `false`,
    /// scrolling is disabled. The default is `true`. When scrolling is disabled,
    /// the scroll view does not accept touch events; it forwards them up the responder chain.
    public var isScrollEnabled: Bool = true
    
    public var scrollHorizontal: Bool = true
    
    public var scrollVertical: Bool = true
    
    // MARK: - Zooming and Panning
    
    /// The underlying gesture recognizer for pan gestures.
    ///
    /// Your application accesses this property when it wants to more precisely control
    /// which pan gestures are recognized by the scroll view.
    public private(set) var panGestureRecognizer: UIPanGestureRecognizer!
    
    // MARK: - Private
    
    private var dragging = false
    
    private func panGesture(_ gesture: UIGestureRecognizer) {
        
        if gesture === panGestureRecognizer {
            
            switch panGestureRecognizer.state {
                
            case .began:
                
                beginDragging()
                
            case .changed:
                
                let delta = panGestureRecognizer.translation(in: self)
                
                drag(by: delta)
                
            case .ended:
                
                break
                
            case .possible, .failed, .cancelled:
                
                break
            }
        }
    }
    
    private func beginDragging() {
        
        if dragging == false {
            
            
        }
    }
    
    private func drag(by delta: CGPoint) {
        
        let confinedDelta = confined(delta: delta, animated: false)
        
        scrollContent(confinedDelta, animated: false)
    }
    
    private func endDragging(velocity: CGPoint) {
        
        
    }
    
    private func confined(delta: CGPoint, animated: Bool) -> CGPoint {
        
        
    }
    
    private func scrollContent(_ delta: CGPoint, animated: Bool) {
        
        
    }
}

// MARK: - Supporting Types

/// The methods declared by the UIScrollViewDelegate protocol allow the adopting delegate
/// to respond to messages from the `UIScrollView` class and thus respond to,
/// and in some affect, operations such as scrolling, zooming, deceleration of scrolled content, and scrolling animations.
public protocol UIScrollViewDelegate: class {
    
    func scrollViewDidEndScrollingAnimation(_ scrollView: UIScrollView)
    
    func scrollViewDidScroll(_ scrollView: UIScrollView)
    
    func scrollViewWillBeginDragging(_ scrollView: UIScrollView)
    
    func scrollViewDidEndDragging(_ scrollView: UIScrollView, willDecelerate decelerate: Bool)
    
    func scrollViewWillBeginDecelerating(_ scrollView: UIScrollView)
    
    func scrollViewDidEndDecelerating(_ scrollView: UIScrollView)
    
    func viewForZooming(in scrollView: UIScrollView) -> UIView
    
    func scrollViewWillBeginZooming(_ scrollView: UIScrollView, withView view: UIView)
    
    func scrollViewDidEndZooming(_ scrollView: UIScrollView, with view: UIView, atScale scale: Float)
    
    func scrollViewDidZoom(_ scrollView: UIScrollView)
    
    func scrollViewShouldScrollToTop(_ scrollView: UIScrollView) -> Bool
}
