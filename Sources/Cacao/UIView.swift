//
//  UIView.swift
//  Cacao
//
//  Created by Alsey Coleman Miller on 5/27/16.
//  Copyright © 2016 PureSwift. All rights reserved.
//

import Foundation
import CSDL2
import SDL
import Silica
import Cairo

/// An object that represents a rectangular area on the screen and manages the content in that area.
///
/// At runtime, a view object handles the rendering of any content in its area and also handles any interactions
/// with that content. The `UIView` class itself provides basic behavior for filling its rectangular area
/// with a background color. More sophisticated content can be presented by subclassing `UIView`
/// and implementing the necessary drawing and event-handling code yourself.
open class UIView: UIResponder {
    
    // MARK: - Initializing a View Object
    
    deinit {
        
        removeAllGestureRecognizers()
    }
    
    public override convenience init() {
        
        self.init(frame: .zero)
    }
    
    /// Initializes and returns a newly allocated view object with the specified frame rectangle.
    public init(frame: CGRect) {
        
        super.init()
        
        self.frame = frame
    }
    
    // MARK: - CustomStringConvertible
    /*
    open override var description: String {
        
        return String(format: "<%@: %p; frame = %@; hidden = %@; layer = %@>", NSStringFromClass(type(of: self)) as! NSString, self, "\(self.frame)", (self.isHidden ? "YES" : "NO"), "\(self.texture ?? "nil" as Any)")
    }*/
    
    // MARK: - Properties
    
    // MARK: - Configuring a View’s Visual Appearance
    
    /// The view’s background color.
    ///
    /// The default value is `nil`, which results in a transparent background color.
    public final var backgroundColor: UIColor? { didSet { setNeedsDisplay() } }
    
    /// A Boolean value that determines whether the view is hidden.
    ///
    /// Setting the value of this property to true hides the receiver
    /// and setting it to false shows the receiver. The default value is false.
    ///
    /// A hidden view disappears from its window and does not receive input events.
    /// It remains in its superview’s list of subviews, however, and participates in autoresizing as usual.
    /// Hiding a view with subviews has the effect of hiding those subviews and any view descendants they might have.
    /// This effect is implicit and does not alter the hidden state of the receiver’s descendants.
    ///
    /// Hiding the view that is the window’s current first responder
    /// causes the view’s next valid key view to become the new first responder.
    ///
    /// The value of this property reflects the state of the receiver only
    /// and does not account for the state of the receiver’s ancestors in the view hierarchy.
    /// Thus this property can be false but the receiver may still be hidden if an ancestor is hidden.
    public final var isHidden: Bool = false { didSet { setNeedsDisplay() } }
    
    /// The view’s alpha value.
    ///
    /// The value of this property is a floating-point number in the range 0.0 to 1.0,
    /// where 0.0 represents totally transparent and 1.0 represents totally opaque.
    /// This value affects only the current view and does not affect any of its embedded subviews.
    public final var alpha: CGFloat = 1.0 { didSet { setNeedsDisplay() } }
    
    /// A Boolean value that determines whether the view is opaque.
    ///
    /// This property provides a hint to the drawing system as to how it should treat the view.
    /// If set to true, the drawing system treats the view as fully opaque,
    /// which allows the drawing system to optimize some drawing operations and improve performance.
    /// If set to false, the drawing system composites the view normally with other content.
    /// The default value of this property is true.
    ///
    /// An opaque view is expected to fill its bounds with entirely opaque content—that is,
    /// the content should have an alpha value of 1.0.
    /// If the view is opaque and either does not fill its bounds
    /// or contains wholly or partially transparent content, the results are unpredictable.
    /// You should always set the value of this property to false if the view is fully or partially transparent.
    ///
    /// You only need to set a value for the opaque property in subclasses of `UIView`
    /// that draw their own content using the `draw(_:)` method.
    /// The opaque property has no effect in system-provided classes such as `UIButton`, `UILabel`, `UITableViewCell`, and so on.
    public final var isOpaque: Bool = true { didSet { setNeedsDisplay() } }
    
    /// The first nondefault tint color value in the view’s hierarchy, ascending from and starting with the view itself.
    ///
    /// If the system cannot find a nondefault color in the hierarchy, this property’s value is a system-defined color instead.
    ///
    /// If the view’s tintAdjustmentMode property’s value is dimmed, then the tintColor property value is automatically dimmed.
    ///
    /// To refresh subview rendering when this property changes, override the `tintColorDidChange()` method.
    public final var tintColor: UIColor! {
        
        get {
            if let tintColor = _tintColor {
                return tintColor
            }
            
            // TODO
            return UIColor.blue
        }
        
        set {
            
            _tintColor = newValue
        }
        
    }
    private var _tintColor: UIColor?
    
