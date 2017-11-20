//
//  UIEventDispatcher.swift
//  Cacao
//
//  Created by Alsey Coleman Miller on 11/19/17.
//

import Foundation
import CoreFoundation

internal final class UIEventDispatcher {
    
    private(set) weak var application: UIApplication!
    
    // mainEnvironment
    let environment: UIEventEnvironment
    
    private var runLoop: RunLoop?
    
    private weak var handleEventQueueRunLoopSource: CFRunLoopSource?
    
    private weak var collectHIDEventsRunLoopSource: CFRunLoopSource?
    
    private weak var eventFetcher: UIEventFetcher?
    
    init(application: UIApplication) {
        
        self.application = application
        
        self.environment = UIEventEnvironment(application: application)
    }
    
    internal func installEventRunLoopSources(_ runLoop: RunLoop) {
        
        assert(self.runLoop == nil, "RunLoop already installed")
        
        self.runLoop = runLoop
        self.eventFetcher = self.environment.application.eventFetcher
        
        var source: CFRunLoopSource
        var sourceContext = CFRunLoopSourceContext()
        
        sourceContext.info = Unmanaged.passUnretained(environment).toOpaque()
        sourceContext.perform = handleEventQueue
        source = CFRunLoopSourceCreate(nil, .max, &sourceContext)
        CFRunLoopAddSource(runLoop.getCFRunLoop(), source, CFRunLoopMode.commonModes)
        self.handleEventQueueRunLoopSource = source
        
        sourceContext.info = Unmanaged.passUnretained(self).toOpaque()
        sourceContext.perform = handleHIDEventFetcherDrain
        source = CFRunLoopSourceCreate(nil, .max, &sourceContext)
        CFRunLoopAddSource(runLoop.getCFRunLoop(), source, CFRunLoopMode.commonModes)
        self.collectHIDEventsRunLoopSource = source
    }
}

internal protocol UIEventFetcherSink: class {
    
    func eventFetcherDidReceiveEvents(_ fetcher: UIEventFetcher)
}

extension UIEventDispatcher: UIEventFetcherSink {
    
    func eventFetcherDidReceiveEvents(_ fetcher: UIEventFetcher) {
        
        
    }
}

@_silgen_name("___handleEventQueue")
private func handleEventQueue(_ : UnsafeMutableRawPointer?) {
    
    
}

@_silgen_name("___handleHIDEventFetcherDrain")
private func handleHIDEventFetcherDrain(_ : UnsafeMutableRawPointer?) {
    
    
}
