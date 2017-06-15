//
//  UIRectCorner.swift
//  Cacao
//
//  Created by Alsey Coleman Miller on 6/15/17.
//

///
public struct UIRectCorner: OptionSet {
    
    public let rawValue: Int
    
    public init(rawValue: Int) {
        self.rawValue = rawValue
    }
    
    public static let topLeft        = UIRectCorner(rawValue: 1 << 0)
    public static let topRight       = UIRectCorner(rawValue: 1 << 1)
    public static let bottomLeft     = UIRectCorner(rawValue: 1 << 2)
    public static let bottomRight    = UIRectCorner(rawValue: 1 << 3)
    public static let allCorners     = UIRectCorner(rawValue: ~0)
}
