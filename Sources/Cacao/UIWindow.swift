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
    
    public var rootViewController: UIViewController? {
        
        didSet { addSubview(rootViewController.view) }
    }
    
    // MARK: - Methods
    
    public override func layoutSubviews() {
        
        rootViewController?.view.frame = Rect(size: frame.size)
        
        if rootViewController?.isViewLoaded == false {
            
            rootViewController.viewDidLoad()
        }
    }
}