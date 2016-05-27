//
//  UIWindow.swift
//  Cacao
//
//  Created by Alsey Coleman Miller on 5/15/16.
//  Copyright © 2016 PureSwift. All rights reserved.
//

import Silica

public final class UIWindow: UIView {
    
    // MARK: - Properties
    
    public var screen: UIScreen { return UIScreen.main }
    
    public var rootViewController: UIViewController? {
        
        willSet {
            
            if let rootViewController = newValue {
                
                addSubview(rootViewController.view)
                
                // remove old view
                
            } else {
                
                // remove current view
            }
        }
    }
    
    /// A Boolean value that indicates whether the window is the key window for the app.
    ///
    /// The value of this property is `true` when the window is the key window or `false` when it is not.
    /// The key window receives keyboard and other non-touch related events. 
    /// Only one window at a time may be the key window.
    public var keyWindow: Bool {
        
        return UIApplication.shared.keyWindow === self
    }
    
    // MARK: - Initialization
    
    public override init(frame: Rect = UIScreen.main.bounds) {
        super.init(frame: frame)
        
        assert(frame == UIScreen.main.bounds, "Can only set to the main screen's bounds (for now)")
        
        UIApplication.shared.windows.append(self)
        self.screen.windows.append(self)
    }
    
    // MARK: - Methods
    
    public override func layoutSubviews() {
        
        rootViewController?.view.frame = Rect(size: frame.size)
        
        if rootViewController?.isViewLoaded == false {
            
            rootViewController?.viewDidLoad()
        }
    }
    
    /// Makes the receiver the key window.
    ///
    /// Use this method to make the window key without changing its visibility. 
    /// The key window receives keyboard and other non-touch related events. 
    /// This method causes the previous key window to resign the key status.
    public func makeKeyWindow() {
        
        UIApplication.shared.keyWindow = self
    }
    
    /// Shows the window and makes it the key window.
    ///
    /// This is a convenience method to show the current window and 
    /// position it in front of all other windows.
    /// If you only want to show the window, change its hidden property to `false`.
    public func makeKeyAndVisible() {
        
        self.hidden = false
        self.makeKeyWindow()
    }
    
    // MARK: - Internal Methods
    
    /// Dispatches the specified event to its views.
    internal func sendEvent(_ event: UIEvent) {
        
        /*
        for view in subviews {
            
            switch event.type {
                
            case .Touches:
                
                if event.touches(for: view).count > 0 {
                    
                    
                }
                
            default: break
            }
        }*/
    }
}
