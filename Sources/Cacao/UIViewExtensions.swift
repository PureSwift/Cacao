//
//  UIViewExtensions.swift
//  Cacao
//
//  Created by Alsey Coleman Miller on 5/26/16.
//  Copyright © 2016 PureSwift. All rights reserved.
//

import Silica

public extension UIView {
    
    /// Calculates a destination `Rect` based on a `UIViewContentMode`.
    static func rect(for contentMode: UIViewContentMode, size: (original: Size, maximum: Size)) -> Rect {
        
        switch contentMode {
            
        case .ScaleToFill:
            
            return Rect(size: size.maximum)
            
        default: fatalError("Not implemented")
        }
    }
}

