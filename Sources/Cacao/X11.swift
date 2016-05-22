//
//  UIApplicationX11.swift
//  Cacao
//
//  Created by Alsey Coleman Miller on 5/12/16.
//  Copyright © 2016 PureSwift. All rights reserved.
//

#if os(Linux)
    
    import Glibc
    import CXCB
    import Silica
    
    public func UIApplicationMainX11(size: Size = Size(width: 320, height: 480)) {
        
        // connect to X11
        let connection = xcb_connect(nil, nil)
        
        defer { xcb_disconnect(connection) }
        
        guard xcb_connection_has_error(connection) == 0
            else { fatalError("Cannot open display") }
        
        let screen = xcb_setup_roots_iterator(xcb_get_setup(connection)).data!.pointee
        
        // create graphics context
        
        let graphicsContext = xcb_generate_id(connection)
        
        var window = screen.root
        
        var mask = XCB_GC_FOREGROUND.rawValue | XCB_GC_GRAPHICS_EXPOSURES.rawValue
        
        var values = [screen.black_pixel, 0]
        
        xcb_create_gc(connection, graphicsContext, window, mask, &values)
        
        // create window
        
        window = xcb_generate_id(connection)
        
        mask = XCB_CW_BACK_PIXEL.rawValue | XCB_CW_EVENT_MASK.rawValue
        
        values = [screen.white_pixel, XCB_EVENT_MASK_EXPOSURE.rawValue | XCB_EVENT_MASK_KEY_PRESS.rawValue]
        
        xcb_create_window(connection, screen.root_depth, window, screen.root,
                          10, 10, UInt16(size.width), UInt16(size.height), 1,
                          UInt16(XCB_WINDOW_CLASS_INPUT_OUTPUT.rawValue), screen.root_visual,
                          mask, values)
        
        xcb_map_window(connection, window)
        
        xcb_flush(connection)
        
        // create Cairo surface
        
        //let surfacePointer = cairo_xcb_surface_create(connection, window)
        
        
        // main loop
        
        var done = false
        
        while !done {
            
            let event = xcb_wait_for_event(connection)!
            defer { free(event) }
            
            let eventType = event.pointee.response_type & ~0x80
            
            
        }
    }
    
#endif
