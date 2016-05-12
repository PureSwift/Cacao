//
//  UIColor.swift
//  Cacao
//
//  Created by Alsey Coleman Miller on 5/12/16.
//  Copyright © 2016 PureSwift. All rights reserved.
//

import SwiftCoreGraphics
import Silica
import Cacao

public final class UIColor {
    
    // MARK: - Properties
    
    public let CGColor: SwiftCoreGraphics.CGColor
    
    // MARK: - Initialization
    
    public init(cgColor color: SwiftCoreGraphics.CGColor) {
        
        self.CGColor = color
    }
    
    /// An initialized color object. The color information represented by this object is in the device RGB colorspace.
    public init(red: SwiftCoreGraphics.CGFloat,
                green: SwiftCoreGraphics.CGFloat,
                blue: SwiftCoreGraphics.CGFloat,
                alpha: SwiftCoreGraphics.CGFloat) {
        
        self.CGColor = Color(red: red, green: green, blue: blue, alpha: alpha)
    }
    
    // MARK: - Methods
    
    // MARK: Retrieving Color Information
    
    public func getRed(_ red: inout SwiftCoreGraphics.CGFloat,
                       green: inout SwiftCoreGraphics.CGFloat,
                       blue: inout SwiftCoreGraphics.CGFloat,
                       alpha: inout SwiftCoreGraphics.CGFloat) -> Bool {
        
        red = CGColor.red
        green = CGColor.green
        blue = CGColor.blue
        alpha = CGColor.alpha
        
        return true
    }
    
    // MARK: Drawing
    
    /// Sets the color of subsequent stroke and fill operations to the color that the receiver represents.
    public func set() {
        
        setFill()
        setStroke()
    }
    
    /// Sets the color of subsequent fill operations to the color that the receiver represents.
    public func setFill() {
        
        UIGraphicsGetCurrentContext()?.fillColor = CGColor
    }
    
    /// Sets the color of subsequent stroke operations to the color that the receiver represents.
    public func setStroke() {
        
        UIGraphicsGetCurrentContext()?.strokeColor = CGColor
    }
}
