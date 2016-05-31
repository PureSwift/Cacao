//
//  UIViewContentMode.swift
//  Cacao
//
//  Created by Alsey Coleman Miller on 5/31/16.
//  Copyright © 2016 PureSwift. All rights reserved.
//

public enum UIViewContentMode: Int {
    
    public init() { self = .ScaleToFill }
    
    case ScaleToFill
    case ScaleAspectFit
    case ScaleAspectFill
    case Redraw
    case Center
    case Top
    case Bottom
    case Left
    case Right
    case TopLeft
    case TopRight
    case BottomLeft
    case BottomRight
}

extension UIViewContentMode: CacaoConvertible {
    
    public func toCacao() -> ContentMode {
        
        switch self {
            
        case ScaleToFill:       return .scaleToFill
        case ScaleAspectFit:    return .aspectFit
        case ScaleAspectFill:   return .aspectFill
        case Redraw:            return .scaleToFill // default
        case Center:            return .center
        case Top:               return .top
        case Bottom:            return .bottom
        case Left:              return .left
        case Right:             return .right
        case TopLeft:           return .topLeft
        case TopRight:          return .topRight
        case BottomLeft:        return .bottomLeft
        case BottomRight:       return .bottomRight
        }
    }
}
