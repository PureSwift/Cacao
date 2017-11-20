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
    
    // delegate
    private(set) weak var eventFetcherSink: UIEventFetcherSink! {
        
        didSet { signalEventsAvailable(with: .sinkChanged) }
    }
    
    private var displayLink: CADisplayLink?
    
    private var runLoop: RunLoop?
    
    private var triggerHandOffEventsRunLoopSource: CFRunLoopSource?
    
    private var eventFilters = [() -> ()]()
    
    private var incomingHIDEvents = [SDL_Event]()
    
    private var incomingHIDEventsFiltered = [SDL_Event]()
    
    private var countOfDigitizerEventsReceivedSinceLastDisplayLinkCallback = 0
    
    private var didDispatchOneMoveEventSinceLastDisplayLinkCallback: Bool = false
    
    private var lastImportantEventTimestamp: Double = 0
    
    private var commitTimeForTouchEvents: TimeInterval = 0
    
    // MARK: - Initialization
    
    deinit {
        
        
    }
    
    init(eventFetcherSink: UIEventFetcherSink) {
        
        self.eventFetcherSink = eventFetcherSink
    }
    
    // MARK: - Methods
    
    private func filterEvents() {
        
        // pause display link
        /*
        if let displayLink = self.displayLink,
            displayLink.isPaused == false,
            incomingHIDEvents.isEmpty == false {
            
            displayLink.isPaused = true
        }*/
        
        // call delegate
        eventFetcherSink?.eventFetcherDidReceiveEvents(self)
    }
    
    // Should always run on background thread
    // com.apple.uikit.eventfetch-thread
    internal func threadMain() {
        
        assert(Thread.current.isMainThread == false, "Should only be called from background thread")
        
        let runLoop = RunLoop.current
        
        self.setup(for: runLoop)
        
        // run forever
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
                
                self.signalEventsAvailable(with: .displayLinkDidFire, filteredEventCount: filteredEventCount)
            }
            
        } else {
            
            if filteredEventCount > 0 {
                
                self.signalEventsAvailable(with: .displayLinkDidFire, filteredEventCount: filteredEventCount)
                
            } else {
                
                if let displayLink = self.displayLink, displayLink.isPaused == false {
                    
                    displayLink.isPaused = true
                }
            }
        }
        
        // reset counter
        self.didDispatchOneMoveEventSinceLastDisplayLinkCallback = false
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
    
    private func signalEventsAvailable(with reason: EventsAvailableReason = .none, filteredEventCount: Int = 0) {
        
        // log signaling reason
        UIApplication.shared.options.log?("\(#function) with reason \(reason) and \(filteredEventCount) filtered events.")
        
        // signal
        self.shouldSignalOnDisplayLink = false
        self.eventFetcherSink?.eventFetcherDidReceiveEvents(self)
    }
    
    internal func drainEvents(into environment: UIEventEnvironment) {
        
        incomingHIDEventsFiltered.forEach { environment.enqueueHIDEvent($0)  }
        
        incomingHIDEventsFiltered.removeAll()
        
        environment.commitTimeForTouchEvents = self.commitTimeForTouchEvents
    }
    
    /// Poll SDL events on the main run loop
    internal func pollEvents() {
        
        assert(Thread.current.isMainThread)
        
        // poll event queue
        
        var sdlEvent = SDL_Event()
        
        // get all events in SDL event queue
        while SDL_PollEvent(&sdlEvent) != 0 {
            
            incomingHIDEvents.append(sdlEvent)
        }
    }
}

// MARK: - Supporting Types

private extension UIEventFetcher {
    
    enum EventsAvailableReason {
        
        case none
        case sinkChanged // 0x1
        case displayLinkDidFire // 0x2
    }
}

internal protocol UIEventFetcherSink: class {
    
    func eventFetcherDidReceiveEvents(_ fetcher: UIEventFetcher)
}
