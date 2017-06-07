//
//  AppDelegate.swift
//  Cacao
//
//  Created by Alsey Coleman Miller on 5/21/16.
//  Copyright © 2016 PureSwift. All rights reserved.
//

import Cacao
import Silica

final class Application: Cacao.Application {
    
    let name: String = "CacaoDemo"
    
    var preferredWindowSize = Size(width: 640, height: 480)
    
    var framesPerSecond: Int = 60
    
    func didFinishLaunching(screen: Screen) {
        
        print("Started Demo app")
        
        print("Running at \(framesPerSecond) FPS")
        
        let rootVC = ContentModeViewController()
        
        screen.rootViewController = rootVC
    }
    
    func willTerminate() {
        
        print("Will close app")
    }
}