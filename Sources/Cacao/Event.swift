//
//  Event.swift
//  Cacao
//
//  Created by Alsey Coleman Miller on 5/27/16.
//  Copyright © 2016 PureSwift. All rights reserved.
//

import Silica

public protocol Event {
    
    var timestamp: UInt32 { get }
    
    var location: Point { get }
}

public struct MouseEvent: Event {
    
    public let timestamp: UInt32
    
    public let location: Point
    
    public let button: Button
    
    public enum Button {
        
        case left, right, middle
    }
}

public struct TouchEvent: Event {
    
    public let timestamp: UInt32
    
    public let location: Point
}