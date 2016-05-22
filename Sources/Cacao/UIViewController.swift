//
//  UIViewController.swift
//  Cacao
//
//  Created by Alsey Coleman Miller on 5/15/16.
//  Copyright © 2016 PureSwift. All rights reserved.
//

public class UIViewController {
    
    // MARK: - Properties
    
    public let view: UIView
    
    public private(set) var isViewLoaded = false
    
    // MARK: - Initialization
    
    public init(view: UIView = UIView()) {
        
        self.view = view
    }
    
    public func viewDidLoad() {
        
        isViewLoaded = true
        
        view.layoutSubviews()
    }
}
