//
//  ViewController.swift
//  Cacao
//
//  Created by Alsey Coleman Miller on 5/27/16.
//  Copyright © 2016 PureSwift. All rights reserved.
//

public protocol ViewController: class {
    
    var view: View { get }
    
    func layoutViews()
}