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

extension UIViewContentMode: CacaoConvertible {
    
    public func toCacao() -> ContentMode {
        
        switch self {
            
        case .scaleToFill:       return .scaleToFill
        case .scaleAspectFit:    return .aspectFit
        case .scaleAspectFill:   return .aspectFill
        case .redraw:            return .scaleToFill // default
        case .center:            return .center
        case .top:               return .top
        case .bottom:            return .bottom
        case .left:              return .left
        case .right:             return .right
        case .topLeft:           return .topLeft
        case .topRight:          return .topRight
        case .bottomLeft:        return .bottomLeft
        case .bottomRight:       return .bottomRight
        }
    }
}
