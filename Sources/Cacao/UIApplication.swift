//
//  UIApplication.swift
//  Cacao
//
//  Created by Alsey Coleman Miller on 6/7/17.
//

import Foundation
import CSDL2
import SDL
import Silica
import Cairo

// MARK: - UIApplicationMain

@_silgen_name("UIApplicationMain")
public func UIApplicationMain(delegate: UIApplicationDelegate, options: CacaoOptions = CacaoOptions()) {
    
    _UIApp = UIApplication(delegate: delegate, options: options)
    
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
        else { options.log?("Application delegate could not launch app"); return }
    
    defer { delegate.applicationWillTerminate(UIApplication.shared) }
    
    // enter main loop
    
    let framesPerSecond = screen.maximumFramesPerSecond
    
    var frame = 0
    
    let eventPoller = SDLEventPoller(screen: screen)
    
    while !eventPoller.done {
        
        frame += 1
        
        let startTime = SDL_GetTicks()
        
        eventPoller.poll()
        
        // render to screen
        screen.update()
        
        // sleep to save energy
        let frameDuration = Int(SDL_GetTicks() - startTime)
        
        if frameDuration < (1000 / framesPerSecond) {
            
            SDL_Delay(UInt32((1000 / framesPerSecond) - frameDuration))
        }
    }
}

/// Cacao-specific application launch settings
public struct CacaoOptions {
    
    public var windowName: String = "App"
    
    public var windowSize: CGSize = CGSize(width: 600, height: 480)
        
    public var canResizeWindow: Bool = true
    
    public var log: ((String) -> ())?
    
    public init() { }
}

internal private(set) var _UIApp: UIApplication!

public final class UIApplication: UIResponder {
    
    // MARK: - Getting the App Instance
    
    public static var shared: UIApplication { return _UIApp }
    
    private override init() { fatalError() }
    
    fileprivate init(delegate: UIApplicationDelegate, options: CacaoOptions) {
        super.init()
        
        assert(_UIApp == nil, "\(type(of: self)) is a singleton and should only be initialized once.")
        
        self.delegate = delegate
        self.options = options
    }
        
    // MARK: - Getting the App Delegate
    
    public fileprivate(set) weak var delegate: UIApplicationDelegate?
    
    // MARK: - Getting App Windows
    
    /// The app's key window.
    public var keyWindow: UIWindow? { return keyWindow(for: UIScreen.main) }
    
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
    
    // MARK: - Private
    
    internal let options: CacaoOptions
    
    internal lazy var eventFetcher: UIEventFetcher = UIEventFetcher(eventFetcherSink: self.eventDispatcher)
    
    internal lazy var eventDispatcher: UIEventDispatcher = UIEventDispatcher(application: self)
    
    internal lazy var gestureEnvironment: UIGestureEnvironment = UIGestureEnvironment()
    
    private var touchesEvent: UITouchesEvent?
    
    internal private(set) var alwaysHitTestsForMainScreen: Bool = false
    
    private func keyWindow(for screen: UIScreen) -> UIWindow? {
        
        return screen.keyWindow
    }
    
    private func sendHeadsetOriginatedMediaRemoteCommand() {
        
        
    }
    
    private func sendWillEnterForegroundCallbacks() {
        
        
    }
    
    // Scroll to top
    private func scrollsToTopInitiatorView() {
        
        
    }
    
    private func shouldAttemptOpenURL() {  }
    
    private var isRunningInTaskSwitcher: Bool = false
}

fileprivate extension UIApplication {
    
    func run() {
        
        // register for changes, if possible
        
        // get main run loop
        let mainRunLoop = RunLoop.main
        
        // install the run loop source for the event dispatcher
        self.eventDispatcher.installEventRunLoopSources(mainRunLoop)
        
        // start polling for SDL events
        SDLEventRun()
    }
}

@_silgen_name("UIApplicationHandleEvent")
private func UIApplicationHandleEvent() {
    
    
}

// MARK: - Supporting Types

public protocol UIApplicationDelegate: class {
    
    func application(_ application: UIApplication, willFinishLaunchingWithOptions launchOptions: [UIApplicationLaunchOptionsKey : Any]?) -> Bool
    
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplicationLaunchOptionsKey : Any]?) -> Bool
    
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
    
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplicationLaunchOptionsKey : Any]?) -> Bool { return true }
    
    func applicationDidBecomeActive(_ application: UIApplication) { }
    
    func applicationDidEnterBackground(_ application: UIApplication) { }
    
    func applicationWillResignActive(_ application: UIApplication) { }
    
    func applicationWillEnterForeground(_ application: UIApplication) { }
    
    func applicationWillTerminate(_ application: UIApplication) { }
}
