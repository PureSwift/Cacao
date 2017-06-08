//
//  UIApplication.swift
//  Cacao
//
//  Created by Alsey Coleman Miller on 6/7/17.
//

import CSDL2
import SDL
import Silica
import Cairo

// MARK: - UIApplicationMain

@_silgen_name("_UIApplicationMain")
public func UIApplicationMain(delegate: UIApplicationDelegate, options: CacaoOptions) {
    
    UIApplication.shared.delegate = delegate
    
    SDL.initialize(subSystems: [.video]).sdlAssert()
    
    defer { SDL.quit() }
    
    var windowOptions: [Window.Option] = [] // [.allowRetina]
    
    if options.canResizeWindow {
        
        windowOptions.append(.resizable)
    }
    
    let preferredSize = options.windowSize
    
    let initialWindowSize = preferredSize // can we query for screen resolution?
    
    let window = Window(title: options.windowName, frame: (x: .centered, y: .centered, width: Int(initialWindowSize.width), height:  Int(initialWindowSize.height))).sdlAssert()
    
    let initialNativeSize = initialWindowSize // FIXME: Retina display
    
    // create UIScreen
    let screen = UIScreen(window: window, size: (initialWindowSize, initialNativeSize))
    
    UIScreen.main = screen
    
    screen.update()
    
    let launchOptions = [UIApplicationLaunchOptionsKey: Any]()
    
    guard delegate.application(UIApplication.shared, willFinishLaunchingWithOptions: launchOptions),
        delegate.application(UIApplication.shared, didFinishLaunchingWithOptions: launchOptions)
        else { options.log("Application delegate could not launch app"); return }
    
    // enter main loop
    
    let framesPerSecond = screen.maximumFramesPerSecond
    
    var frame = 0
    
    var done = false
    
    var event = SDL_Event()
    
    while !done {
        
        frame += 1
        
        let startTime = SDL_GetTicks()
        
        // poll event queue
        
        var pollEventStatus = SDL_PollEvent(&event)
        
        while pollEventStatus != 0 {
            
            let eventType = SDL_EventType(rawValue: event.type)
            
            switch eventType {
                
            case SDL_QUIT, SDL_APP_TERMINATING:
                
                done = true
                
            case SDL_MOUSEBUTTONDOWN, SDL_MOUSEBUTTONUP:
                
                /*
                 let SDL_TOUCH_MOUSEID = -1
                 
                 guard event.button.which != SDL_TOUCH_MOUSEID
                 else { return }*/
                
                break
                //screen.handle(event: PointerEvent(event.button))
                
            case SDL_FINGERDOWN, SDL_FINGERUP: break
                
                // TODO
                
            case SDL_WINDOWEVENT:
                
                switch event.window.event {
                    
                case UInt8(SDL_WINDOWEVENT_SIZE_CHANGED.rawValue):
                    
                    let size = Size(width: Double(event.window.data1), height: Double(event.window.data2))
                    
                    screen.size = (size, size)
                    
                default: break
                }
                
            default: break
            }
            
            // try again
            pollEventStatus = SDL_PollEvent(&event)
        }
        
        // inform responder chain
        
        // render to screen
        screen.update()
        
        // sleep to save energy
        let frameDuration = Int(SDL_GetTicks() - startTime)
        
        if frameDuration < (1000 / framesPerSecond) {
            
            SDL_Delay(Uint32((1000 / framesPerSecond) - frameDuration))
        }
    }
    
    // quit application
    
    delegate.applicationWillTerminate(UIApplication.shared)
}

/// Cacao-Specific application launch settings
public struct CacaoOptions {
    
    public var windowName: String = "App"
    
    public var windowSize: Size = Size(width: 600, height: 800)
        
    public var canResizeWindow: Bool = true
    
    public var log: (String) -> () = { print($0) }
}

public final class UIApplication {
    
    // MARK: - Getting the App Instance
    
    public static var shared = UIApplication()
    
    private init() { }
    
    // MARK: - Getting the App Delegate
    
    public fileprivate(set) weak var delegate: UIApplicationDelegate?
    
    // MARK: - Getting App Windows
    
    /// The app's key window.
    public var keyWindow: UIWindow? { return UIScreen.main.keyWindow }
    
    /// The app's visible and hidden windows.
    public var windows: [UIWindow] { return UIScreen.screens.reduce([UIWindow](), { $0 + $1.windows }) }
    
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
    
    func application(_ application: UIApplication, willFinishLaunchingWithOptions launchOptions: [UIApplicationLaunchOptionsKey : Any]?) -> Bool { return true }
    
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplicationLaunchOptionsKey : Any]) -> Bool { return true }
    
    func applicationDidBecomeActive(_ application: UIApplication) { }
    
    func applicationDidEnterBackground(_ application: UIApplication) { }
    
    func applicationWillResignActive(_ application: UIApplication) { }
    
    func applicationWillEnterForeground(_ application: UIApplication) { }
    
    func applicationWillTerminate(_ application: UIApplication) { }
}
