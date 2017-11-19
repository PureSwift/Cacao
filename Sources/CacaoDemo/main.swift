//
//  main.swift
//  Cacao
//
//  Created by Alsey Coleman Miller on 5/21/16.
//  Copyright © 2016 PureSwift. All rights reserved.
//

#if os(iOS)
    
import UIKit

UIApplicationMain(0, nil, nil, NSStringFromClass(AppDelegate.self))
    
#else
    
import Cacao

var options = CacaoOptions()
options.windowName = "CacaoDemo"

UIApplicationMain(delegate: AppDelegate.shared, options: options)
    
#endif
