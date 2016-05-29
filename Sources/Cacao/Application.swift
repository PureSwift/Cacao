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
    
    var preferredWindowSize: Size { get }
    
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
        
        let windowFlags = SDL_WINDOW_RESIZABLE.rawValue | SDL_WINDOW_ALLOW_HIGHDPI.rawValue
        
        var windowSize = preferredWindowSize
        
        let windowPosition: Int32 = 0x1FFF0000 // undefined
        
        let window = SDL_CreateWindow(
            name,
            windowPosition,
            windowPosition,
            CInt(windowSize.width),
            CInt(windowSize.height),
            windowFlags)!
        
        defer { SDL_DestroyWindow(window) }
        
        // create image buffers and screen
        
        var screen: Screen!
        
        var sdlImageSurface: UnsafeMutablePointer<SDL_Surface>!
        
        defer { SDL_FreeSurface(sdlImageSurface) }
        
        func updateScreenBuffers() {
            
            // free old buffer
            if sdlImageSurface != nil {
                
                SDL_FreeSurface(sdlImageSurface)
            }
            
            /*
            // calculate native pixels
            let nativeSize: Size = {
                
                var w: Int32 = 0
                var h: Int32 = 0
                
                SDL_GL_GetDrawableSize(window, &w, &h)
                
                return Size(width: Double(w), height: Double(h))
            }()*/
            
            let nativeSize = windowSize // FIXME: Retina display
            
            sdlImageSurface = SDL_CreateRGBSurface(0, CInt(nativeSize.width), CInt(nativeSize.height), 32, 0, 0, 0, 0)!
            
            let cairoSurfacePointer = cairo_image_surface_create_for_data(UnsafeMutablePointer<UInt8>(sdlImageSurface.pointee.pixels), CAIRO_FORMAT_ARGB32, sdlImageSurface.pointee.w, sdlImageSurface.pointee.h, sdlImageSurface.pointee.pitch)!
            
            let surface = Cairo.Surface(cairoSurfacePointer)
            
            if screen == nil {
                
                screen = Screen(surface: surface, nativeSize: nativeSize, size: windowSize)
                
            } else {
                
                screen.target = (surface, nativeSize, windowSize)
            }
        }
        
        updateScreenBuffers()
        
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
                    
                case SDL_QUIT, SDL_APP_TERMINATING:
                    
                    done = true
                    
                case SDL_MOUSEBUTTONDOWN, SDL_MOUSEBUTTONUP:
                    
                    /*
                    let SDL_TOUCH_MOUSEID = -1
                    
                    guard event.button.which != SDL_TOUCH_MOUSEID
                        else { return }*/
                    
                    screen.handle(event: PointerEvent(event.button))
                    
                case SDL_FINGERDOWN, SDL_FINGERUP: break
                    
                    
                    
                case SDL_WINDOWEVENT:
                    
                    switch event.window.event {
                        
                    case UInt8(SDL_WINDOWEVENT_SIZE_CHANGED.rawValue):
                        
                        windowSize = Size(width: Double(event.window.data1), height: Double(event.window.data2))
                        
                        updateScreenBuffers()
                        
                    default: break
                    }
                    
                default: break
                }
                
                // try again
                pollEventStatus = SDL_PollEvent(&event)
            }
            
            // inform responder chain
            
            // render to screen
            if needsDisplay {
                
                try! screen.render()
                
                screen.target.surface.flush()
                
                guard SDL_UpperBlit(sdlImageSurface, nil, SDL_GetWindowSurface(window)!, nil) == 0
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