    /// Called by the system when the `tintColor` property changes.
    ///
    /// The system calls this method on a view when your code changes the value of the `tintColor` property on that view.
    /// In addition, the system calls this method on a subview that inherits a changed interaction tint color.
    ///
    /// In your implementation, refresh the view rendering as needed.
    open func tintColorDidChange() {
        
        setNeedsDisplay()
    }
    
    //var tintAdjustmentMode: UIViewTintAdjustmentMode
    
    /// A Boolean value that determines whether subviews are confined to the bounds of the view.
    ///
    /// Setting this value to `true` causes subviews to be clipped to the bounds of the receiver.
    /// If set to false, subviews whose frames extend beyond the visible bounds of the receiver are not clipped.
    ///
    /// The default value is false.
    public final var clipsToBounds: Bool = false { didSet { setNeedsDisplay() } }
    
    /// A Boolean value that determines whether the view’s bounds should be automatically cleared before drawing.
    ///
    /// When set to true, the drawing buffer is automatically cleared to transparent black
    /// before the `draw(_:`) method is called. This behavior ensures that there are no visual artifacts left
    /// over when the view’s contents are redrawn. If the view’s `isOpaque` property is also set to `true`,
    /// the `backgroundColor` property of the view must not be nil or drawing errors may occur.
    ///
    /// The default value of this property is true.
    ///
    /// If you set the value of this property to false,
    /// you are responsible for ensuring the contents of the view are drawn properly in your `draw(_:)` method.
    /// If your drawing code is already heavily optimized, setting this property is false can improve performance,
    /// especially during scrolling when only a portion of the view might need to be redrawn.
    public final var clearsContextBeforeDrawing: Bool = true
    
    /// An optional view whose alpha channel is used to mask a view’s content.
    ///
    /// The view’s alpha channel determines how much of the view’s content and background shows through.
    /// Fully or partially opaque pixels allow the underlying content to show through
    /// but fully transparent pixels block that content.
    public final var mask: UIView?
    
    /// Returns the class used to create the layer for instances of this class.
    //class var layerClass: AnyClass
    
    /// The view’s Core Animation layer used for rendering.
    //var layer: CALayer
    
    // MARK: - Configuring the Event-Related Behavior
    
    /// A Boolean value that determines whether user events are ignored and removed from the event queue.
    ///
    /// When set to false, touch, press, keyboard, and focus events intended for the view
    /// are ignored and removed from the event queue. When set to true, events are delivered to the view normally.
    ///
    /// The default value of this property is `true`.
    public final var isUserInteractionEnabled: Bool = true
    
    /// When set to `true`, the receiver receives all touches associated with a multi-touch sequence.
    /// When set to `false`, the receiver receives only the first touch event in a multi-touch sequence.
    /// The default value of this property is `false`.
    ///
    /// Other views in the same window can still receive touch events when this property is `false.`
    /// If you want this view to handle multi-touch events exclusively,
    /// set the values of both this property and the `isExclusiveTouch property` to `true`.
    public final var isMultipleTouchEnabled: Bool = false
    
    /// A Boolean value that indicates whether the receiver handles touch events exclusively.
    ///
    /// Setting this property to true causes the receiver to block the delivery
    /// of touch events to other views in the same window.
    ///
    /// The default value of this property is false.
    public final var isExclusiveTouch: Bool = false
    
    // MARK: - Configuring the Bounds and Frame Rectangles
    
    /// The frame rectangle, which describes the view’s location and size in its superview’s coordinate system.
    ///
    /// This rectangle defines the size and position of the view in its superview’s coordinate system.
    /// You use this rectangle during layout operations to size and position the view.
    /// Setting this property changes the point specified by the center property
    /// and the size in the bounds rectangle accordingly.
    /// The coordinates of the frame rectangle are always specified in points.
    ///
    /// - Warning: If the transform property is not the identity transform,
    /// the value of this property is undefined and therefore should be ignored.
    open var frame: CGRect {
        get { return _frame }
        set {
            let oldValue = _bounds
            _frame = newValue
            _bounds.size = newValue.size
            boundsDidChange(from: oldValue, to: newValue)
        }
    }
    private var _frame = CGRect()
    
