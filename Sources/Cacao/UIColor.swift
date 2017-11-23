//
//  UIColor.swift
//  Cacao
//
//  Created by Alsey Coleman Miller on 5/12/16.
//  Copyright © 2016 PureSwift. All rights reserved.
//

import struct Foundation.CGFloat
import struct Foundation.CGPoint
import struct Foundation.CGSize
import struct Foundation.CGRect
import Silica

public struct UIColor {
    
    // MARK: - Properties
    
    public let cgColor: CGColor
    
    // MARK: - Initialization
    
    public init(cgColor color: CGColor) {
        
        self.cgColor = color
    }
    
    /// An initialized color object. The color information represented by this object is in the device RGB colorspace.
    public init(red: CGFloat,
                green: CGFloat,
                blue: CGFloat,
                alpha: CGFloat = 1.0) {
        
        self.cgColor = CGColor(red: red, green: green, blue: blue, alpha: alpha)
    }
    
    // MARK: - Methods
    
    // MARK: Retrieving Color Information
    
    public func getRed(_ red: inout CGFloat,
                       green: inout CGFloat,
                       blue: inout CGFloat,
                       alpha: inout CGFloat) -> Bool {
        
        red = cgColor.red
        green = cgColor.green
        blue = cgColor.blue
        alpha = cgColor.alpha
        
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
        
        UIGraphicsGetCurrentContext()?.fillColor = cgColor
        UIGraphicsGetCurrentContext()?.alpha = UIGraphicsGetCurrentContext()?.alpha ?? 1 // apply alpha again
    }
    
    /// Sets the color of subsequent stroke operations to the color that the receiver represents.
    public func setStroke() {
        
        UIGraphicsGetCurrentContext()?.strokeColor = cgColor
    }
    
    // MARK: - Singletons
    
    public static let red = UIColor(cgColor: CGColor.red)
    
    public static var green = UIColor(cgColor: CGColor.green)
    
    public static var blue = UIColor(cgColor: CGColor.blue)
    
    public static var white = UIColor(cgColor: CGColor.white)
    
    public static var black = UIColor(cgColor: CGColor.black)
    
    public static let clear = UIColor(red: 0, green: 0, blue: 0, alpha: 0)
}
