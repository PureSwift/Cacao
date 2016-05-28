//
//  ViewController.swift
//  Cacao
//
//  Created by Alsey Coleman Miller on 5/27/16.
//  Copyright © 2016 PureSwift. All rights reserved.
//

import Silica

public protocol ViewController: class {
    
    var view: View { get }
    
    var childViewControllers: [ViewController] { get }
    
    func layoutView()
}

public extension ViewController {
    
    var childViewControllers: [ViewController] { return [] }
    
    func layoutView() {
        
        view.layoutSubviews()
    }
}