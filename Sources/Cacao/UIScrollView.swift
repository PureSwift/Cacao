//
//  UIScrollView.swift
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
        get { return _contentOffset }
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
    
    /// A floating-point value that determines the rate of deceleration after the user lifts their finger.
    public var decelerationRate: CGFloat = UIScrollViewDecelerationRateNormal
    
    /// A Boolean value that indicates whether the user has begun scrolling the content.
    public private(set) var isDragging: Bool = false
    
    /// Returns whether the user has touched the content to initiate scrolling.
    public private(set) var isTracking: Bool = false
    
    /// Returns whether the content is moving in the scroll view after the user lifted their finger.
    public private(set) var isDecelerating: Bool = false
    
    /// The underlying gesture recognizer for directional button presses.
    //var directionalPressGestureRecognizer: UIGestureRecognizer
    
    // MARK: - Managing the Scroll Indicator and Refresh Control
    
    /// The style of the scroll indicators.
    public var indicatorStyle: UIScrollViewIndicatorStyle = .default {
        
        didSet {
            //horizontalScroller.indicatorStyle = style
            //verticalScroller.indicatorStyle = style
        }
    }
    
    /// The distance the scroll indicators are inset from the edge of the scroll view.
    public var scrollIndicatorInsets: UIEdgeInsets = .zero
    
    /// A Boolean value that controls whether the horizontal scroll indicator is visible.
    public var showsHorizontalScrollIndicator: Bool = true
    
    /// A Boolean value that controls whether the vertical scroll indicator is visible.
    public var showsVerticalScrollIndicator: Bool = true
    
    /// Displays the scroll indicators momentarily.
    public func flashScrollIndicators() {
        
        //horizontalScroller?.flash()
        //verticalScroller?.flash()
    }
    
    /// The refresh control associated with the scroll view.
    public var refreshControl: UIRefreshControl? = nil {
        
        didSet {
            
            
        }
    }
    
    // MARK: - Zooming and Panning
    
    /// The underlying gesture recognizer for pan gestures.
    ///
    /// Your application accesses this property when it wants to more precisely control
    /// which pan gestures are recognized by the scroll view.
    public private(set) var panGestureRecognizer: UIPanGestureRecognizer!
    
    // MARK: - Managing the Keyboard
    
    /// The manner in which the keyboard is dismissed when a drag begins in the scroll view.
    public var keyboardDismissMode: UIScrollViewKeyboardDismissMode = .none
    
    // MARK: - Overriden Methods
    
    open override func layoutSubviews() {
        super.layoutSubviews()
        
        //let scrollerSize = UIScrollerWidthForBoundsSize(bounds.size)
        
        //verticalScroller?.frame = CGRect(x: CGFloat(bounds.origin.x + bounds.size.width - scrollerSize - scrollIndicatorInsets.right), y: CGFloat(bounds.origin.y + scrollIndicatorInsets.top), width: scrollerSize, height: CGFloat(bounds.size.height - scrollIndicatorInsets.top - scrollIndicatorInsets.bottom))
        
        //horizontalScroller?.frame = CGRect(x: CGFloat(bounds.origin.x + scrollIndicatorInsets.left), y: CGFloat(bounds.origin.y + bounds.size.height - scrollerSize - scrollIndicatorInsets.bottom), width: CGFloat(bounds.size.width - scrollIndicatorInsets.left - scrollIndicatorInsets.right), height: scrollerSize)
        
        confineContent()
    }
    
    open override func didAddSubview(_ subview: UIView) {
        bringScrollersToFront()
    }
    
    public override func addSubview(_ subview: UIView) {
        super.addSubview(subview)
        bringScrollersToFront()
    }
    
    public override func bringSubview(toFront subview: UIView) {
        super.bringSubview(toFront: subview)
        bringScrollersToFront()
    }
    
    public override func insertSubview(_ subview: UIView, at index: Int) {
        super.insertSubview(subview, at: index)
        bringScrollersToFront()
    }
    
    // MARK: - Private
    
    private static let bounceRatio: CGFloat = 0.30
    
    // Used for calculating delta
    private var previousTranslation: CGPoint?
    
    private func panGesture(_ gesture: UIGestureRecognizer) {
        
        if gesture === panGestureRecognizer {
            
            switch panGestureRecognizer.state {
                
            case .began:
                
                beginDragging()
                
            case .changed:
                
                let translation = panGestureRecognizer.translation(in: self)
                
                drag(with: translation)
                
            case .ended:
                
                let velocity = panGestureRecognizer.velocity(in: self)
                
                endDragging(velocity: velocity)
                
            case .possible, .failed, .cancelled:
                
                break
            }
        }
    }
    
    private func beginDragging() {
        
        guard isDragging == false
            else { return }
        
        isDragging = true
        
        assert(previousTranslation == nil)
        
        //horizontalScroller?.alwaysVisible = true
        //verticalScroller?.alwaysVisible = true
        
        //cancelScrollAnimation()
        
        delegate?.scrollViewWillBeginDragging(self)
    }
    
    private func drag(with translation: CGPoint) {
        
        guard isDragging
            else { return }
        
        // Update scrollers
        //horizontalScroller?.alwaysVisible = true
        //verticalScroller?.alwaysVisible = true
        
        let delta: CGPoint
        
        if let previousTranslation = self.previousTranslation {
            
            delta = CGPoint(x: translation.x - previousTranslation.x,
                            y: translation.y - previousTranslation.y)
            
        } else {
            
            delta = translation
        }
        
        self.previousTranslation = translation
        
        let confinedDelta = confined(delta: delta, animated: false)
        
        scrollContent(confinedDelta, animated: false)
    }
    
    private func endDragging(velocity: CGPoint) {
        
        if isDragging {
            
            isDragging = false
            //let decelerationAnimation: UIScrollViewAnimation? = isPagingEnabled ? _pageSnapAnimation() : _decelerationAnimation(withVelocity: velocity)
            //delegate?.scrollViewDidEndDragging(self, willDecelerate: (decelerationAnimation != nil))
            if /* decelerationAnimation != nil */ false {
                
                //_setScroll(decelerationAnimation)
                //horizontalScroller?.alwaysVisible = true
                //verticalScroller?.alwaysVisible = true
                isDecelerating = true
                
                delegate?.scrollViewWillBeginDecelerating(self)
            }
            else {
                //horizontalScroller?.alwaysVisible = false
                //verticalScroller?.alwaysVisible = false
                confineContent()
            }
            
            previousTranslation = nil
        }
    }
    
    private func updateBounds() {
        
        self.bounds.origin = CGPoint(x: contentOffset.x - contentInset.left,
                                     y: contentOffset.y - contentInset.top)
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
    
    func bringScrollersToFront() {
        //super.bringSubview(toFront: horizontalScroller)
        //super.bringSubview(toFront: verticalScroller)
    }
    
    @inline(__always)
    private func confineContent() {
        
        //self.contentOffset = confined(contentOffset: self.contentOffset)
    }
    
    private var canScrollHorizontal: Bool {
        
        return isScrollEnabled && (contentSize.width > bounds.size.width)
    }
    
    private var canScrollVertical: Bool {
        
        return isScrollEnabled && (contentSize.height > bounds.size.height)
    }
    
    private func confined(delta: CGPoint, animated: Bool = false) -> CGPoint {
        
        let bounds = self.bounds
        
        let proposedOffset = CGPoint(x: CGFloat(self.contentOffset.x - delta.x), y: CGFloat(self.contentOffset.y - delta.y))
        let visibleBottomCorner = CGPoint(x: CGFloat(self.contentOffset.x + bounds.size.width), y: CGFloat(self.contentOffset.y + bounds.size.height))
        let proposedBottomCorner = CGPoint(x: CGFloat(proposedOffset.x + bounds.size.width), y: CGFloat(proposedOffset.y + bounds.size.height))
        let contentBounds = CGRect(x: CGFloat(0), y: CGFloat(0), width: CGFloat(self.contentSize.width), height: CGFloat(self.contentSize.height))
        if contentBounds.contains(proposedOffset) && contentBounds.contains(proposedBottomCorner) && !self.isPagingEnabled {
            return delta
        }
        var resultOrigin: CGPoint = proposedOffset
        let canScrollHorizontal = self.canScrollHorizontal
        let canScrollVertical = self.canScrollVertical
        if resultOrigin.x < 0 {
            
            if self.bounces && canScrollHorizontal && !animated {
                if fabs(resultOrigin.x) < bounds.size.width * UIScrollView.bounceRatio {
                    resultOrigin.x = self.contentOffset.x - (delta.x * UIScrollView.bounceRatio)
                }
                else {
                    resultOrigin.x = -bounds.size.width * UIScrollView.bounceRatio
                }
            }
            else {
                resultOrigin.x = 0
            }
        }
        else if resultOrigin.x > 0 && !canScrollHorizontal {
            resultOrigin.x = 0
        }
        
        if resultOrigin.y < 0 {
            if self.bounces && canScrollVertical && !animated {
                if fabs(resultOrigin.y) < bounds.size.height * UIScrollView.bounceRatio {
                    resultOrigin.y = self.contentOffset.y - (delta.y * UIScrollView.bounceRatio)
                    //resultOrigin.y = resultOrigin.y * UIScrollView.bounceRatio
                }
                else {
                    //resultOrigin.y = -bounds.size.height * UIScrollView.bounceRatio
                    resultOrigin.y = -bounds.size.height * UIScrollView.bounceRatio
                }
            }
            else {
                resultOrigin.y = 0
            }
        }
        else if resultOrigin.y > 0 && !canScrollVertical {
            resultOrigin.y = 0
        }
        
        var resultBottomCorner = proposedBottomCorner
        
        if proposedBottomCorner.x > self.contentSize.width {
            if self.bounces && canScrollHorizontal && !animated {
                if resultBottomCorner.x - self.contentSize.width < bounds.size.width * UIScrollView.bounceRatio {
                    resultBottomCorner.x = visibleBottomCorner.x - (delta.x * UIScrollView.bounceRatio)
                }
                else {
                    resultBottomCorner.x = self.contentSize.width + bounds.size.width * UIScrollView.bounceRatio
                }
            }
            else {
                resultBottomCorner.x = self.contentSize.width
            }
            resultOrigin = CGPoint(x: CGFloat(resultBottomCorner.x - bounds.size.width), y: CGFloat(resultOrigin.y))
        }
        if proposedBottomCorner.y > self.contentSize.height {
            
            if self.bounces && canScrollVertical && !animated {
                if resultBottomCorner.y - self.contentSize.height < bounds.size.height * UIScrollView.bounceRatio {
                    resultBottomCorner.y = visibleBottomCorner.y - (delta.y * UIScrollView.bounceRatio)
                }
                else {
                    resultBottomCorner.y = self.contentSize.height + bounds.size.height * UIScrollView.bounceRatio
                }
            }
            else {
                resultBottomCorner.y = self.contentSize.height
            }
            resultOrigin = CGPoint(x: CGFloat(resultOrigin.x), y: CGFloat(resultBottomCorner.y - bounds.size.height))
        }
        
        if self.isPagingEnabled && animated {
            if canScrollHorizontal {
                resultOrigin.x = round(resultOrigin.x / bounds.size.width) * bounds.size.width
            }
            if canScrollVertical {
                resultOrigin.y = round(resultOrigin.y / bounds.size.height) * bounds.size.height
            }
            
        }
        
        let result = CGPoint(x: CGFloat(self.contentOffset.x - resultOrigin.x), y: CGFloat(self.contentOffset.y - resultOrigin.y))
        
        return result
    }
    
    private func scrollContent(_ delta: CGPoint, animated: Bool = false) {
        
        let contentOffset = CGPoint(x: self.contentOffset.x + delta.x,
                                    y: self.contentOffset.y + delta.y)
        
        setContentOffset(contentOffset, animated: animated)
    }
}

// MARK: - Supporting Types

public let UIScrollViewDecelerationRateNormal: CGFloat = 0.998
public let UIScrollViewDecelerationRateFast: CGFloat = 0.99

public enum UIScrollViewIndicatorStyle: Int {
    
    public init() { self = .default }
    
    case `default`
    case black
    case white
}

public enum UIScrollViewKeyboardDismissMode {
    
    public init() { self = .none }
    
    /// The keyboard does not get dismissed with a drag.
    case none
    
    /// The keyboard is dismissed when a drag begins.
    case onDrag
    
    /// The keyboard follows the dragging touch offscreen, and can be pulled upward again to cancel the dismiss.
    case interactive
}

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
