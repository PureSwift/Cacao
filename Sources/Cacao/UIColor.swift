//
//  UIColor.swift
//  Cacao
//
//  Created by Alsey Coleman Miller on 5/12/16.
//  Copyright © 2016 PureSwift. All rights reserved.
//

import Silica

public final class UIColor {
    
    // MARK: - Properties
    
    public let cgColor: CGColor
    
    // MARK: - Initialization
    
    public init(cgColor color: CGColor) {
        
        self.cgColor = color
    }
    
    /// An initialized color object. The color information represented by this object is in the device RGB colorspace.
    public init(red: Double,
                green: Double,
                blue: Double,
                alpha: Double = 1.0) {
        
        self.cgColor = Color(red: red, green: green, blue: blue, alpha: alpha)
    }
    
    // MARK: - Methods
    
    // MARK: Retrieving Color Information
    
    public func getRed(_ red: inout Double,
                       green: inout Double,
                       blue: inout Double,
                       alpha: inout Double) -> Bool {
        
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
        
        UIGraphicsGetCurrentContext()?.silicaContext.fillColor = cgColor
    }
    
    /// Sets the color of subsequent stroke operations to the color that the receiver represents.
    public func setStroke() {
        
        UIGraphicsGetCurrentContext()?.silicaContext.strokeColor = cgColor
    }
    
    // MARK: - Singletons
    
    public static let red = UIColor(cgColor: Color.red)
    
    public static var green = UIColor(cgColor: Color.green)
    
    public static var blue = UIColor(cgColor: Color.blue)
    
    public static var white = UIColor(cgColor: Color.white)
    
    public static var black = UIColor(cgColor: Color.black)
}

// MARK: - CacaoConvertible

extension UIColor: CacaoConvertible {
    
    public func toCacao() -> Silica.Color {
        
        return cgColor
    }
}

