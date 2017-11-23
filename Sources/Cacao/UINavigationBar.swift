//
//  UINavigationBar.swift
//  Cacao
//
//  Created by Alsey Coleman Miller on 6/12/17.
//

import struct Foundation.CGFloat
import struct Foundation.CGRect
import Silica

/// A control that supports navigation of hierarchical content, most often used in navigation controllers.
open class UINavigationBar: UIView {
    
    // MARK: - Initialization
    
    public override init(frame: CGRect) {
        super.init(frame: frame)
        
        // load view
        
    }
    
    // MARK: - Responding to Navigation Bar Changes
    
    /// The navigation bar’s delegate object.
    public weak var delegate: UINavigationBarDelegate?
    
    // MARK: - Pushing and Popping Items
    
    /// Pushes the given navigation item onto the navigation bar's stack and updates the UI.
    public func pushItem(_ item: UINavigationItem, animated: Bool) {
        
        var items = _items
        
        items.append(item)
        
        setItems(items, animated: animated)
    }
    
    /// Pops the top item from the navigation bar's stack and updates the UI.
    public func popItem(animated: Bool) -> UINavigationItem? {
        
        var items = _items
        
        let item = items.popLast()
        
        setItems(items, animated: animated)
        
        return item
    }
    
    /// Replaces the navigation items currently managed by the navigation bar with the specified items.
    public func setItems(_ items: [UINavigationItem]?, animated: Bool) {
        
        _items = items ?? []
        
        // change frames
        
    }
    
    /// An array of navigation items managed by the navigation bar.
    public var items: [UINavigationItem]? {
        
        get { return _items }
        
        @inline(__always)
        set { setItems(newValue, animated: false) }
    }
    
    private var _items = [UINavigationItem]()
    
    /// The navigation item at the top of the navigation bar’s stack.
    public var topItem: UINavigationItem? {
        
        return _items.last
    }
    
    /// The navigation item that is immediately below the topmost item on navigation bar’s stack.
    public var backItem: UINavigationItem? {
        
        let items = _items
        
        guard items.count >= 2
            else { return nil }
        
        let backItemIndex = items.count - 2
        
        return items[backItemIndex]
    }
    
    // MARK: - Customizing the Bar Appearance
    
    /// The image shown beside the back button.
    public var backIndicatorImage: UIImage?
    
    /// The image used as a mask for content during push and pop transitions.
    public var backIndicatorTransitionMaskImage: UIImage?
    
    /// The navigation bar style that specifies its appearance.
    ///
    /// It is permissible to set the value of this property when the navigation bar
    /// is being managed by a navigation controller object.
    public var barStyle: UIBarStyle = .default
    
    /// The tint color to apply to the navigation bar background.
    public var barTintColor: UIColor?
    
    /// The shadow image to be used for the navigation bar.
    public var shadowImage: UIImage?
    
    /// The tint color to apply to the navigation items and bar button items.
    //public var tintColor: UIColor
    
    /// The default value is true. If the navigation bar has a custom background image,
    /// the default is true if any pixel of the image has an alpha value of less than 1.0, and false otherwise.
    /// If you set this property to true on a navigation bar with an opaque custom background image,
    /// the navigation bar applies a system-defined opacity of less than 1.0 to the image.
    /// If you set this property to false on a navigation bar with a translucent custom background image,
    /// the navigation bar provides an opaque background for the image using black if the navigation bar has
    /// black style, white if the navigation bar has default , or the navigation bar’s barTintColor if a custom value is defined.
    public var isTranslucent: Bool = true
    
    /// Returns the background image for given bar metrics.
    public func backgroundImage(for barMetrics: UIBarMetrics) {
        
        
    }
    
    /// Sets the background image for given bar metrics.
    public func setBackgroundImage(_ image: UIImage?, for barMetrics: UIBarMetrics) {
        
        
    }
    
    /// Returns the background image to use for a given bar position and set of metrics.
    public func backgroundImage(for barPosition: UIBarPosition, barMetrics: UIBarMetrics) {
        
        
    }
    
    /// Sets the background image to use for a given bar position and set of metrics.
    public func setBackgroundImage(_ image: UIImage?, for barPosition: UIBarPosition, barMetrics: UIBarMetrics) {
        
        
    }
    
    /// Returns the title’s vertical position adjustment for given bar metrics.
    public func titleVerticalPositionAdjustment(for barMetrics: UIBarMetrics) {
        
        
    }
    
    /// Sets the title’s vertical position adjustment for given bar metrics.
    public func setTitleVerticalPositionAdjustment(_ adjustment: CGFloat, for barMetrics: UIBarMetrics) {
        
        
    }
    
    /// Display attributes for the bar’s title text.
    public var titleTextAttributes: [String : Any]?
}

// MARK: - Supporting Types

/// The UINavigationBarDelegate protocol defines optional methods that a `UINavigationBar`
/// delegate should implement to update its views when items are pushed and popped from the stack.
/// The navigation bar represents only the bar at the top of the screen, not the view below.
/// It’s the application’s responsibility to implement the behavior when the top item changes.
public protocol UINavigationBarDelegate: UIBarPositioningDelegate {
    
    /// Returns a Boolean value indicating whether the navigation bar should push an item.
    func navigationBar(_ navigationBar: UINavigationBar, shouldPush item: UINavigationItem) -> Bool
    
    /// Tells the delegate that an item was pushed onto the navigation bar.
    func navigationBar(_ navigationBar: UINavigationBar, didPush item: UINavigationItem)
    
    /// Returns a Boolean value indicating whether the navigation bar should pop an item.
    func navigationBar(_ navigationBar: UINavigationBar, shouldPop item: UINavigationItem) -> Bool
    
    /// Tells the delegate that an item was popped from the navigation bar.
    func navigationBar(_ navigationBar: UINavigationBar, didPop item: UINavigationItem)
}

public extension UINavigationBarDelegate {
    
    func navigationBar(_ navigationBar: UINavigationBar, shouldPush item: UINavigationItem) -> Bool {
        return true
    }
    
    func navigationBar(_ navigationBar: UINavigationBar, didPush item: UINavigationItem) { }
    
    func navigationBar(_ navigationBar: UINavigationBar, shouldPop item: UINavigationItem) -> Bool {
        return true
    }
    
    func navigationBar(_ navigationBar: UINavigationBar, didPop item: UINavigationItem) { }
}

