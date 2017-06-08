//
//  SwiftLogoView.swift
//  Cacao
//
//  Created by Alsey Coleman Miller on 5/22/16.
//  Copyright © 2016 PureSwift. All rights reserved.
//

import Silica
import Cacao

/// View that displays the Swift logo.
public final class SwiftLogoView: UIView {
    
    // MARK: - Static Methods
    
    public static func contentSize(includesText: Bool) -> Size {
        
        return includesText ? Size(width: 164, height: 48) : Size(width: 48, height: 48)
    }
    
    // MARK: - Properties
    
    /// Whether the view also draws "Swift" text next to the logo.
    ///
    /// Note: The logo alone has a `1:1` ratio and the logo with text has a `41:12` ratio.
    public var includesText: Bool
    
    /// The intrinsic content size.
    public override var intrinsicContentSize: Size  {
        
        return SwiftLogoView.contentSize(includesText: includesText)
    }
    
    // MARK: - Initialization
    
    public init(frame: Rect? = nil, includesText: Bool = false) {
        
        self.includesText = includesText
        
        let frame = frame ?? Rect(size: SwiftLogoView.contentSize(includesText: includesText))
        
        super.init(frame: frame)
    }
    
    // MARK: - Drawing
    
    public override func draw(_ rect: CGRect) {
        
        let frame = contentMode.rect(for: bounds, size: intrinsicContentSize)
        
        if includesText {
            
            StyleKit.drawSwiftLogoWithText(frame: frame)
            
        } else {
            
            StyleKit.drawSwiftLogo(frame: frame)
        }
    }
}