    /// The bounds rectangle, which describes the view’s location and size in its own coordinate system.
    ///
    /// On the screen, the bounds rectangle represents the same visible portion of the view as its frame rectangle.
    /// By default, the origin of the bounds rectangle is set to `(0, 0)`
    /// but you can change this value to display different portions of the view.
    /// The size of the bounds rectangle is coupled to the size of the frame rectangle,
    /// so that changes to one affect the other.
    /// Changing the bounds size grows or shrinks the view relative to its center point.
    /// The coordinates of the bounds rectangle are always specified in points.
    ///
    /// Changing the frame rectangle automatically redisplays the receiver without invoking the `draw(_:)` method.
    /// If you want the `draw(_:)` method invoked when the frame rectangle changes, set the `contentMode` property to `redraw`.
    ///
    ///
    /// The default bounds origin is `(0,0)` and the size is the same as the frame rectangle’s size.
    public final var bounds: CGRect {
        get { return _bounds }
        set {
            let oldValue = _bounds
            _bounds = newValue
            _frame.size = newValue.size
            boundsDidChange(from: oldValue, to: newValue)
        }
    }
    private var _bounds = CGRect()
    
    private func boundsDidChange(from oldBounds: CGRect, to newBounds: CGRect) {
        
        // bounds changed
        guard oldBounds != newBounds else { return }
        
        // FIXME: Do the docs state this happens?
        setNeedsLayout()
        
        // Autoresize subviews
        if autoresizesSubviews, oldBounds.size != newBounds.size {
            
            subviews.forEach { $0.frame.resize($0.autoresizingMask, containerSize: (oldBounds.size, newBounds.size)) }
        }
    }
    
    /// The center of the frame.
    ///
    /// The center is specified within the coordinate system of its superview and is measured in points.
    /// Setting this property changes the values of the frame properties accordingly.
    public final var center: CGPoint {
        get {
            return CGPoint(x: _frame.origin.x + (_frame.size.width / 2),
                           y: _frame.origin.y + (_frame.size.height / 2))
        }
        set {
            // adjust frame
            let oldValue = self.center
            _frame.origin.x += newValue.x - oldValue.x
            _frame.origin.y += newValue.y - oldValue.y
        }
    }
    
    /// Specifies the transform applied to the receiver, relative to the center of its bounds.
    ///
    /// The origin of the transform is the value of the `center` property,
    ///
    /// The default value is `CGAffineTransformIdentity`.
    public final var transform: CGAffineTransform = .identity {
        didSet { /* TODO */ }
    }
    
    // MARK: - Managing the View Hierarchy
    
    /// The receiver’s superview, or nil if it has none.
    public final private(set) weak var superview: UIView?
    
    /// The receiver’s immediate subviews.
    ///
    /// You can use this property to retrieve the subviews associated with your custom view hierarchies.
    /// The order of the subviews in the array reflects their visible order on the screen,
    /// with the view at index 0 being the back-most view.
    public final private(set) var subviews: [UIView] = []
    
    /// The receiver’s window object, or nil if it has none.
    ///
    /// This property is nil if the view has not yet been added to a window.
    public final var window: UIWindow? {
        
        return rootSuperview as? UIWindow
    }
    
    /// The root view in the hierarchy.
    private var rootSuperview: UIView {
        
        var superview: UIView = self
        var superViewFound = true
        
        repeat {
            
            if let newValue = superview.superview {
                
                superview = newValue
                
            } else {
                
                superViewFound = false
            }
            
        } while superViewFound
        
        return superview
    }
    
    /// Adds a view to the end of the receiver’s list of subviews.
    ///
    /// This method establishes a strong reference to view and sets its next responder to the receiver,
    /// which is its new superview.
    ///
    /// Views can have only one superview.
    /// If view already has a superview and that view is not the receiver,
    /// this method removes the previous superview before making the receiver its new superview.
    ///
    /// - Parameter view: The view to be added. After being added, this view appears on top of any other subviews.
    public func addSubview(_ view: UIView) {
        
        addSubview(view, { $0.append($1) })
    }
    
    @inline(__always)
    private func addSubview(_ view: UIView, _ body: (inout [UIView], UIView) -> ()) {
        
        let oldWindow = view.window
        let newWindow = self.window
        
        // remove from previous superview
        if view.superview !== self {
            view.removeFromSuperview()
        }
        
        // store subview in array
        body(&subviews, view)
        
        view.willMove(toSuperview: self)
        
        // set super view weak reference
        view.superview = self
        
        // inform view of change
        if oldWindow?.screen !== newWindow?.screen {
            didMoveToScreen()
        }
        view.didMoveToSuperview()
        didAddSubview(view)
        
        // force redraw
        setNeedsDisplay()
    }
    
