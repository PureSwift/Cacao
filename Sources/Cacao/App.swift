//
//  App.swift
//  Cacao
//
//  Created by Alsey Coleman Miller on 12/14/24.
//

import Foundation
import SDL
import CSDL2

/// Cacao App
@MainActor
public protocol App {
    
    static var window: Window { get }
}

public extension App {
    
    @MainActor
    static func main() throws {
        
        assert(Thread.current.isMainThread, "Should only be called from main thread")
                
        try SDL.initialize(subSystems: [.video, .joystick, .gameController, .events])
        defer { SDL.quit() }
        
        // create window
        _ = self.window
        
        // run loop
        try AppCoordinator.shared.run()
    }
}

@MainActor
final class AppCoordinator {
    
    var isRunning = true
    
    let runloop = RunLoop.main
    
    var windows: [Window] {
        Window.windows
    }
    
    static let shared = AppCoordinator()
    
    private init() {}
    
    func run() throws {
        var framesPerSecond = 60
        var event = SDL_Event()
        while isRunning {
            let startTime = SDL_GetTicks()
            // poll events (should never block)
            while SDL_PollEvent(&event) > 0 {
                handle(event)
            }
            // render to screen
            for window in windows {
                // update FPS if not same
                let windowFramesPerSecond = try window.sdlWindow.displayMode().refreshRate
                if windowFramesPerSecond > framesPerSecond {
                    framesPerSecond = windowFramesPerSecond
                }
                // render image
                try window.update()
            }
            // run main loop
            let runloopTimeout = (1.0 / TimeInterval(framesPerSecond))
            runloop.run(
                mode: .default,
                before: Date() + runloopTimeout
            )
            // sleep to save energy
            let expectedLoopTime = UInt32(1000 / framesPerSecond)
            let frameDuration = SDL_GetTicks() - startTime
            if frameDuration < expectedLoopTime {
                let timeRemaining = expectedLoopTime - frameDuration
                SDL_Delay(timeRemaining)
            }
        }
    }
    
    func handle(_ event: SDL_Event) {
        let eventType = SDL_EventType(rawValue: event.type)
        switch eventType {
        case SDL_QUIT, SDL_APP_TERMINATING:
            // quit app
            isRunning = false
        case SDL_WINDOWEVENT:
            let id = SDLWindow.ID(event.window.windowID)
            let window = self[window: id]
            // window handles event
            window.handle(event.window)
        default:
            break
        }
    }
    
    subscript(window id: SDLWindow.ID) -> Window {
        guard let window = windows.first(where: { $0.sdlWindow.id == id }) else {
            fatalError("No window found for \(id)")
        }
        return window
    }
}
