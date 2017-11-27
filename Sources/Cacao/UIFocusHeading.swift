//
//  UIFocusHeading.swift
//  Cacao
//
//  Created by Alsey Coleman Miller on 11/26/17.
//

/// You obtain the direction of the focus from the `focusHeading` property.
public struct UIFocusHeading : OptionSet {
    
    public let rawValue: UInt
    
    public init(rawValue: UInt) {
        self.rawValue = rawValue
    }
    
    public static let up: UIFocusHeading = .init(rawValue: 1 << 0)
    
    public static let down: UIFocusHeading = .init(rawValue: 1 << 1)
    
    public static let left: UIFocusHeading = .init(rawValue: 1 << 2)
    
    public static let right: UIFocusHeading = .init(rawValue: 1 << 3)
    
    public static let next: UIFocusHeading = .init(rawValue: 1 << 4)
    
    public static let previous: UIFocusHeading = .init(rawValue: 1 << 5)
}
