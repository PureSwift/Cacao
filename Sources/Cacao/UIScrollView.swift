//
//  UIScrollView.swift
//  Cacao
//
//  Created by Alsey Coleman Miller on 5/28/16.
//  Copyright © 2016 PureSwift. All rights reserved.
//

#if os(macOS)
    import Darwin
#elseif os(Linux)
    import Glibc
#endif

import Foundation

#if os(iOS)
import UIKit
import CoreGraphics
#else
import Silica
#endif

open class UIScrollView: UIView {
    
    // MARK: - Initialization
    
    public override init(frame: CGRect) {
        super.init(frame: frame)
        
        self.addGestureRecognizer(panGestureRecognizer)
    }
    
    #if os(iOS)
    public required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    #endif
    
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
        
        //if animated { }
        
        _contentOffset.x = round(contentOffset.x)
        _contentOffset.y = round(contentOffset.y)
        updateBounds()
        
        delegate?.scrollViewDidScroll(self)
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
    public var refreshControl: UIRefreshControl? {
        
        didSet {
            
            
        }
    }
    
    // MARK: - Zooming and Panning
    
    /// The underlying gesture recognizer for pan gestures.
    ///
    /// Your application accesses this property when it wants to more precisely control
    /// which pan gestures are recognized by the scroll view.
    public var panGestureRecognizer: UIPanGestureRecognizer {
        return scrollGestureRecognizer
    }
    
