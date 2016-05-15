//
//  Window.swift
//  Cacao
//
//  Created by Alsey Coleman Miller on 5/12/16.
//  Copyright © 2016 PureSwift. All rights reserved.
//

import Silica

public final class Window {
    
    // MARK: - Properties
    
    public var frame: Rect
    
    public var rootViewController: ViewController
    
    // MARK: - Initialization
    
    public init(frame: Rect, rootViewController: ViewController) {
        
        self.frame = frame
        self.rootViewController = rootViewController
    }
    
    // MARK: - Methods
    
    func draw(context: Silica.Context) { }
}