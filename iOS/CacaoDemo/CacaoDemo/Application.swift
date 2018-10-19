//
//  Application.swift
//  CacaoDemo
//
//  Created by Alsey Coleman Miller on 10/18/18.
//  Copyright © 2018 PureSwift. All rights reserved.
//

import Foundation

/// The application singleton.
public final class Application {
    
    private init() { }
    
    public static let shared = Application()
    
    public fileprivate(set) weak var delegate: ApplicationDelegate?
    
    public fileprivate(set) var applicationState: ApplicationState = .active
    
    /// Never returns
    public static func main(delegate: ApplicationDelegate) {
        
        // Initialize singleton
        let app = Application.shared
        
        // enter main loop
        app.run()
        
        // start polling for SDL events
        SDLEventRun()
    }
    
    internal func run() {
        
        
    }
}

// MARK: - Delegate

public protocol ApplicationDelegate: class {
    
    func application(_ application: Application, willFinishLaunchingWithOptions launchOptions: ApplicationLaunchOptions) -> Bool
    
    func application(_ application: Application, didFinishLaunchingWithOptions launchOptions: ApplicationLaunchOptions) -> Bool
    
    func applicationDidBecomeActive(_ application: Application)
    
    func applicationDidEnterBackground(_ application: Application)
    
    func applicationWillResignActive(_ application: Application)
    
    func applicationWillEnterForeground(_ application: Application)
    
    func applicationWillTerminate(_ application: Application)
}

public struct ApplicationLaunchOptions {
    
    
}

public enum ApplicationState {
    
    case active
    case inactive
    case background
}
