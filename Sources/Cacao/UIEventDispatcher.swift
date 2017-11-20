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
        
        var sourceContext = CFRunLoopSourceContext()
        sourceContext.info = Unmanaged.passUnretained(environment).toOpaque()
        sourceContext.perform = handleEventQueue
        
        CFRunLoopSourceCreate(nil, 0xffffffffffffffff, &sourceContext)
        
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
private func handleEventQueue(_ :U nsafeMutableRawPointer?) {
    
    
}
