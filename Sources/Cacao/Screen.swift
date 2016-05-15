//
//  Screen.swift
//  Cacao
//
//  Created by Alsey Coleman Miller on 5/14/16.
//  Copyright © 2016 PureSwift. All rights reserved.
//

import Silica
import Cairo

/// Device screen
public final class Screen {
    
    public var scale: Double = 1.0
    
    public var size: Size
    
    public var surface: Surface
    
    // MARK: - Private Properties
    
    internal var context: Silica.Context?
    
    // MARK: - Initialization
    
    public init(surface: Surface, size: Size) {
        
        self.size = size
        self.surface = surface
    }
}