//
//  CADisplayLink.swift
//  Cacao
//
//  Created by Alsey Coleman Miller on 11/19/17.
//

import Foundation

public final class CADisplayLink {
    
    public typealias Action = (CADisplayLink) -> ()
    
    public let action: Action
    
    public init(action: @escaping Action) {
        
        self.action = action
    }
}
