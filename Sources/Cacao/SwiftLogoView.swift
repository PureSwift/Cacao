//
//  SwiftLogoView.swift
//  Cacao
//
//  Created by Alsey Coleman Miller on 5/22/16.
//  Copyright © 2016 PureSwift. All rights reserved.
//

import Silica

/// View that displays the Swift logo.
public final class SwiftLogoView: Drawable {
    
    // MARK: - Static Methods
    
    public static func contentSize(includesText: Bool) -> Size {
        
        return includesText ? Size(width: 164, height: 48) : Size(width: 48, height: 48)
    }
    
    // MARK: - Properties
    
    public var userInteractionEnabled: Bool { return false }
    
    public var frame: Rect
    
    public var hidden: Bool = false
    
    public var clipsToBounds: Bool = true
    
    /// Whether the view also draws "Swift" text next to the logo.
    ///
    /// Note: The logo alone has a `1:1` ratio and the logo with text has a `41:12` ratio.
    public var includesText: Bool
    
    /// The intrinsic content size.
    public var intrinsicContentSize: Size  {
        
        return SwiftLogoView.contentSize(includesText: includesText)
    }
    
    // MARK: - Initialization
    
    public init(frame: Rect? = nil, includesText: Bool = false) {
        
        self.includesText = includesText
        self.frame = frame ?? Rect(size: SwiftLogoView.contentSize(includesText: includesText))
    }
    
    // MARK: - Drawing
    
    public func draw(context: Silica.Context) {
        
        let bounds = Rect(size: frame.size)
        
        UIGraphicsPushContext(context)
        
        if includesText {
            
            StyleKit.drawSwiftLogoWithText(frame: bounds)
            
        } else {
            
            StyleKit.drawSwiftLogo(frame: bounds)
        }
        
        UIGraphicsPopContext()
    }
}
