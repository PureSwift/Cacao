//
//  SwiftLogoView.swift
//  Cacao
//
//  Created by Alsey Coleman Miller on 5/22/16.
//  Copyright © 2016 PureSwift. All rights reserved.
//

public final class SwiftLogoView: UIView {
    
    public override func draw(_ rect: CGRect) {
        
        StyleKit.drawSwiftLogo(frame: rect)
    }
}