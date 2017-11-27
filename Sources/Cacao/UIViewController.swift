//
//  UIViewController.swift
//  Cacao
//
//  Created by Alsey Coleman Miller on 6/7/17.
//

import Foundation
import Silica

open class UIViewController: UIResponder {
    
    // MARK: - Configuring a View Controller Using Nib Files
    
    public init?(coder: NSCoder) {
        
        return nil
    }
    
    /// Returns a newly initialized view controller with the nib file in the specified bundle.
    public init(nibName: String? = nil, bundle: Bundle? = nil) {
        
        self.nibName = nibName
        self.nibBundle = bundle
    }
    
    public final var nibName: String?
    
    public final var nibBundle: Bundle?
    
    // MARK: - Managing the View
    
    /// The view that the controller manages.
    ///
    /// The view stored in this property represents the root view for the view controller's view hierarchy.
    /// The default value of this property is nil.
    ///
    /// If you access this property and its value is currently nil,
    /// the view controller automatically calls the loadView() method and returns the resulting view.
    ///
    /// Each view controller object is the sole owner of its view.
    /// You must not associate the same view object with multiple view controller objects.
    /// The only exception to this rule is that a container view controller implementation may
    /// add this view as a subview in its own view hierarchy. Before adding the subview,
    /// the container must first call its `addChildViewController(_:)` method
    /// to create a parent-child relationship between the two view controller objects.
    ///
    /// Because accessing this property can cause the view to be loaded automatically,
    /// you can use the isViewLoaded() method to determine if the view is currently in memory.
    /// Unlike this property, the isViewLoaded() property does not force the loading of the
    /// view if it is not currently in memory.
    public final var view: UIView! {
        get { loadViewIfNeeded(); return _view }
        set {
            let oldValue = _view
            oldValue?.viewController = nil
            newValue.viewController = self
            _view = newValue
        }
    }
    private var _view: UIView?
    public final var isViewLoaded: Bool { return _view != nil }
    
    /// You should never call this method directly.
    /// The view controller calls this method when its view property is requested but is currently nil.
    /// This method loads or creates a view and assigns it to the view property.
    ///
    /// If the view controller has an associated nib file, this method loads the view from the nib file.
    /// A view controller has an associated nib file if the nibName property returns a non-nil value,
    /// which occurs if the view controller was instantiated from a storyboard,
    /// if you explicitly assigned it a nib file using the `init(nibName:bundle:)` method,
    /// or if the app finds a nib file in the app bundle with a name based on the view controller's class name.
    /// If the view controller does not have an associated nib file, this method creates a plain `UIView` object instead.
    ///
    /// If you use Interface Builder to create your views and initialize the view controller, you must not override this method.
    ///
    /// You can override this method in order to create your views manually.
    /// If you choose to do so, assign the root view of your view hierarchy to the view property.
    /// The views you create should be unique instances and should not be shared with any other view controller object.
    /// Your custom implementation of this method should not call super.
    ///
    /// If you want to perform any additional initialization of your views, do so in the `viewDidLoad()` method.
    open func loadView() {
        
        self.view = UIView(frame: .zero)
    }
    
    /// Called after the controller's view is loaded into memory.
    open func viewDidLoad() { /* Subclasses should override */ }
    
    /// Loads the view controller’s view if it has not yet been loaded.
    public final func loadViewIfNeeded() {
        
        if isViewLoaded == false {
            
            loadView()
            viewDidLoad()
        }
    }
    
    /// The view controller’s view, or nil if the view is not yet loaded.
    public final var viewIfLoaded: UIView? { return _view }
    
    /// A localized string that represents the view this controller manages.
    public final var title: String?
    
    /// The preferred size for the view controller’s view.
    ///
    /// The value in this property is used primarily when displaying the view controller’s
    /// content in a popover but may also be used in other situations.
    public final var preferredContentSize: CGSize = .zero
    
    // MARK: - Presenting View Controllers
    
    // MARK: - Responding to View Events
    
    open func viewWillAppear(_ animated: Bool) {
        
        
    }
    
    open func viewDidAppear(_ animated: Bool) {
        
        
    }
    
    open func viewWillDisappear(_ animated: Bool) {
        
        
    }
    
    open func viewDidDisappear(_ animated: Bool) {
        
        
    }
    
    // MARK: - Configuring the View’s Layout Behavior
    
    /// Called to notify the view controller that its view is about to layout its subviews.
    ///
    /// When a view's bounds change, the view adjusts the position of its subviews.
    /// Your view controller can override this method to make changes before the view lays out its subviews.
    /// The default implementation of this method does nothing.
    open func viewWillLayoutSubviews() { }
    
