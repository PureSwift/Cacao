//
//  UIEventFetcher.swift
//  Cacao
//
//  Created by Alsey Coleman Miller on 11/19/17.
//

import Foundation
import SDL
import CSDL2

/// Polls the events and signals event availiblity to its delegate.
internal final class UIEventFetcher {
    
    // MARK: - Properties
    
    // delegate
    private(set) weak var eventFetcherSink: UIEventFetcherSink! {
        
        didSet { signalEventsAvailable(with: .sinkChanged) }
    }
    
    // The queue of incoming events
    private var incomingHIDEvents = [SDL_Event]()
    
    // timer used to push events along with display refresh
    private var displayLink: CADisplayLink!
    
    // MARK: - Initialization
    
    init(eventFetcherSink: UIEventFetcherSink) {
        
        self.eventFetcherSink = eventFetcherSink
        self.displayLink = CADisplayLink { [weak self] in self?.displayLinkDidFire($0) }
    }
    
    // MARK: - Methods
    
    /// Poll SDL events on the main run loop
    internal func pollEvents() {
        
        #if os(macOS) || swift(>=4.0)
        assert(Thread.current.isMainThread, "Should only be called from main thread")
        #endif
        
        // poll event queue
        
        var sdlEvent = SDL_Event()
        
        // get all events in SDL event queue
        while SDL_PollEvent(&sdlEvent) != 0 {
            
            self.receiveHIDEvent(sdlEvent)
        }
        
        // signal events availible
        self.signalEventsAvailable(with: .eventsPolled)
    }
    
    private func receiveHIDEvent(_ event: SDL_Event) {
        
        // add to queue of incoming events
        self.incomingHIDEvents.append(event)
        
        /*
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
        }*/
    }
    
    private func displayLinkDidFire(_ sender: CADisplayLink) {
        /*
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
        */
    }
    
    private func signalEventsAvailable(with reason: EventsAvailableReason = .none) {
        
        // log signaling reason
        UIApplication.shared.options.log?("\(#function) with reason \(reason)")
        
        // signal
        //self.shouldSignalOnDisplayLink = false
        self.eventFetcherSink?.eventFetcherDidReceiveEvents(self)
    }
    
    internal func drainEvents(into environment: UIEventEnvironment) {
        
        incomingHIDEvents.forEach { environment.enqueueHIDEvent($0)  }
        
        incomingHIDEvents.removeAll()
    }
}

// MARK: - Supporting Types

internal protocol UIEventFetcherSink: class {
    
    func eventFetcherDidReceiveEvents(_ fetcher: UIEventFetcher)
}

private extension UIEventFetcher {
    
    enum EventsAvailableReason {
        
        case none
        case sinkChanged // 0x1
        case displayLinkDidFire // 0x2
        case eventsPolled // 0x3
    }
}
