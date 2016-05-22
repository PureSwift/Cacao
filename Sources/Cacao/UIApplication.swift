//
//  UIApplication.swift
//  Cacao
//
//  Created by Alsey Coleman Miller on 5/21/16.
//  Copyright © 2016 PureSwift. All rights reserved.
//

import CSDL2
import Silica
import Cairo
import CCairo

// MARK: - Main

public func UIApplicationMain<Delegate: UIApplicationDelegate>(delegateClass: Delegate.Type, size: Size = Size(width: 640, height: 480)) {
    
    let options: UInt32 = UInt32(SDL_INIT_VIDEO)
    
    guard SDL_Init(options) >= 0
        else { fatalError("Could not initialize SDL") }
        
    let window = SDL_CreateWindow(
        "Application",
        0,
        0,
        CInt(size.width),
        CInt(size.height),
        0
    )
    
    let sdlWindowSurface = SDL_GetWindowSurface(window)!
    
    guard let sdlImageSurface = SDL_CreateRGBSurface(0, CInt(size.width), CInt(size.height), 32, 0x00FF0000, 0x0000FF00, 0x000000FF, 0)
        else { fatalError("Could not create SDL surface: \(SDL_GetError())") }
    
    defer { SDL_FreeSurface(sdlImageSurface) }
    
    guard let cairoSurfacePointer = cairo_image_surface_create_for_data(UnsafeMutablePointer<UInt8>(sdlImageSurface.pointee.pixels), CAIRO_FORMAT_RGB24, sdlImageSurface.pointee.w, sdlImageSurface.pointee.h, sdlImageSurface.pointee.pitch)
        else { fatalError("Could not create Cairo Image surface") }
    
    let surface = Cairo.Surface(cairoSurfacePointer)
    
    UIScreen.main = try! UIScreen(surface: surface, size: size)
    
    let appDelegate = Delegate()
    
    UIApplication.shared.delegate = appDelegate
    
    UIApplication.shared.delegate?.application(UIApplication.shared, didFinishLaunchingWithOptions: nil)
    
    // enter main loop
    
    var done = false
    
    var event = SDL_Event()
    
    while !done {
        
        // poll event queue
        
        var pollEventStatus = SDL_PollEvent(&event)
        
        while pollEventStatus != 0 {
            
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
        
        
        // update UI
        
        try! UIScreen.main.render()
        
        surface.flush()
        
        SDL_UpperBlit(sdlImageSurface, nil, sdlWindowSurface, nil)
        
        SDL_UpdateWindowSurface(OpaquePointer(sdlWindowSurface))
    }
    
    UIApplication.shared.delegate?.applicationWillTerminate(UIApplication.shared)
    
    SDL_Quit()
}

// MARK: - UIApplicationDelegate

public protocol UIApplicationDelegate: class {
    
    init()
    
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [String : Any]?) -> Bool
    
    func applicationWillTerminate(_ application: UIApplication)
}

public extension UIApplicationDelegate {
    
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [String : Any]?) -> Bool {
        
        return true
    }
    
    func applicationWillTerminate(_ application: UIApplication) { }
}

// MARK: - UIApplication

public final class UIApplication {
    
    public static private(set) var shared = UIApplication()
    
    public weak var delegate: UIApplicationDelegate?
    
    
}