    open func viewDidLayoutSubviews() { }
    
    // MARK: - Configuring the View Rotation Settings
    
    // MARK: - Managing Child View Controllers in a Custom Container
    
    public final private(set) var childViewControllers = [UIViewController]()
    
    public final func addChildViewController(_ viewController: UIViewController) {
        
        childViewControllers.append(viewController)
        
        viewController.parent = self
    }
    
    public final func removeFromParentViewController() {
        
        guard let index = parent?.childViewControllers.index(where: { $0 === self })
            else { return }
        
        parent?.childViewControllers.remove(at: index)
    }
    
    /// Transitions between two of the view controller's child view controllers.
    ///
    /// This method adds the second view controller's view to the view hierarchy and
    /// then performs the animations defined in your animations block.
    /// After the animation completes, it removes the first view controller's view from the view hierarchy.
    /// This method is only intended to be called by an implementation of a custom container view controller.
    /// If you override this method, you must call super in your implementation.
    public func transition(from fromViewController: UIViewController,
                    to toViewController: UIViewController,
                    duration: TimeInterval,
                    options: UIViewAnimationOptions = [],
                    animations: (() -> Void)?,
                    completion: ((Bool) -> Void)? = nil) {
        
        let animated = duration > 0
        fromViewController.beginAppearanceTransition(false, animated: animated)
        toViewController.beginAppearanceTransition(true, animated: animated)
        
        // run animations
        
        self.view.addSubview(toViewController.view)
        fromViewController.view?.removeFromSuperview()
        
    }
    
    /// Returns a Boolean value indicating whether appearance methods are forwarded to child view controllers.
    ///
    /// - Returns: true if appearance methods are forwarded or false if they are not.
    ///
    /// This method is called to determine whether to automatically forward appearance-related containment
    /// callbacks to child view controllers.
    /// The default implementation returns true. Subclasses of the `UIViewController` class that implement containment
    /// logic may override this method to control how these methods are forwarded.
    /// If you override this method and return false, you are responsible for telling the child when its
    /// views are going to appear or disappear.
    /// You do this by calling the child view controller's `beginAppearanceTransition(_:animated:)`
    /// and `endAppearanceTransition()` methods.
    public var shouldAutomaticallyForwardAppearanceMethods: Bool {
        
        return true
    }
    
    /// Tells a child controller its appearance is about to change.
    ///
    /// If you are implementing a custom container controller,
    /// use this method to tell the child that its views are about to appear or disappear.
    public func beginAppearanceTransition(_ isAppearing: Bool,
                                          animated: Bool) {
        
        if shouldAutomaticallyForwardAppearanceMethods {
            
            childViewControllers
                .filter { $0.isViewLoaded && $0.view.isDescendant(of: self.view) }
                .forEach { $0.beginAppearanceTransition(isAppearing, animated: animated) }
        }
        
        if isAppearing {
            
            let _ = self.view
            viewWillAppear(animated)
            
        } else {
            
            viewWillDisappear(animated)
        }
    }
    
    /// Tells a child controller its appearance has changed.
    ///
    /// If you are implementing a custom container controller,
    /// use this method to tell the child that the view transition is complete.
    public func endAppearanceTransition() {
        
        if shouldAutomaticallyForwardAppearanceMethods {
            
            childViewControllers.forEach { $0.endAppearanceTransition() }
        }
        
        //if isview
    }
    
    // MARK: - Responding to Containment Events
    
    // MARK: - Getting Other Related View Controllers
    
    /// The view controller that presented this view controller.
    public private(set) weak var presentingViewController: UIViewController?
    
    /// The view controller that is presented by this view controller, or one of its ancestors in the view controller hierarchy.
    public var presentedViewController: UIViewController? {
        
        return nil
    }
    
    public final private(set) weak var parent: UIViewController?
    
    //public final var navigationController: UINavigationController?
    
    //var splitViewController: UISplitViewController?
    //var tabBarController: UITabBarController?
    
    // MARK: - Handling Memory Warnings
    
    /// Sent to the view controller when the app receives a memory warning.
    ///
    /// Your app never calls this method directly.
    /// Instead, this method is called when the system determines that the amount of available memory is low.
    ///
    /// You can override this method to release any additional memory used by your view controller.
    /// If you do, your implementation of this method must call the super implementation at some point.
    open func didReceiveMemoryWarning() {
        
        childViewControllers.forEach { $0.didReceiveMemoryWarning() }
    }
    
    // MARK: - UIResponder
    
    open override var next: UIResponder? {
        
        return view?.superview
    }
    
    internal override var firstResponder: UIResponder? {
        
        return self.view.firstResponder ?? super.firstResponder
    }
}
