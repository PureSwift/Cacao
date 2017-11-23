//
//  AppDelegate.swift
//  Cacao
//
//  Created by Alsey Coleman Miller on 5/21/16.
//  Copyright © 2016 PureSwift. All rights reserved.
//

import Foundation

#if os(iOS)
    import UIKit
#else
    import Cacao
    import Silica
#endif

final class AppDelegate: NSObject, UIApplicationDelegate {
    
    static let shared = AppDelegate()
    
    var window: UIWindow?
    
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplicationLaunchOptionsKey : Any]?) -> Bool {
        
        print("Device: \(UIDevice.current.name)")
        print("Model: \(UIDevice.current.model)")
        print("System: \(UIDevice.current.systemName) \(UIDevice.current.systemVersion)")
        print("Battery: \(UIDevice.current.batteryLevel) (\(UIDevice.current.batteryState))")
        print("FPS: \(UIScreen.main.maximumFramesPerSecond)")
        
        self.window = UIWindow(frame: UIScreen.main.bounds)
        
        self.window?.rootViewController = ScrollViewController()
        
        self.window?.makeKeyAndVisible()
        
        return true
    }
    
    func applicationWillTerminate(_ application: UIApplication) {
        
        print("Will close app")
    }
}
