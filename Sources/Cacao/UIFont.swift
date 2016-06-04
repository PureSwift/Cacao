//
//  UIFont.swift
//  Cacao
//
//  Created by Alsey Coleman Miller on 5/29/16.
//  Copyright © 2016 PureSwift. All rights reserved.
//

import Silica

public typealias UIFont = Cacao.Font

public extension UIFont {
    
    // MARK: - Class Methods
    
    public static func labelFontSize() -> CGFloat { return 17 }
    
    // MARK: - Properties
    
    public var fontName: String { return name }
    
    public var familyName: String { return family }
    
    public var pointSize: CGFloat { return size }
}
