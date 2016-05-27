//
//  AppDelegate.swift
//  Cacao
//
//  Created by Alsey Coleman Miller on 5/21/16.
//  Copyright © 2016 PureSwift. All rights reserved.
//

import Cacao

final class AppDelegate: UIApplicationDelegate {
    
    var window: UIWindow!
    
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [String : Any]?) -> Bool {
        
        window = UIWindow(frame: UIScreen.main.bounds)
                
        // Override point for customization after application launch.
        
        let rootVC = HelloWorldViewController()
        
        rootVC.view.backgroundColor = UIColor(red: 0.0, green: 0.0, blue: 1.0)
        
        window.rootViewController = rootVC
                
        window.makeKeyAndVisible()
        
        print("Started Demo app")
        
        return true
    }
    
    func applicationWillTerminate(_ application: UIApplication) {
        
        print("Will close app")
    }
}