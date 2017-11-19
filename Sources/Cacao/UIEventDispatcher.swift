//
//  UIEventDispatcher.swift
//  Cacao
//
//  Created by Alsey Coleman Miller on 11/19/17.
//

import Foundation

internal UIEventDispatcher {
    
    let application: UIApplication
    
    // mainEnvironment
    let environment: UIEventEnvironment
    
    init(application: UIApplication) {
        
        self.application = application
        
        self.environment = UIEventEnvironment(application: application)
    }
    
    func eventFetcherDidReceiveEvents(_ fetcher: UIEventFetcher) {
        
        
    }
}
