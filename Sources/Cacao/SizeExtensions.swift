//
//  SizeExtensions.swift
//  Cacao
//
//  Created by Alsey Coleman Miller on 5/26/16.
//  Copyright © 2016 PureSwift. All rights reserved.
//

import Silica

public extension Size {
    
    /// A dimension of `Size`.
    public enum Dimension {
        
        case width, height
    }
    
    public subscript (dimension: Dimension) -> Double {
        
        get {
            
            switch dimension {
                
            case .width: return width
            case .height: return height
            }
        }
        
        set {
            
            switch dimension {
                
            case .width: width = newValue
            case .height: height = newValue
            }
        }
    }
    
    public var largerDimension: Dimension? {
        
        guard width != height else { return nil }
        
        return width > height ? .width : .height
    }
    
    public var smallerDimension: Dimension? {
        
        guard width != height else { return nil }
        
        return width < height ? .width : .height
    }
}