    private func willMove(fromWindow: UIWindow?, toWindow: UIWindow?) {
        
        guard fromWindow !== toWindow
            else { return }
        
        if isFirstResponder {
            let _ = resignFirstResponder()
        }
        
        willMove(toWindow: toWindow)
        
        subviews.forEach { $0.willMove(fromWindow: fromWindow, toWindow: toWindow) }
        
        viewController?.beginAppearanceTransition(toWindow != nil, animated: false)
    }
    
    private func didMove(fromWindow: UIWindow?, toWindow: UIWindow?) {
        
        guard fromWindow !== toWindow
            else { return }
        
        
    }
    
    private func didMoveToScreen() {
        
        //self.contentScaleFactor = self.window.screen.scale
        self.setNeedsDisplay()
        
        self.subviews.forEach { $0.didMoveToScreen() }
    }
    
    /// Moves the specified subview so that it appears on top of its siblings.
    ///
    /// This method moves the specified view to the end of the array of views in the subviews property.
    ///
    /// - Parameter view: The subview to move to the front.
    public func bringSubview(toFront view: UIView) {
        
        assert(subviews.contains(where: { $0 === view }), "\(view) is not a subview of \(self)")
        
        guard let index = subviews.index(where: { $0 === view })
            else { return }
        
        subviews.remove(at: index)
        
        subviews.append(view)
    }
    
    /// Moves the specified subview so that it appears behind its siblings.
    ///
    /// This method moves the specified view to the beginning of the array of views in the subviews property.
    ///
    /// - Parameter view: The subview to move to the back.
    public final func sendSubview(toBack view: UIView) {
        
        assert(subviews.contains(where: { $0 === view }), "\(view) is not a subview of \(self)")
        
        guard let index = subviews.index(where: { $0 === view })
            else { return }
        
        subviews.remove(at: index)
        
        subviews.insert(view, at: 0)
    }
    
    /// Unlinks the view from its superview and its window, and removes it from the responder chain.
    ///
    /// If the view’s superview is not `nil`, the superview releases the view.
    ///
    /// - Note: Calling this method removes any constraints that refer to the view you are removing,
    /// or that refer to any view in the subtree of the view you are removing.
    public final func removeFromSuperview() {
        
        guard let index = superview?.subviews.index(where: { $0 === self })
            else { return }
        
        superview?.willRemoveSubview(self)
        
        superview?.subviews.remove(at: index)
    }
    
    /// Inserts a subview at the specified index.
    ///
    /// - Parameter view: The view to insert. This value cannot be nil.
    /// - Parameter index: The index in the array of the subviews property at which to insert the view.
    /// Subview indices start at 0 and cannot be greater than the number of subviews.
    ///
    /// This method establishes a strong reference to view and sets its next responder to the receiver,
    /// which is its new superview.
    ///
    /// Views can have only one superview.
    /// If view already has a superview and that view is not the receiver,
    /// this method removes the previous superview before making the receiver its new superview.
    public func insertSubview(_ view: UIView, at index: Int) {
        
        addSubview(view, { $0.insert($1, at: index) })
    }
    
    /// Inserts a view above another view in the view hierarchy.
    public final func insertSubview(_ view: UIView, aboveSubview siblingSubview: UIView) {
        
        guard let _ = subviews.index(where: { $0 === siblingSubview })
            else { return }
        
        addSubview(view, { $0 = $0 + [$1] })
    }
    
    /// Inserts a view below another view in the view hierarchy.
    public final func insertSubview(_ view: UIView, belowSubview siblingSubview: UIView) {
        
        guard let _ = subviews.index(where: { $0 === siblingSubview })
            else { return }
        
        addSubview(view, { $0 = [$1] + $0 })
    }
    
    /// Exchanges the subviews at the specified indices.
    public final func exchangeSubview(at index1: Int, withSubviewAt index2: Int) {
        
        subviews.swapAt(index1, index2)
    }
    
    /// Returns a Boolean value indicating whether the receiver is a subview of a given view or identical to that view.
    public final func isDescendant(of view: UIView) -> Bool {
        
        var superview: UIView?
        
        repeat {
            
            superview = self.superview
            
            if superview === view { return true }
            
        } while superview != nil
        
        return false
    }
    
    // MARK: - Configuring the Resizing Behavior
    
    /// A flag used to determine how a view lays out its content when its bounds change
    public final var contentMode: UIViewContentMode = .scaleAspectFill { didSet { setNeedsDisplay() } }
    
