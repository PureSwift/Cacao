//
//  UIEventDispatcher.swift
//  Cacao
//
//  Created by Alsey Coleman Miller on 11/19/17.
//

import Foundation
import CoreFoundation

internal final class UIEventDispatcher {
    
    // MARK: - Properties
    
    private(set) weak var application: UIApplication!
    
    // mainEnvironment
    let environment: UIEventEnvironment
    
    fileprivate var runLoop: RunLoop?
    
    fileprivate weak var handleEventQueueRunLoopSource: CFRunLoopSource?
    
    fileprivate weak var collectHIDEventsRunLoopSource: CFRunLoopSource?
    
    fileprivate var eventFetcher: UIEventFetcher?
    
    // MARK: - Initialization
    
    init(application: UIApplication) {
        
        self.application = application
        
        self.environment = UIEventEnvironment(application: application)
    }
    
    // MARK: - Methods
    
    internal func installEventRunLoopSources(_ runLoop: RunLoop) {
        
        assert(self.runLoop == nil, "RunLoop already installed")
        
        self.runLoop = runLoop
        self.eventFetcher = self.environment.application.eventFetcher
        
        var source: CFRunLoopSource
        var sourceContext = CFRunLoopSourceContext()
        
        #if os(macOS)
        let runLoopMode = CFRunLoopMode.defaultMode
        #else
        let runLoopMode = kCFRunLoopDefaultMode
        #endif
        
        sourceContext.info = Unmanaged.passUnretained(environment).toOpaque()
        sourceContext.perform = _handleEventQueue
        source = CFRunLoopSourceCreate(nil, .max, &sourceContext)
        CFRunLoopAddSource(runLoop.getCFRunLoop(), source, runLoopMode)
        self.handleEventQueueRunLoopSource = source
        
        sourceContext.info = Unmanaged.passUnretained(self).toOpaque()
        sourceContext.perform = _handleHIDEventFetcherDrain
        source = CFRunLoopSourceCreate(nil, .max, &sourceContext)
        CFRunLoopAddSource(runLoop.getCFRunLoop(), source, runLoopMode)
        self.collectHIDEventsRunLoopSource = source
    }
    
    internal func handleHIDEventFetcherDrain() {
                
        eventFetcher?.drainEvents(into: environment)
        environment.handleEventQueue()
    }
}

// MARK: - UIEventFetcherSink

extension UIEventDispatcher: UIEventFetcherSink {
    
    func eventFetcherDidReceiveEvents(_ eventFetcher: UIEventFetcher) {
        
        assert(self.eventFetcher === eventFetcher)
        
        CFRunLoopSourceSignal(collectHIDEventsRunLoopSource)
        CFRunLoopWakeUp(runLoop?.getCFRunLoop())
    }
}

// MARK: - Private Functions

@_silgen_name("___handleEventQueue")
private func _handleEventQueue(_ objectPointer: UnsafeMutableRawPointer?) {
    
    let environment = Unmanaged<UIEventEnvironment>.fromOpaque(objectPointer!).takeUnretainedValue()
    
    environment.handleEventQueue()
}

@_silgen_name("___handleHIDEventFetcherDrain")
private func _handleHIDEventFetcherDrain(_ objectPointer: UnsafeMutableRawPointer?) {
    
    let eventDispatcher = Unmanaged<UIEventDispatcher>.fromOpaque(objectPointer!).takeUnretainedValue()
    
    eventDispatcher.handleHIDEventFetcherDrain()
}
