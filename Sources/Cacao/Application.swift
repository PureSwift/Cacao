//
//  Application.swift
//  Cacao
//
//  Created by Alsey Coleman Miller on 5/21/16.
//  Copyright © 2016 PureSwift. All rights reserved.
//

import CSDL2
import Silica
import Cairo
import CCairo

public protocol Application: class {
    
    func didFinishLaunching(screen: Screen)
    
    func willTerminate()
    
    var name: String { get }
    
    var windowSize: Size { get set }
    
    var framesPerSecond: Int { get set }
}

// MARK: - Main

public extension Application {
    
    /// Enter main application loop.
    func main() {
        
        // setup SDL window
        
        let options: UInt32 = UInt32(SDL_INIT_VIDEO)
        
        guard SDL_Init(options) >= 0
            else { fatalError("Could not initialize SDL") }
        
        let windowSize = self.windowSize
        
        let window = SDL_CreateWindow(
            self.name,
            0,
            0,
            CInt(windowSize.width),
            CInt(windowSize.height),
            0
            )!
        
        defer { SDL_DestroyWindow(window) }
        
        let sdlWindowSurface = SDL_GetWindowSurface(window)!
        
        guard let sdlImageSurface = SDL_CreateRGBSurface(0, CInt(windowSize.width), CInt(windowSize.height), 32, 0, 0, 0, 0)
            else { fatalError("Could not create SDL surface: \(SDL_GetError())") }
        
        defer { SDL_FreeSurface(sdlImageSurface) }
        
        guard let cairoSurfacePointer = cairo_image_surface_create_for_data(UnsafeMutablePointer<UInt8>(sdlImageSurface.pointee.pixels), CAIRO_FORMAT_ARGB32, sdlImageSurface.pointee.w, sdlImageSurface.pointee.h, sdlImageSurface.pointee.pitch)
            else { fatalError("Could not create Cairo Image surface") }
        
        let surface = Cairo.Surface(cairoSurfacePointer)
        
        let screen = Screen(surface: surface, size: windowSize)
        
        // define FPS
        
        let framesPerSecond: UInt32
        
        var sdlDisplayMode = SDL_DisplayMode()
        
        if SDL_GetWindowDisplayMode(window, &sdlDisplayMode) == 0 && sdlDisplayMode.refresh_rate != 0 {
            
            framesPerSecond = UInt32(sdlDisplayMode.refresh_rate)
            
            self.framesPerSecond = Int(framesPerSecond)
            
        } else {
            
            framesPerSecond = UInt32(self.framesPerSecond)
        }
        
        self.didFinishLaunching(screen: screen)
        
        // enter main loop
        
        var frame = 0
        
        var done = false
        
        var event = SDL_Event()
        
        while !done {
            
            frame += 1
            
            let startTime = SDL_GetTicks()
            
            // poll event queue
            
            var pollEventStatus = SDL_PollEvent(&event)
            
            var needsDisplay = false //screen.rootViewController?.needsDisplay ?? false
            
            while pollEventStatus != 0 {
                
                needsDisplay = true
                
                let eventType = SDL_EventType(rawValue: event.type)
                
                switch eventType {
                    
                case SDL_QUIT:
                    
                    done = true
                    
                default: break
                }
                
                // try again
                pollEventStatus = SDL_PollEvent(&event)
            }
            
            // inform responder chain
            
            // render to screen
            if needsDisplay {
                
                try! screen.render()
                
                surface.flush()
                
                guard SDL_UpperBlit(sdlImageSurface, nil, sdlWindowSurface, nil) == 0
                    else { fatalError("Could not render to screen: \(SDL_GetError())") }
                
                SDL_UpdateWindowSurface(window)
            }
            
            // sleep to save energy
            let frameDuration = SDL_GetTicks() - startTime
            
            if frameDuration < 1000 / framesPerSecond {
                
                SDL_Delay((1000 / framesPerSecond) - frameDuration)
            }
        }
        
        // quit application
        
        self.willTerminate()
        
        SDL_Quit()
    }
}