    /// Asks the view to calculate and return the size that best fits the specified size.
    ///
    /// The default implementation of this method returns the existing size of the view.
    /// Subclasses can override this method to return a custom value based on the desired layout of any subviews.
    /// For example, a `UISwitch` object returns a fixed size value that represents the standard size of a switch view,
    /// and a `UIImageView` object returns the size of the image it is currently displaying.
    ///
    /// - Note: This method does not resize the receiver.
    open func sizeThatFits(_ size: CGSize) -> CGSize {
        
        return bounds.size
    }
    
    /// Resizes and moves the receiver view so it just encloses its subviews.
    ///
    /// Call this method when you want to resize the current view so that it uses the most appropriate amount of space.
    /// Specific views resize themselves according to their own internal needs.
    /// In some cases, if a view does not have a superview, it may size itself to the screen bounds.
    /// Thus, if you want a given view to size itself to its parent view,
    /// you should add it to the parent view before calling this method.
    ///
    /// - Note: You should not override this method.
    /// If you want to change the default sizing information for your view, override the `sizeThatFits(_:)` instead.
    /// That method performs any needed calculations and returns them to this method, which then makes the change.
    public final func sizeToFit() {
        
        // TODO: sizeToFit
    }
    
    /// The natural size for the receiving view, considering only properties of the view itself.
    ///
    /// Custom views typically have content that they display of which the layout system is unaware.
    /// Setting this property allows a custom view to communicate to the layout system
    /// what size it would like to be based on its content.
    /// This intrinsic size must be independent of the content frame,
    /// because there’s no way to dynamically communicate a changed width to the
    /// layout system based on a changed height, for example.
    ///
    /// If a custom view has no intrinsic size for a given dimension,
    /// it can use `UIViewNoIntrinsicMetric` for that dimension.
    open var intrinsicContentSize: CGSize {
        
        return CGSize(width: UIViewNoIntrinsicMetric, height: UIViewNoIntrinsicMetric)
    }
    
    /// A Boolean value that determines whether the receiver automatically resizes its subviews when its bounds change.
    ///
    /// When set to `true`, the receiver adjusts the size of its subviews when its bounds change.
    /// The default value is `true`.
    public var autoresizesSubviews: Bool = true
    
    /// An integer bit mask that determines how the receiver resizes itself when its superview’s bounds change.
    ///
    /// When a view’s bounds change, that view automatically resizes its subviews according to each subview’s autoresizing mask.
    public var autoresizingMask: UIViewAutoresizing = []
    
    // MARK: - Identifying the View at Runtime
    
    /// An integer that you can use to identify view objects in your application.
    public final var tag: Int = 0
    
    /// Returns the view whose tag matches the specified value.
    ///
    /// This method searches the current view and all of its subviews for the specified view.
    ///
    /// - Returns: The view in the receiver’s hierarchy whose tag property matches the value in the tag parameter.
    public final func viewWithTag(_ tag: Int) -> UIView? {
        
        if self.tag == tag {
            
            return self
            
        } else {
            
            for view in subviews {
                
                if let tagView = view.viewWithTag(tag) {
                    
                    return tagView
                }
            }
        }
        
        return nil
    }
    
    // MARK: - Converting Between View Coordinate Systems
    
    /// Converts a point from the receiver’s coordinate system to that of the specified view.
    public final func convert(_ point: CGPoint, to view: UIView?) -> CGPoint {
        
        let rootSuperview = self.rootSuperview
        
        let view = view ?? rootSuperview
        
        assert(view.rootSuperview === rootSuperview, "Both views must descend from same root super view or window")
        
        // get origin offset for both views
        let offset = rootSuperview.offset(for: self)!
        let viewOffset = rootSuperview.offset(for: view)!
        let delta = CGSize(width: offset.width - viewOffset.width, height: offset.height - viewOffset.height)
        
        return CGPoint(x: point.x + delta.width, y: point.y + delta.height)
    }
    
    private func offset(for subview: UIView, offset: CGSize = CGSize()) -> CGSize? {
        
        var offset = offset
        
        // add delta
        offset.width += frame.origin.x
        offset.height += frame.origin.y
        
        guard subview !== self
            else { return offset }
        
        for view in subviews {
            
            guard let foundOffset = view.offset(for: subview, offset: offset)
                else { continue }
            
            return foundOffset
        }
        
        return nil
    }
    
    @nonobjc
    public final func convert(_ point: CGPoint, from view: UIView?) -> CGPoint {
        
        fatalError()
    }
    
