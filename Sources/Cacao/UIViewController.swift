//
//  UIViewController.swift
//  Cacao
//
//  Created by Alsey Coleman Miller on 5/15/16.
//  Copyright © 2016 PureSwift. All rights reserved.
//

public class UIViewController: UIResponder {
    
    // MARK: - Properties
    
    public var view: UIView = UIView()
    
    public private(set) var isViewLoaded = false
    
    // MARK: - Initialization
    
    public init() { }
    
    // MARK: - Methods
    
    public func viewDidLoad() {
        
        isViewLoaded = true
        
        view.layoutSubviews()
    }
    
    // MARK: - Cacao Extensions
    
    /// Routes the dynamic `IBAction` missing in the Swift runtime.
    ///
    /// Subclasses should override this method.
    public func perform(action: String, sender: AnyObject) {
        
        print("\(self.dynamicType) \"\(action)\" called with sender: \(sender)")
    }
}
