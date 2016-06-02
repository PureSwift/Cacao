//
//  Appearance.swift
//  Cacao
//
//  Created by Alsey Coleman Miller on 6/2/16.
//  Copyright © 2016 PureSwift. All rights reserved.
//

/// Allows a view to be configured globally for a default appearance.
public protocol Appearance: View {
    
    associatedtype Appearance
    
    static var appearance: Self.Appearance { get set }
}