    @nonobjc
    public final func convert(_ rect: CGRect, to view: UIView?) -> CGPoint {
        
        fatalError()
    }
    
    @nonobjc
    public final func convert(_ rect: CGRect, from view: UIView?) -> CGPoint {
        
        fatalError()
    }
    
    // MARK: - Drawing
    
    open func draw(_ rect: CGRect) { /* implemented by subclasses */ }
    
    /// The scale factor applied to the view.
    ///
    /// The scale factor determines how content in the view is mapped from the logical coordinate space
    /// (measured in points) to the device coordinate space (measured in pixels).
    /// This value is typically either 1.0 or 2.0. Higher scale factors indicate that each point in
    /// the view is represented by more than one pixel in the underlying layer.
    /// For example, if the scale factor is 2.0 and the view frame size is 50 x 50 points,
    /// the size of the bitmap used to present that content is 100 x 100 pixels.
    ///
    /// The default value for this property is the scale factor associated with the screen currently displaying the view.
    ///
    /// In general, you should not need to modify the value in this property.
    /// However, if your application draws using OpenGL ES, you may want to change
    /// the scale factor to trade image quality for rendering performance.
    public final var contentScaleFactor: CGFloat {
        
        return self.window?.screen.scale ?? UIScreen.main.scale
    }
    
    /// The backing rendering node / texture.
    ///
    /// Cacao's equivalent of `UIView.layer` / `CALayer`.
    /// Instead of the CoreGraphics API you could draw directly to the texture's pixel data.
    ///
    /// The value is guarenteed to be valid during `draw()` calls and can be used directly
    /// (e.g. video streaming, SDL game) instead of the CoreGraphics drawing API.
    ///
    /// - Warning: Do not hold a reference to this object as it can be recreated as needed for rendering.
    public private(set) var texture: SDLTexture?
    
    internal var shouldRender: Bool {
        return isHidden == false
            && alpha > 0
            && bounds.size.width >= 1.0
            && bounds.size.height >= 1.0 // must be at least 1x1
    }
    
    internal final func render(on screen: UIScreen, in rect: SDL_Rect) throws {
        
        guard shouldRender
            else { return }
        
        let scale = screen.scale
        let nativeSize = (width: Int(bounds.size.width * scale),
                          height: Int(bounds.size.height * scale))
        
        let texture: SDLTexture
        
        // reuse cached texture if view hasn't been resized.
        if let cachedTexture = self.texture,
            let attributes = try? cachedTexture.attributes(),
            attributes.width == nativeSize.width,
            attributes.height == nativeSize.height {
            
            texture = cachedTexture
            
        } else {
            
            texture = try SDLTexture(renderer: screen.renderer,
                                     format: .argb8888, // SDL_PIXELFORMAT_ARGB8888
                                     access: .streaming,
                                     width: nativeSize.width,
                                     height: nativeSize.height)
            
            try texture.setBlendMode([.alpha])
            
            // cache for reuse if view size isn't changed
            self.texture = texture
        }
        
        // unlock and modify texture
        try texture.withUnsafeMutableBytes {
            
            let surface = try Cairo.Surface.Image(mutableBytes: $0.assumingMemoryBound(to: UInt8.self),
                                                   format: .argb32,
                                                   width: nativeSize.width,
                                                   height: nativeSize.height,
                                                   stride: $1)
            
            // reset memory
            memset($0, 0, surface.stride * surface.height)
            
            let context = try! CGContext(surface: surface, size: bounds.size)
            context.scaleBy(x: scale, y: scale)
            
            // CoreGraphics drawing
            draw(in: context)
            
            /// flush surface
            surface.flush()
            surface.finish()
        }
        
        try screen.renderer.copy(texture, destination: rect)
    }
    
    internal func draw(in context: Silica.CGContext) {
        
        UIGraphicsPushContext(context)
        
        // draw background color
        context.fillColor = backgroundColor?.cgColor ?? CGColor.clear
        context.addRect(bounds)
        context.fillPath()
        
        // apply alpha
        context.setAlpha(alpha)
        
        // draw rect
        draw(bounds)
        
        UIGraphicsPopContext()
    }
    
    // MARK: - Layout
    
    /// This view is the main view of the specified view controller.
    internal weak var viewController: UIViewController?
    
