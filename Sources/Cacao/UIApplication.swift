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
    
    // initialize singleton application
    _UIApp = UIApplication(delegate: delegate, options: options)
    
    // enter main loop
    _UIApp.run()
    
    // start polling for SDL events
    SDLEventRun()
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
    
    fileprivate init(delegate: UIApplicationDelegate, options: CacaoOptions) {
        
        assert(_UIApp == nil, "\(UIApplication.self) is a singleton and should only be initialized once.")
        
        self.options = options
        self.delegate = delegate
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
        
        self.windows.forEach { $0.sendEvent(event) }
    }
    
    public func sendAction(_ selector: String,
                           to target: AnyObject?,
                           from sender: AnyObject?,
                           for event: UIEvent?) {
        
        
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
    
    internal private(set) var isDone: Bool = false
    
    internal lazy var eventFetcher: UIEventFetcher = UIEventFetcher(eventFetcherSink: self.eventDispatcher)
    
    internal lazy var eventDispatcher: UIEventDispatcher = UIEventDispatcher(application: self)
    
    internal lazy var gestureEnvironment: UIGestureEnvironment = UIGestureEnvironment()
    
    internal var touchesEvent: UITouchesEvent? { return eventDispatcher.environment.touchesEvent }
    
    internal var physicalKeyboardEvent: UIPhysicalKeyboardEvent? { return eventDispatcher.environment.physicalKeyboardEvent }
    
    internal var wheelEvent: UIWheelEvent? { return eventDispatcher.environment.wheelEvent }
    
    internal private(set) var alwaysHitTestsForMainScreen: Bool = false
    
    internal func quit() {
        
        self.isDone = true
    }
    
    internal func lowMemory() {
        
        
    }
    
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
    
    public override func wheelChanged(with event: UIWheelEvent) {
        
        super.wheelChanged(with: event)
    }
    
    internal func sendButtonEvent(with pressInfo: UIPressInfo) {
        
        
    }
    
    internal func handlePhysicalButtonEvent(_ event: UIPhysicalKeyboardEvent) {
        
        
    }
    
    public override func becomeFirstResponder() -> Bool {
        
        return keyWindow?.becomeFirstResponder() ?? false
    }
}

fileprivate extension UIApplication {
    
    func run() {
        
        // register for changes, if possible
        
        // get main run loop
        let mainRunLoop = RunLoop.main
        
        // install the run loop source for the event dispatcher
        self.eventDispatcher.installEventRunLoopSources(mainRunLoop)
    }
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
