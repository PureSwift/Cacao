//
//  CacaoConvertible.swift
//  Cacao
//
//  Created by Alsey Coleman Miller on 5/31/16.
//  Copyright © 2016 PureSwift. All rights reserved.
//

/// Can be converted from `UIKit` type to `Cacao`
public protocol CacaoConvertible {
    
    associatedtype CacaoType
    
    /// Converts the `UIKit` type to its equivalent `Cacao` type.
    func toCacao() -> CacaoType
}