    /// Lays out subviews.
    ///
    /// If contraints are availible, the default implementation uses any constraints you have set
    /// to determine the size and position of any subviews.
    /// Otherwise, the default implementation of this method does nothing.
    ///
    /// Subclasses can override this method as needed to perform more precise layout of their subviews.
    /// You should override this method only if the autoresizing and constraint-based behaviors of
    /// the subviews do not offer the behavior you want.
    /// You can use your implementation to set the frame rectangles of your subviews directly.
    ///
    /// You should not call this method directly.
    /// If you want to force a layout update, call the `setNeedsLayout()` method instead
    /// to do so prior to the next drawing update.
    /// If you want to update the layout of your views immediately, call the `layoutIfNeeded()` method.
    @inline(__always)
    open func layoutSubviews() { }
    
    /// Tells the view that a subview was added.
    ///
    /// The default implementation of this method does nothing.
    /// Subclasses can override it to perform additional actions when subviews are added.
    /// This method is called in response to adding a subview using any of the relevant view methods.
    @inline(__always)
    open func didAddSubview(_ subview: UIView) { }
    
    /// Tells the view that a subview is about to be removed.
    ///
    /// The default implementation of this method does nothing.
    /// Subclasses can override it to perform additional actions whenever subviews are removed.
    /// This method is called when the subview’s superview changes
    /// or when the subview is removed from the view hierarchy completely.
    @inline(__always)
    open func willRemoveSubview(_ subview: UIView) { }
    
    /// Tells the view that its superview is about to change to the specified superview.
     @inline(__always)
    open func willMove(toSuperview newSuperview: UIView?) { }
    
    /// Tells the view that its superview changed.
    ///
    /// The default implementation of this method does nothing.
     @inline(__always)
    open func didMoveToSuperview() { }
    
    /// Tells the view that its window object is about to change.
    ///
    /// The default implementation of this method does nothing.
    /// Subclasses can override it to perform additional actions whenever the window changes.
     @inline(__always)
    open func willMove(toWindow newWindow: UIWindow?) { }
    
    /// Tells the view that its window object changed.
    @inline(__always)
    open func didMoveToWindow() { }
    
    /// Invalidates the current layout of the receiver and triggers a layout update during the next update cycle.
    ///
    /// Call this method on your application’s main thread when you want to adjust the layout of a view’s subviews.
    /// This method makes a note of the request and returns immediately.
    /// Because this method does not force an immediate update, but instead waits for the next update cycle,
    /// you can use it to invalidate the layout of multiple views before any of those views are updated.
    /// This behavior allows you to consolidate all of your layout updates to one update cycle,
    /// which is usually better for performance.
    public final func setNeedsLayout() {
        
        self.window?.screen.needsLayout = true
    }
    
    /// Lays out the subviews immediately.
    ///
    /// Use this method to force the layout of subviews before drawing.
    /// Using the view that receives the message as the root view,
    /// this method lays out the view subtree starting at the root.
    public final func layoutIfNeeded() {
        
        viewController?.viewWillLayoutSubviews()
        layoutSubviews()
        subviews.forEach { $0.layoutIfNeeded() }
        viewController?.viewDidLayoutSubviews()
    }
    
    /// Returns the farthest descendant of the receiver in the view hierarchy (including itself) that contains a specified point.
    ///
    /// - Note: This method ignores view objects that are hidden or have user interaction disabled.
    /// This method does not take the view’s content into account when determining a hit.
    /// Thus, a view can still be returned even if the specified point is in a transparent portion of that view’s content.
    open func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        
        guard isHidden == false,
            alpha > 0,
            isUserInteractionEnabled,
            self.point(inside: point, with: event)
            else { return nil }
        
        for subview in subviews.reversed() {
            
            // convert point for subviews
            let subviewPoint = self.convert(point, to: subview)
            
            guard let descendant = subview.hitTest(subviewPoint, with: event)
                else { continue }
            
            return descendant
        }
        
