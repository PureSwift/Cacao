//
//  UIEventEnvironment.swift
//  Cacao
//
//  Created by Alsey Coleman Miller on 11/19/17.
//

import Foundation

internal final class UIEventEnvironment {
    
    private(set) weak var application: UIApplication!
    
    private(set) var eventQueue = [UIEvent]()
    
    init(application: UIApplication) {
        
        self.application = application
    }
}
