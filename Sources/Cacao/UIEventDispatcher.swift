//
//  UIEventDispatcher.swift
//  Cacao
//
//  Created by Alsey Coleman Miller on 11/19/17.
//

import Foundation

internal final class UIEventDispatcher {
    
    private(set) weak var application: UIApplication!
    
    // mainEnvironment
    let environment: UIEventEnvironment
    
    init(application: UIApplication) {
        
        self.application = application
        
        self.environment = UIEventEnvironment(application: application)
    }
}

internal protocol UIEventFetcherSink: class {
    
    func eventFetcherDidReceiveEvents(_ fetcher: UIEventFetcher)
}

extension UIEventDispatcher: UIEventFetcherSink {
    
    func eventFetcherDidReceiveEvents(_ fetcher: UIEventFetcher) {
        
        
    }
}