        return self
    }
    
    /// Returns a Boolean value indicating whether the receiver contains the specified point.
    public final func point(inside point: CGPoint, with event: UIEvent?) -> Bool {
        
        let rect = CGRect(origin: CGPoint(), size: frame.size)
        
        return (point.x >= rect.minX && point.x <= rect.maxX)
            && (point.y >= rect.minY && point.y <= rect.maxY)
    }
    
    public final func setNeedsDisplay(_ rect: CGRect? = nil) {
        
        self.window?.screen.needsDisplay = true
    }
    
    // MARK: - Managing Gesture Recognizers
    
    /// Attaches a gesture recognizer to the view.
    public func addGestureRecognizer(_ gestureRecognizer: UIGestureRecognizer) {
        
        addGestureRecognizer(gestureRecognizer, atEnd: true)
    }
    
    private func addGestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, atEnd: Bool) {
        
        // remove from old view
        gestureRecognizer.view?.removeGestureRecognizer(gestureRecognizer)
        
        // add to view
        gestureRecognizer.view = self
        atEnd ? gestureRecognizers?.append(gestureRecognizer) : gestureRecognizers?.insert(gestureRecognizer, at: 0)
        
        // update gesture environment
        //UIApplication.shared.gestureEnvironment.addGestureRecognizer(gestureRecognizer)
    }
    
    /// Detaches a gesture recognizer from the receiving view.
    public func removeGestureRecognizer(_ gestureRecognizer: UIGestureRecognizer) {
        
        guard let index = gestureRecognizers?.index(where: { $0 === gestureRecognizer })
            else { return }
        
        gestureRecognizers?.remove(at: index)
        gestureRecognizer.view = nil
    }
    
    private func removeAllGestureRecognizers() {
        
        gestureRecognizers?.forEach { removeGestureRecognizer($0) }
    }
    
    /// The gesture-recognizer objects currently attached to the view.
    public var gestureRecognizers: [UIGestureRecognizer]? = []
    
    /// Asks the view if the gesture recognizer should be allowed to continue tracking touch events.
    open func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
        
        return true
    }
    
    // MARK: - Event Handling
    
    // MARK: - UIResponder
    
    open override var next: UIResponder? {
        
        return viewController ?? superview
    }
    
    open override func becomeFirstResponder() -> Bool {
        
        // CHECKME
        return super.becomeFirstResponder()
    }
    
    open override var canBecomeFirstResponder: Bool {
        
        return true
    }
    
    internal override var firstResponder: UIResponder? {
        
        return responderWindow?.firstResponder
    }
    
    // MARK: - Animating Views with Block Objects
    
    internal private(set) static var animationDuration: TimeInterval?
    
    internal static var animations = [Animation]()
    
    /// Animate changes to one or more views using the specified duration.
    public class func animate(withDuration duration: TimeInterval, animations: @escaping () -> ()) {
        
        guard duration > 0 else { animations(); return }
        
        UIView.animationDuration = duration
        
        animations()
        
        UIView.animationDuration = nil
    }
}

// MARK: - Supporting Types

public let UIViewNoIntrinsicMetric: CGFloat = -1.0

// MARK: - Internal Animations

internal class Animation {
    
    let frameChange: () -> Bool
    
    init<View: UIView>(view: View,
                       duration: TimeInterval,
                       value: (start: CGFloat, end: CGFloat),
                       keyPath: ReferenceWritableKeyPath<View, CGFloat>) {
        
        let startDate = Date()
        
        let delta = value.end - value.start
        
        let weakView = WeakReference(view)
        
        self.frameChange = {
            
            guard let view = weakView.value
                else { return false }
            
            let now = Date()
            
            var secondsLeft = duration - now.timeIntervalSince(startDate)
            
            if secondsLeft < 0 {
                
                secondsLeft = 0
            }
            
            let progress = 1 - CGFloat(secondsLeft / duration)
            
            let currentValue = value.start + (progress * delta)
            
            //view[keyPath: keyPath] = currentValue
            keyPath.set(view, currentValue)
            
            return progress < 1.0
        }
    }
}

final class ReferenceWritableKeyPath<Value, Property> {
    
    let get: (Value) -> (Property)
    
    let set: (Value, Property) -> ()
    
    init(get: @escaping (Value) -> (Property),
         set: @escaping (Value, Property) -> ()) {
        
        self.get = get
        self.set = set
    }
}

// MARK: - Xcode Quick Look

#if os(macOS) && Xcode
    
    import class AppKit.NSImage
    import class Foundation.NSString
    
    public extension UIView {
        
        @objc(debugQuickLookObject)
        public var debugQuickLookObject: AnyObject {
            
            if let cachedTexture = self.texture,
                let screen = self.window?.screen {
                
                let scale = screen.scale
                let nativeSize = (width: Int(bounds.size.width * scale),
                                  height: Int(bounds.size.height * scale))
                
                let surface = try! cachedTexture.withUnsafeMutableBytes {
                    
                    try Cairo.Surface.Image(mutableBytes: $0.assumingMemoryBound(to: UInt8.self), format: .argb32, width: nativeSize.width, height: nativeSize.height, stride: $1)
                }
                
                let data = try! surface!.writePNG()
                
                let image = NSImage(data: data)!
                
                return image
                
            } else {
                
                return "\(self)" as NSString
            }
        }
    }
    
#endif


