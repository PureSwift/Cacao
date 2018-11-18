//
//  AppDelegate.swift
//  Cacao
//
//  Created by Alsey Coleman Miller on 5/21/16.
//  Copyright © 2016 PureSwift. All rights reserved.
//

import Foundation

#if os(iOS) || os(tvOS)
    import UIKit
    import CoreGraphics
#else
    import Cacao
    import Silica
#endif

final class AppDelegate: NSObject, UIApplicationDelegate {
    
    #if os(iOS)
    static var shared: AppDelegate { return UIApplication.shared.delegate as! AppDelegate }
    #else
    static let shared: AppDelegate = AppDelegate()
    #endif
    
    var window: UIWindow?
    
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplicationLaunchOptionsKey : Any]?) -> Bool {
        
        print("Device: \(UIDevice.current.name)")
        print("Model: \(UIDevice.current.model)")
        print("System: \(UIDevice.current.systemName) \(UIDevice.current.systemVersion)")
        #if !os(tvOS)
        print("Battery: \(UIDevice.current.batteryLevel) (\(UIDevice.current.batteryState))")
        #endif
        if #available(iOS 10.3, *) {
            print("FPS: \(UIScreen.main.maximumFramesPerSecond)")
        }
        
        self.window = UIWindow(frame: UIScreen.main.bounds)
        self.window?.rootViewController = TableViewController()
        self.window?.makeKeyAndVisible()
        
        return true
    }
    
    func applicationWillTerminate(_ application: UIApplication) {
        
        print("Will close app")
    }
}