    private lazy var scrollGestureRecognizer: UIScrollViewPanGestureRecognizer = {
        #if os(iOS)
        let gestureRecognizer = UIPanGestureRecognizer(target: self, action: #selector(_panGesture))
        #else
        let action = UIGestureRecognizer.TargetAction(action: self.panGesture, name: "panGesture")
        let gestureRecognizer = UIScrollViewPanGestureRecognizer(targetAction: action, scrollview: self)
        #endif
        return gestureRecognizer
    }()
    
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
    
    open override func addSubview(_ subview: UIView) {
        super.addSubview(subview)
        bringScrollersToFront()
    }
    
    open override func bringSubview(toFront subview: UIView) {
        super.bringSubview(toFront: subview)
        bringScrollersToFront()
    }
    
    open override func insertSubview(_ subview: UIView, at index: Int) {
        super.insertSubview(subview, at: index)
        bringScrollersToFront()
    }
    
    // MARK: - Private
    
    private static let bounceRatio: CGFloat = 0.30
    
    // Used for calculating delta
    private var previousTranslation: CGPoint?
    
    #if os(iOS)
    @objc private func _panGesture(_ gesture: UIGestureRecognizer) {
        panGesture(gesture)
    }
    #endif
    
    private func panGesture(_ gesture: UIGestureRecognizer) {
        
        guard gesture === panGestureRecognizer
            else { assertionFailure(); return }
        
        switch gesture.state {
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
    
    /*
    open override func wheelChanged(with event: UIWheelEvent) {
        
        beginDragging()
        drag(with: CGPoint(x: event.translation.width, y: event.translation.height))
        endDragging(velocity: .zero)
    }*/
    
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
        
        let originalOffset = contentOffset
        var proposedOffset = originalOffset
        proposedOffset.x -= delta.x
        proposedOffset.y -= delta.y
        let confinedOffset = confined(contentOffset: proposedOffset)
        
        if bounces {
            let shouldHorizontalBounce = (fabs(proposedOffset.x - confinedOffset.x) > 0)
            let shouldVerticalBounce = (fabs(proposedOffset.y - confinedOffset.y) > 0)
            if shouldHorizontalBounce {
                proposedOffset.x = originalOffset.x + (0.055 * delta.x)
            }
            if shouldVerticalBounce {
                proposedOffset.y = originalOffset.y + (0.055 * delta.y)
            }
            setRestrained(contentOffset: proposedOffset)
        }
        else {
            contentOffset = confinedOffset
        }
 
        contentOffset = confinedOffset
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
        setNeedsDisplay()
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
        
        self.contentOffset = confined(contentOffset: self.contentOffset)
    }
    
    private var canScrollHorizontal: Bool {
        
        return isScrollEnabled && (contentSize.width > bounds.size.width)
    }
    
    private var canScrollVertical: Bool {
        
        return isScrollEnabled && (contentSize.height > bounds.size.height)
    }
    
    private func confined(contentOffset: CGPoint) -> CGPoint {
        
        let scrollerBounds = UIEdgeInsetsInsetRect(bounds, contentInset)
        
        var contentOffset = contentOffset
        
        if bounces {
            
            // FIXME: Bounces scrolling
            
            // dont allow content offset lower than end of content
            let contentOffsetMax = CGPoint(x: contentSize.width - scrollerBounds.size.width,
                                           y: contentSize.height - scrollerBounds.size.height)
            
            if contentOffset.x > contentOffsetMax.x {
                contentOffset.x = contentOffsetMax.x
            }
            
            if contentOffset.y > contentOffsetMax.y {
                contentOffset.y = contentOffsetMax.y
            }
            
            // non-bouncing content offset
            contentOffset.x = max(contentOffset.x, 0)
            contentOffset.y = max(contentOffset.y, 0)
            
            // no scrolling if content size is smaller or exactly the size of the scroll view
            if contentSize.width <= scrollerBounds.size.width {
                contentOffset.x = 0
            }
            
            if contentSize.height <= scrollerBounds.size.height {
                contentOffset.y = 0
            }
            
        } else {
            
            // dont allow content offset lower than end of content
            let contentOffsetMax = CGPoint(x: contentSize.width - scrollerBounds.size.width,
                                           y: contentSize.height - scrollerBounds.size.height)
            
            if contentOffset.x > contentOffsetMax.x {
                contentOffset.x = contentOffsetMax.x
            }
            
            if contentOffset.y > contentOffsetMax.y {
                contentOffset.y = contentOffsetMax.y
            }
            
            // non-bouncing content offset
            contentOffset.x = max(contentOffset.x, 0)
            contentOffset.y = max(contentOffset.y, 0)
            
            // no scrolling if content size is smaller or exactly the size of the scroll view
            if contentSize.width <= scrollerBounds.size.width {
                contentOffset.x = 0
            }
            
            if contentSize.height <= scrollerBounds.size.height {
                contentOffset.y = 0
            }
        }
 
        return contentOffset
    }
    
    private func setRestrained(contentOffset: CGPoint) {
        
        var contentOffset = contentOffset
        
        let confinedOffset = confined(contentOffset: contentOffset)
        let scrollerBounds = UIEdgeInsetsInsetRect(bounds, contentInset)
        
        if isAlwaysBounceHorizontal == false,
            contentSize.width <= scrollerBounds.size.width {
            
            contentOffset.x = confinedOffset.x
        }
        
        if isAlwaysBounceVertical == false,
            contentSize.height <= scrollerBounds.size.height {
            
            contentOffset.y = confinedOffset.y
        }
        
        self.contentOffset = contentOffset
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
    
    func viewForZooming(in scrollView: UIScrollView) -> UIView?
    
    func scrollViewWillBeginZooming(_ scrollView: UIScrollView, withView view: UIView)
    
    func scrollViewDidEndZooming(_ scrollView: UIScrollView, with view: UIView, atScale scale: Float)
    
    func scrollViewDidZoom(_ scrollView: UIScrollView)
    
    func scrollViewShouldScrollToTop(_ scrollView: UIScrollView) -> Bool
}

public extension UIScrollViewDelegate {
    
    func scrollViewDidEndScrollingAnimation(_ scrollView: UIScrollView) { }
    
    func scrollViewDidScroll(_ scrollView: UIScrollView) { }
    
    func scrollViewWillBeginDragging(_ scrollView: UIScrollView) { }
    
    func scrollViewDidEndDragging(_ scrollView: UIScrollView, willDecelerate decelerate: Bool) { }
    
    func scrollViewWillBeginDecelerating(_ scrollView: UIScrollView) { }
    
    func scrollViewDidEndDecelerating(_ scrollView: UIScrollView) { }
    
    func viewForZooming(in scrollView: UIScrollView) -> UIView? { return nil }
    
    func scrollViewWillBeginZooming(_ scrollView: UIScrollView, withView view: UIView) { }
    
    func scrollViewDidEndZooming(_ scrollView: UIScrollView, with view: UIView, atScale scale: Float) { }
    
    func scrollViewDidZoom(_ scrollView: UIScrollView) { }
    
    func scrollViewShouldScrollToTop(_ scrollView: UIScrollView) -> Bool { return true }
}

#if os(iOS)
typealias UIScrollViewPanGestureRecognizer = UIPanGestureRecognizer
#else
// https://github.com/ceekay1991/iOS11RuntimeHeaders/blob/d01a3a0e5d725c6ec68ab6c8df0a3621056bed50/Frameworks/UIKit.framework/UIScrollViewPanGestureRecognizer.h
fileprivate final class UIScrollViewPanGestureRecognizer: UIPanGestureRecognizer {
    
    weak var scrollview: UIScrollView!
    
    var ignoreMouseEvents: Bool = false
    
    init(targetAction: TargetAction, scrollview: UIScrollView) {
        super.init(targetAction: targetAction)
        
        self.scrollview = scrollview
    }
    
    internal override func shouldTryToBegin(with event: UIEvent) {
        
        guard scrollview.scrollHorizontal
            else { return }
        
        
    }
}
#endif
