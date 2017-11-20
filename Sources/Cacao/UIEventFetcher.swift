//
//  UIEventFetcher.swift
//  Cacao
//
//  Created by Alsey Coleman Miller on 11/19/17.
//

import Foundation
import SDL
import CSDL2

internal final class UIEventFetcher {
    
    // MARK: - Properties
    
    var shouldSignalOnDisplayLink: Bool = false
    
    private(set) weak var eventFetcherSink: UIEventFetcherSink! {
        
        didSet {
            
            // call delegate
            eventFetcherSink?.eventFetcherDidReceiveEvents(self)
        }
    }
    
    private var displayLink: CADisplayLink?
    
    private var runLoop: RunLoop?
    
    private var triggerHandOffEventsRunLoopSource: CFRunLoopSource?
    
    private var eventFilters = [() -> ()]()
    
    private var incomingHIDEvents = SynchronizedArray<SDL_Event>()
    
    private var incomingHIDEventsFiltered = SynchronizedArray<SDL_Event>()
    
    private var countOfDigitizerEventsReceivedSinceLastDisplayLinkCallback = 0
    
    private var didDispatchOneMoveEventSinceLastDisplayLinkCallback: Bool = false
    
    // MARK: - Initialization
    
    deinit {
        
        
    }
    
    init(eventFetcherSink: UIEventFetcherSink) {
        
        self.setupThreadAndRun()
        self.eventFetcherSink = eventFetcherSink
    }
    
    // MARK: - Methods
    
    private func setupThreadAndRun() {
        
        assert(Thread.current.isMainThread, "Should only be called from main thread")
        
        let thread: Thread
        
        if #available(OSX 10.12, *) {
            
            thread = Thread { [weak self] in self?.threadMain() }
            
        } else {
            
            thread = Thread(target: self, selector: #selector(threadMainSelector), object: nil)
        }
        
        thread.qualityOfService = .userInteractive
        
        thread.name = "org.pureswift.cacao.eventfetch-thread"
        
        thread.start()
        
        // release thread via ARC
    }
    
    private func filterEvents() {
        
        // call delegate
        eventFetcherSink?.eventFetcherDidReceiveEvents(self)
    }
    
    // Should always run on background thread
    // com.apple.uikit.eventfetch-thread
    internal func threadMain() {
        
        assert(Thread.current.isMainThread == false, "Should only be called from background thread")
        
        let runLoop = RunLoop.current
        
        self.setup(for: runLoop)
        
        runLoop.run()
    }
    
    #if os(macOS)
    @objc private func threadMainSelector() { self.threadMain() }
    #endif
    
    private func setup(for runLoop: RunLoop) {
        
        self.runLoop = runLoop
        
        self.eventFilters.append {
            
            // filter certain events
        }
        
        setupFilterChain()
        
        // triggerHandOff
        filterEvents()
        
        self.displayLink = CADisplayLink { [weak self] in self?.displayLinkDidFire($0) }
    }
    
    private func setupFilterChain() {
        
        
    }
    
    private func displayLinkDidFire(_ sender: CADisplayLink) {
        
        let filteredEventCount = incomingHIDEventsFiltered.count
        
        if self.countOfDigitizerEventsReceivedSinceLastDisplayLinkCallback > 0 {
            
            if self.shouldSignalOnDisplayLink {
                
                
                signaleven
                
            }
            
        } else {
            
            
        }
        
        
        
        // reset counter
        self.countOfDigitizerEventsReceivedSinceLastDisplayLinkCallback = 0
    }
    
    private func receiveHIDEvent(_ event: SDL_Event) {
        
        guard let runLoop = self.runLoop?.getCFRunLoop()
            else { return }
        
        CFRunLoopPerformBlock(runLoop, CFRunLoopMode.commonModes.rawValue) { [weak self] in self?._receiveHIDEvent(event) }
        
        CFRunLoopWakeUp(runLoop)
    }
    
    private func _receiveHIDEvent(_ event: SDL_Event) {
        
        assert(RunLoop.current === self.runLoop, "Should only be called from \(self) run loop")
        
        // access safely and add to queue of incoming events
        self.incomingHIDEvents.append(event)
        
        // signal
        if let source = self.triggerHandOffEventsRunLoopSource {
            CFRunLoopSourceSignal(source)
        }
        
        // determine if digitizer event
        let isDigitizerEvent: Bool
        
        let eventType = SDL_EventType(event.type)
        
        switch eventType {
            
        case SDL_MOUSEBUTTONDOWN, SDL_MOUSEBUTTONUP, SDL_MOUSEMOTION:
            
            isDigitizerEvent = true
            
        default:
            
            isDigitizerEvent = false
        }
        
        // increment digitizer event count
        if isDigitizerEvent, self.displayLink != nil {
            
            self.countOfDigitizerEventsReceivedSinceLastDisplayLinkCallback += 1
        }
    }
    
    private func signalEventsAvailable(with reason: UInt = 0, filteredEventCount: Int) {
        
        self.shouldSignalOnDisplayLink = false
        self.eventFetcherSink?.eventFetcherDidReceiveEvents(self)
    }
}

// MARK: - Supporting Types

internal protocol UIEventFetcherSink: class {
    
    func eventFetcherDidReceiveEvents(_ fetcher: UIEventFetcher)
}
