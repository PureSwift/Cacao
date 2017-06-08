//
//  Label.swift
//  Cacao
//
//  Created by Alsey Coleman Miller on 5/29/16.
//  Copyright © 2016 PureSwift. All rights reserved.
//

import Silica

open class UILabel: UIView {
    
    // MARK: - Properties
    
    public final var text: String = "" { didSet { setNeedsDisplay() } }
    
    public final var font: UIFont = UIFont(name: "Helvetica", size: 17)! { didSet { setNeedsDisplay() } }
    
    public final var color: UIColor = UIColor.black { didSet { setNeedsDisplay() } }
    
    public final var textAlignment: TextAlignment = .left { didSet { setNeedsDisplay() } }
    
    // MARK: - Draw
    
    open override func draw(_ rect: CGRect?) {
        
        guard let context = UIGraphicsGetCurrentContext()
            else { return }
        
        let bounds = Rect(size: frame.size)
        
        var attributes = TextAttributes()
        attributes.font = font
        attributes.color = color
        attributes.paragraphStyle.alignment = textAlignment
        
        text.draw(in: bounds, context: context.silicaContext, attributes: attributes)
    }
}

// TODO: UIAppearance
extension UILabel {
    
    public static func appearance() -> UILabel {
        
        return UILabel(frame: CGRect())
    }
}
