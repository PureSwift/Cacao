//
//  UIViewContentMode.swift
//  Cacao
//
//  Created by Alsey Coleman Miller on 5/31/16.
//  Copyright © 2016 PureSwift. All rights reserved.
//

public enum UIViewContentMode: Int {
    
    public init() { self = .scaleToFill }
    
    case scaleToFill
    case scaleAspectFit
    case scaleAspectFill
    case redraw
    case center
    case top
    case bottom
    case left
    case right
    case topLeft
    case topRight
    case bottomLeft
    case bottomRight
}
