//
//  SDL.swift
//  Cacao
//
//  Created by Alsey Coleman Miller on 6/7/17.
//

import Foundation
import CSDL2
import SDL

// MARK: - Main SDL run loop

@_silgen_name("SDLEventRun")
internal func SDLEventRun() {
    
    #if os(macOS) || swift(>=4.0)
    assert(Thread.current.isMainThread, "Should only be called from main thread")
    #endif
    
    SDL.initialize(subSystems: [.video]).sdlAssert()
    
    defer { SDL.quit() }
    
    let options = UIApplication.shared.options
    
    let delegate = UIApplication.shared.delegate!
    
    var windowOptions: Set<Window.Option> = [.allowRetina, .opengl]
    
    if options.canResizeWindow {
        
        windowOptions.insert(.resizable)
    }
    
    let preferredSize = options.windowSize
    
    let initialWindowSize = preferredSize // can we query for screen resolution?
    
    let window = Window(title: options.windowName, frame: (x: .centered, y: .centered, width: Int(initialWindowSize.width), height:  Int(initialWindowSize.height)), options: windowOptions).sdlAssert()
    
    // create main UIScreen
    let screen = UIScreen(window: window, size: initialWindowSize)
    UIScreen._main = screen
    
    let framesPerSecond = screen.maximumFramesPerSecond
    
    let launchOptions = [UIApplicationLaunchOptionsKey: Any]()
    
    guard delegate.application(UIApplication.shared, willFinishLaunchingWithOptions: launchOptions),
        delegate.application(UIApplication.shared, didFinishLaunchingWithOptions: launchOptions)
        else { options.log?("Application delegate could not launch app"); return }
    
    assert(screen.keyWindow?.rootViewController != nil, "Application windows are expected to have a root view controller at the end of application launch")
    
    defer { delegate.applicationWillTerminate(UIApplication.shared) }
    
    let eventFetcher = UIApplication.shared.eventFetcher
    
    // enter main loop
    let runloop = RunLoop.current
    
    // run until app is finished
    while _UIApp.isDone == false {
        
        let startTime = SDL_GetTicks()
        
        // poll events (should never block)
        let eventCount = eventFetcher.pollEvents()
        
        if eventCount > 0 {
            
            print("Polled \(eventCount) events (\(SDL_GetTicks() - startTime)ms)")
        }
        
        // run loop
        let runLoopStartTime = SDL_GetTicks()
        runloop.run(mode: .defaultRunLoopMode, before: Date() + (1.0 / TimeInterval(framesPerSecond)))
        print("Runloop took (\(SDL_GetTicks() - runLoopStartTime)ms)")
        
        // render to screen
        screen.update()
        
        // sleep to save energy
        let frameDuration = Int(SDL_GetTicks() - startTime)
        
        if frameDuration < (1000 / framesPerSecond) {
            
            SDL_Delay(UInt32((1000 / framesPerSecond) - frameDuration))
        }
    }
}

// MARK: - Assertions

internal extension Bool {
    
    @inline(__always)
    func sdlAssert(function: String = #function, file: StaticString = #file, line: UInt = #line) {
        
        guard self else { sdlFatalError(function: function, file: file, line: line) }
    }
}

internal extension Optional {
    
    @inline(__always)
    func sdlAssert(function: String = #function, file: StaticString = #file, line: UInt = #line) -> Wrapped {
        
        guard let value = self
            else { sdlFatalError(function: function, file: file, line: line) }
        
        return value
    }
}

@_silgen_name("_cacao_sdl_fatal_error")
internal func sdlFatalError(function: String = #function, file: StaticString = #file, line: UInt = #line) -> Never {
    
    if let error = SDL.errorDescription {
        
        fatalError("SDL error: \(error)", file: file, line: line)
        
    } else {
        
        fatalError("An SDL error occurred", file: file, line: line)
    }
}
