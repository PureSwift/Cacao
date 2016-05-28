//
//  ViewController.swift
//  Cacao
//
//  Created by Alsey Coleman Miller on 5/27/16.
//  Copyright © 2016 PureSwift. All rights reserved.
//

import Silica

public protocol ViewController: class {
    
    func view(frame: Rect) -> View
    
    /// Whether the view controller's contents should be redrawn.
    var needsDisplay: Bool { get }
}

public protocol ContainerViewController: ViewController {
    
    var children: [ViewController] { get }
}

public extension ContainerViewController {
    
    var needsDisplay: Bool {
        
        for child in children {
            
            guard child.needsDisplay else { continue }
            
            return true
        }
        
        return false
    }
}