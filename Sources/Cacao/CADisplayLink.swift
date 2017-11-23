//
//  CADisplayLink.swift
//  Cacao
//
//  Created by Alsey Coleman Miller on 11/19/17.
//

import Foundation

/// A timer object that allows your application to synchronize its drawing to the refresh rate of the display.
public final class CADisplayLink {
    
    public typealias Action = (CADisplayLink) -> ()
    
    public let action: Action
    
    /// A Boolean value that states whether the display link’s notifications to the target are suspended.
    ///
    /// The default value is false. If true, the display link does not send notifications to the target.
    /// `isPaused` is thread safe meaning that it can be set from a thread separate to the one in which
    /// the display link is running.
    public var isPaused: Bool = false
    
    public init(action: @escaping Action) {
        
        self.action = action
    }
}
