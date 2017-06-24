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
    public var isScrollEnabled: Bool = true {
        
        didSet {
            panGestureRecognizer.isEnabled = isScrollEnabled
            updateScrollers()
            setNeedsLayout()
        }
    }
    
    /// A Boolean value that determines whether scrolling is disabled in a particular direction.
    ///
    /// If this property is false, scrolling is permitted in both horizontal and vertical directions.
    /// If this property is true and the user begins dragging in one general direction (horizontally or vertically),
    /// the scroll view disables scrolling in the other direction. If the drag direction is diagonal,
    /// then scrolling will not be locked and the user can drag in any direction until the drag completes.
    ///
    /// The default value is false
    public var isDirectionalLockEnabled: Bool = false
    
    /// A Boolean value that controls whether the scroll-to-top gesture is enabled.
    /// The scroll-to-top gesture is a tap on the status bar.
    public var scrollsToTop: Bool = true
    
    public var scrollHorizontal: Bool = true
    
    public var scrollVertical: Bool = true
    
    /// Scrolls a specific area of the content so that it is visible in the receiver.
    public func scrollRectToVisible(_ rect: CGRect, animated: Bool) {
        
        let contentRect = CGRect(x: 0,
                                 y: 0,
                                 width: CGFloat(contentSize.width),
                                 height: CGFloat(contentSize.height))
        
        let visibleRect = bounds
        var goalRect = rect.intersection(contentRect)
        
        if goalRect.isNull == false,
            visibleRect.contains(goalRect) == false {
            
            goalRect.size.width = min(goalRect.size.width, visibleRect.size.width)
            goalRect.size.height = min(goalRect.size.height, visibleRect.size.height)
            
            var offset = contentOffset
            
            if goalRect.maxY > visibleRect.maxY {
                offset.y += goalRect.maxY - visibleRect.maxY
            }
            else if goalRect.minY < visibleRect.minY {
                offset.y += goalRect.minY - visibleRect.minY
            }
            
            if goalRect.maxX > visibleRect.maxX {
                offset.x += goalRect.maxX - visibleRect.maxX
            }
            else if goalRect.minX < visibleRect.minX {
                offset.x += goalRect.minX - visibleRect.minX
            }
            
            setContentOffset(offset, animated: animated)
        }
    }
    
    /// A Boolean value that determines whether paging is enabled for the scroll view.
    ///
    /// If the value of this property is true,
    /// the scroll view stops on multiples of the scroll view’s bounds when the user scrolls.
    ///
    /// The default value is false.
    public var isPagingEnabled: Bool = false
    
    /// A Boolean value that controls whether the scroll view bounces past the edge of content and back again.
    ///
    /// If the value of this property is true, the scroll view bounces when it encounters a boundary of the content.
    /// Bouncing visually indicates that scrolling has reached an edge of the content.
    /// If the value is false, scrolling stops immediately at the content boundary without bouncing.
    ///
    /// The default value is true.
    public var bounces: Bool = true
    
    /// A Boolean value that determines whether bouncing always occurs when vertical scrolling reaches the end of the content.
    public var isAlwaysBounceVertical: Bool = false
    
    /// A Boolean value that determines whether bouncing always occurs when horizontal scrolling reaches the end of the content.
    public var isAlwaysBounceHorizontal: Bool = false
    
    /// Overridden by subclasses to customize the default behavior when a finger touches down in displayed content.
    public func touchesShouldBegin(_ touches: Set<UITouch>,
                                   with event: UIEvent?,
                                   in view: UIView) -> Bool {
        
        return true
    }
    
    
    /// Returns whether to cancel touches related to the content subview and start dragging.
    public func touchesShouldCancel(in view: UIView) -> Bool {
        
        return false
    }
    
    /// A Boolean value that controls whether touches in the content view always lead to tracking.
    public var canCancelContentTouches: Bool = true
    
    /// A Boolean value that determines whether the scroll view delays the handling of touch-down gestures.
    public var delaysContentTouches: Bool = true
    
    // MARK: - Zooming and Panning
    
    /// The underlying gesture recognizer for pan gestures.
    ///
    /// Your application accesses this property when it wants to more precisely control
    /// which pan gestures are recognized by the scroll view.
    public private(set) var panGestureRecognizer: UIPanGestureRecognizer!
    
    // MARK: - Private
    
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
    
    private func setRestrainedContentOffset(_ contentOffset: CGPoint) {
        
        var contentOffset = self.contentOffset
        let confinedOffset = confinedContentOffset(contentOffset)
        let scrollerBounds = UIEdgeInsetsInsetRect(bounds, contentInset)
        
        if isAlwaysBounceHorizontal == false,
            contentSize.width <= scrollerBounds.size.width {
            
            contentOffset.x = confinedOffset.x
        }
        
        if isAlwaysBounceVertical == false,
            contentSize.height <= scrollerBounds.size.height {
            
            contentOffset.y = confinedOffset.y
        }
        
        self.contentOffset = confinedOffset
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
