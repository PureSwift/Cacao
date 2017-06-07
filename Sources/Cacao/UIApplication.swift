//
//  UIApplication.swift
//  Cacao
//
//  Created by Alsey Coleman Miller on 6/7/17.
//

import SDL
import Silica
import Cairo

// MARK: - UIApplicationMain

@_silgen_name("_UIApplicationMain")
public func UIApplicationMain(delegate: UIApplicationDelegate, options: CacaoOptions) {
    
    UIApplication.shared.delegate = delegate
    
    SDL.initialize(subSystems: [.video]).sdlAssert()
    
    defer { SDL.quit() }
    
    var windowOptions: [Window.Option] = [.allowRetina]
    
    if options.canResizeWindow {
        
        windowOptions.append(.resizable)
    }
    
    let window = Window(title: options.windowName, frame: (x: .centered, y: .centered, width: Int(options.windowSize.width), height:  Int(options.windowSize.height))).sdlAssert()
    
    
    
    let nativeSize = windowSize // FIXME: Retina display
}

/// Cacao-Specific application launch settings
public struct CacaoOptions {
    
    public var windowName: String = "App"
    
    public var windowSize: Size = Size(width: 600, height: 800)
    
    public var framesPerSecond: Int = 60
    
    public var canResizeWindow: Bool = true
}

public final class UIApplication {
    
    // MARK: - Getting the App Instance
    
    // Will be set after `UIApplicationMain()`
    public static var shared = UIApplication()
    
    private init() { }
    
    // MARK: - Getting the App Delegate
    
    public fileprivate(set) weak var delegate: UIApplicationDelegate?
    
    // MARK: - Getting App Windows
    
    public fileprivate(set) var keyWindow: UIWindow?
    
    public private(set) var windows = [UIWindow]()
    
    // MARK: - Controlling and Handling Events
    
    public func sendEvent(_ event: UIEvent) {
        
        
    }
    
    public func sendAction(_ selector: String, to target: AnyObject?, from sender: AnyObject?, for event: UIEvent?) {
        
        
    }
    
    public func beginIgnoringInteractionEvents() {
        
        
    }
    
    public func endIgnoringInteractionEvents() {
        
        
    }
    
    public fileprivate(set) var isIgnoringInteractionEvents: Bool = false
    
    public var applicationSupportsShakeToEdit: Bool { return false }
    
    // MARK: - Managing Background Execution
    
    public fileprivate(set) var applicationState: UIApplicationState = .active
}

// MARK: - Supporting Types

public protocol UIApplicationDelegate: class {
    
    func application(_ application: UIApplication, willFinishLaunchingWithOptions launchOptions: [UIApplicationLaunchOptionsKey : Any]?) -> Bool
    
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplicationLaunchOptionsKey : Any]) -> Bool
    
    func applicationDidBecomeActive(_ application: UIApplication)
    
    func applicationDidEnterBackground(_ application: UIApplication)
    
    func applicationWillResignActive(_ application: UIApplication)
    
    func applicationWillEnterForeground(_ application: UIApplication)
    
    func applicationWillTerminate(_ application: UIApplication)
}

public enum UIApplicationState: Int {
    
    case active
    case inactive
    case background
}

public struct UIApplicationLaunchOptionsKey: RawRepresentable {
    
    public let rawValue: String
    
    public init?(rawValue: String) {
        
        self.rawValue = rawValue
    }
}

extension UIApplicationLaunchOptionsKey: Equatable {
    
    public static func == (lhs: UIApplicationLaunchOptionsKey, rhs: UIApplicationLaunchOptionsKey) -> Bool {
        
        return lhs.rawValue == rhs.rawValue
    }
}

extension UIApplicationLaunchOptionsKey: Hashable {
    
    public var hashValue: Int {
        
        return rawValue.hashValue
    }
}

// Default implementations
public extension UIApplicationDelegate {
    
    func application(_ application: UIApplication, willFinishLaunchingWithOptions launchOptions: [UIApplicationLaunchOptionsKey : Any]?) -> Bool { }
    
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplicationLaunchOptionsKey : Any]) -> Bool { }
    
    func applicationDidBecomeActive(_ application: UIApplication) { }
    
    func applicationDidEnterBackground(_ application: UIApplication) { }
    
    func applicationWillResignActive(_ application: UIApplication) { }
    
    func applicationWillEnterForeground(_ application: UIApplication) { }
    
    func applicationWillTerminate(_ application: UIApplication) { }
}
