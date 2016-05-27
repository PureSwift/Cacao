//
//  SwiftLogoView.swift
//  Cacao
//
//  Created by Alsey Coleman Miller on 5/22/16.
//  Copyright © 2016 PureSwift. All rights reserved.
//

import Silica

/// View that displays the Swift logo.
public final class SwiftLogoView: UIView {
    
    // MARK: - Properties
    
    /// Whether the view also draws "Swift" text next to the logo.
    ///
    /// Note: The logo alone has a `1:1` ratio and the logo with text has a `41:12` ratio.
    public var includesText: Bool = false
    
    /// The intrensic content size.
    public override var intrinsicContentSize: Size  {
        
        return includesText ? Size(width: 164, height: 48) : Size(width: 48, height: 48)
    }
    
    // MARK: - Drawing
    
    public override func draw(_ rect: CGRect) {
        
        // calculate rect
        let contentRect = UIView.rect(for: contentMode, size: (intrinsicContentSize, rect.size))
        
        if includesText {
            
            StyleKit.drawSwiftLogoWithText(frame: contentRect)
            
        } else {
            
            StyleKit.drawSwiftLogo(frame: contentRect)
        }
    }
}
