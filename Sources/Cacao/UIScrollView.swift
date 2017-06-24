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
    private var _contentOffset: CGPoint = .zero
    
    /// Sets the offset from the content view’s origin that corresponds to the receiver’s origin.
    public func setContentOffset(_ contentOffset: CGPoint, animated: Bool) {
        
        if animated {/*
            var animation: UIScrollViewAnimationScroll? = nil
            if (scrollAnimation? is UIScrollViewAnimationScroll) {
                animation = (scrollAnimation as? UIScrollViewAnimationScroll)
            }
            if !animation || !theOffset.equalTo(animation?.endContentOffset) {
                _setScrollAnimation(UIScrollViewAnimationScroll(self, fromContentOffset: contentOffset, toContentOffset: theOffset, duration: UIScrollViewAnimationDuration, curve: UIScrollViewAnimationScrollCurveLinear))
            }*/
        }
        else {
            _contentOffset.x = round(contentOffset.x)
            _contentOffset.y = round(contentOffset.y)
            updateBounds()
            
            delegate?.scrollViewDidScroll(self)
        }
    }
    
    /// The size of the content view.
    public var contentSize: CGSize = .zero {
        
        didSet { confineContent() }
    }
    
    /// The distance that the content view is inset from the enclosing scroll view.
    ///
    /// Use this property to add to the scrolling area around the content.
    /// The unit of size is points. The default value is `.zero`.
    public var contentInset: UIEdgeInsets = .zero {
        
        didSet {
            
            guard oldValue != contentInset else { return }
            
            contentOffset.x -= contentInset.left - oldValue.left
            contentOffset.y -= contentInset.top - oldValue.top
            
            updateBounds()
        }
    }
    
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
    
    private func panGesture(_ gesture: UIGestureRecognizer) {
        
        if gesture === panGestureRecognizer {
            
            
        }
    }
    
    private func updateBounds() {
        
        self.bounds.origin = CGPoint(x: contentOffset.x - contentInset.left, y: contentOffset.y - contentInset.top)
        updateScrollers()
        setNeedsLayout()
    }
    
    private func updateScrollers() {
        /*
        verticalScroller?.contentSize = contentSize.height
        verticalScroller?.contentOffset = contentOffset.y
        horizontalScroller?.contentSize = contentSize.width
        horizontalScroller?.contentOffset = contentOffset.x
        verticalScroller?.isHidden = !canScrollVertical
        horizontalScroller?.isHidden = !canScrollHorizontal
         */
    }
    
    @inline(__always)
    private func confineContent() {
        
        self.contentOffset = confinedContentOffset(self.contentOffset)
    }
    
    private func confinedContentOffset(_ contentOffset: CGPoint) -> CGPoint {
        
        var contentOffset = contentOffset
        
        let scrollerBounds = UIEdgeInsetsInsetRect(bounds, contentInset)
        if (contentSize.width - contentOffset.x) < scrollerBounds.size.width {
            contentOffset.x = (contentSize.width - scrollerBounds.size.width)
        }
        if (contentSize.height - contentOffset.y) < scrollerBounds.size.height {
            contentOffset.y = (contentSize.height - scrollerBounds.size.height)
        }
        contentOffset.x = max(contentOffset.x, 0)
        contentOffset.y = max(contentOffset.y, 0)
        if contentSize.width <= scrollerBounds.size.width {
            contentOffset.x = 0
        }
        if contentSize.height <= scrollerBounds.size.height {
            contentOffset.y = 0
        }
        return contentOffset
    }
    
    private func setRestrainedContentOffset(_ offset: CGPoint) {
        
        let confinedOffset = confinedContentOffset(offset)
        let scrollerBounds = UIEdgeInsetsInsetRect(bounds, contentInset)
        /*
        if !isAlwaysBounceHorizontal && contentSize.width <= scrollerBounds.size.width {
            offset.x = confinedOffset.x
        }
        
        if !isAlwaysBounceVertical && contentSize.height <= scrollerBounds.size.height {
            offset.y = confinedOffset.y
        }
        */
        self.contentOffset = offset
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
