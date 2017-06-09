//
//  AppDelegate.swift
//  Cacao
//
//  Created by Alsey Coleman Miller on 5/21/16.
//  Copyright © 2016 PureSwift. All rights reserved.
//

import Cacao
import Silica

final class AppDelegate: UIApplicationDelegate {
    
    static let shared = AppDelegate()
    
    var window: UIWindow!
    
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplicationLaunchOptionsKey : Any]) -> Bool {
        
        print("Running at \(UIScreen.main.maximumFramesPerSecond) FPS")
        
        window = UIWindow(frame: UIScreen.main.bounds)
                
        let viewController = ContentModeViewController()
        
        window.rootViewController = viewController
        
        window.makeKeyAndVisible()
        
        return true
    }
    
    func applicationWillTerminate(_ application: UIApplication) {
        
        print("Will close app")
    }
}
