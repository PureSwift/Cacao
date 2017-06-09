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
public func UIApplicationMain(delegate: UIApplicationDelegate, options: CacaoOptions = CacaoOptions()) {
    
    UIApplication.shared.delegate = delegate
    
    SDL.initialize(subSystems: [.video]).sdlAssert()
    
    defer { SDL.quit() }
    
    var windowOptions: Set<Window.Option> = [.allowRetina, .opengl]
    
    if options.canResizeWindow {
        
        windowOptions.insert(.resizable)
    }
    
    let preferredSize = options.windowSize
    
    let initialWindowSize = preferredSize // can we query for screen resolution?
    
    let window = Window(title: options.windowName, frame: (x: .centered, y: .centered, width: Int(initialWindowSize.width), height:  Int(initialWindowSize.height)), options: windowOptions).sdlAssert()
    
    // create UIScreen
    let screen = UIScreen(window: window, size: initialWindowSize)
    UIScreen.main = screen
    
    let launchOptions = [UIApplicationLaunchOptionsKey: Any]()
    
    guard delegate.application(UIApplication.shared, willFinishLaunchingWithOptions: launchOptions),
        delegate.application(UIApplication.shared, didFinishLaunchingWithOptions: launchOptions)
        else { options.log("Application delegate could not launch app"); return }
    
    // enter main loop
    
    let framesPerSecond = screen.maximumFramesPerSecond
    
    var frame = 0
    
    var done = false
    
    var sdlEvent = SDL_Event()
    
    var lastEvent: UIEvent?
    
    while !done {
        
        frame += 1
        
        let startTime = SDL_GetTicks()
        
        // poll event queue
        
        var pollEventStatus: Int32 = 0
        
        repeat {
            
            pollEventStatus = SDL_PollEvent(&sdlEvent)
            
            let eventType = SDL_EventType(rawValue: sdlEvent.type)
            
            let screenLocation = CGPoint(x: Double(sdlEvent.button.x), y: Double(sdlEvent.button.y))
                        
            switch eventType {
                
            case SDL_QUIT, SDL_APP_TERMINATING:
                
                done = true
                
            case SDL_MOUSEBUTTONDOWN, SDL_MOUSEBUTTONUP:
                
                guard sdlEvent.button.which != -1
                    else { return }
                
                let timestamp = Double(sdlEvent.button.timestamp) / 1000
                
                let event = UIEvent(timestamp: timestamp)
                
                /// Only the key window can recieve touch input
                guard let window = UIApplication.shared.keyWindow,
                    let view = window.hitTest(screenLocation, with: event)
                    else { continue }
                
                let touchPhase: UITouchPhase
                
                // mouse released
                if eventType == SDL_MOUSEBUTTONUP {
                    
                    touchPhase = .ended
                    
                } else if let previousTouch = lastEvent?.allTouches?.first {
                    
                    touchPhase = previousTouch.location == screenLocation ? .stationary : .moved
                    
                    if view != previousTouch.view {
                        
                        // TODO
                    }
                    
                } else {
                    
                    touchPhase = .began
                }
                
                if let previousTouch = lastEvent?.allTouches?.first {
                    
                    // guard againt multiple touchesEnded events
                    guard (previousTouch.phase == .ended && touchPhase == .ended) == false
                        else { continue }
                }
                
                let touch = UITouch(timestamp: timestamp, location: screenLocation, phase: touchPhase, view: view, window: window)
                
                event.allTouches?.insert(touch)
                
                // inform responder chain
                window.sendEvent(event)
                
                lastEvent = event
                
            case SDL_WINDOWEVENT:
                
                switch sdlEvent.window.event {
                    
                case UInt8(SDL_WINDOWEVENT_SIZE_CHANGED.rawValue):
                    
                    screen.updateSize()
                    
                default: break
                }
                
            default: break
            }
            
        } while pollEventStatus != 0
        
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
    
    public var windowSize: Size = Size(width: 600, height: 480)
        
    public var canResizeWindow: Bool = true
    
    public var log: (String) -> () = { print($0) }
    
    public init() { }
}

public final class UIApplication: UIResponder {
    
    // MARK: - Getting the App Instance
    
    public static var shared = UIApplication()
        
    // MARK: - Getting the App Delegate
    
    public fileprivate(set) weak var delegate: UIApplicationDelegate?
    
    // MARK: - Getting App Windows
    
    /// The app's key window.
    public var keyWindow: UIWindow? { return UIScreen.main.keyWindow }
    
    /// The app's visible and hidden windows.
    public var windows: [UIWindow] { return UIScreen.screens.reduce([UIWindow](), { $0 + $1.windows }) }
    
    // MARK: - Controlling and Handling Events
    
    /// Dispatches an event to the appropriate responder objects in the app.
    ///
    /// - Parameter event: A UIEvent object encapsulating the information about an event, including the touches involved.
    ///
    /// If you require it, you can intercept incoming events by subclassing UIApplication and overriding this method.
    /// For every event you intercept, you must dispatch it by calling super`sendEvent()`
    /// after handling the event in your implementation.
    public func sendEvent(_ event: UIEvent) {
        
        keyWindow?.sendEvent(event)
    }
    
    public func sendAction(_ selector: String, to target: AnyObject?, from sender: AnyObject?, for event: UIEvent?) {
        
        
    }
    
    public func beginIgnoringInteractionEvents() {
        
        isIgnoringInteractionEvents = true
    }
    
    public func endIgnoringInteractionEvents() {
        
        isIgnoringInteractionEvents = false
    }
    
    public private(set) var isIgnoringInteractionEvents: Bool = false
    
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
