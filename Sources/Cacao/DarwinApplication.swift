//
//  DarwinApplication.swift
//  Cacao
//
//  Created by Alsey Coleman Miller on 5/14/16.
//  Copyright © 2016 PureSwift. All rights reserved.
//

#if os(OSX)
    
    import Silica
    import AppKit
    
    // Enter the main application loop for OS X app.
    public func DarwinApplicationMain() {
        
        guard let darwinScreen = NSScreen.main()
            else { print("No screen found to start application"); return }
        
        
    }
    
#endif