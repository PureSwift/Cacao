//
//  Label.swift
//  Cacao
//
//  Created by Alsey Coleman Miller on 5/29/16.
//  Copyright © 2016 PureSwift. All rights reserved.
//

import struct Foundation.CGFloat
import struct Foundation.CGPoint
import struct Foundation.CGSize
import struct Foundation.CGRect
import Silica

open class UILabel: UIView {
    
    // MARK: - Properties
    
    public final var text: String = "" { didSet { setNeedsDisplay() } }
    
    public final var font: UIFont = UIFont(name: "Helvetica", size: 17)! { didSet { setNeedsDisplay() } }
    
    public final var textColor: UIColor = .black { didSet { setNeedsDisplay() } }
    
    public final var textAlignment: TextAlignment = .left { didSet { setNeedsDisplay() } }
    
    // MARK: - Draw
    
    open override func draw(_ rect: CGRect?) {
        
        guard let context = UIGraphicsGetCurrentContext()
            else { return }
        
        var attributes = TextAttributes()
        attributes.font = font
        attributes.color = textColor
        attributes.paragraphStyle.alignment = textAlignment
        
        text.draw(in: self.bounds, context: context, attributes: attributes)
    }
}

// TODO: UIAppearance
extension UILabel {
    
    public static func appearance() -> UILabel {
        
        return UILabel(frame: .zero)
    }
}
