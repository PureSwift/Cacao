//
//  Label.swift
//  Cacao
//
//  Created by Alsey Coleman Miller on 5/29/16.
//  Copyright © 2016 PureSwift. All rights reserved.
//

import Foundation
import Silica

open class UILabel: UIView {
    
    // MARK: - Initialization
    
    public override init(frame: CGRect) {
        super.init(frame: frame)
        
        // disable user interaction
        self.isUserInteractionEnabled = false
    }
    
    // MARK: - Properties
    
    open var text: String? { didSet { setNeedsDisplay() } }
    
    open var font: UIFont = UIFont(name: "Helvetica", size: 17)! { didSet { setNeedsDisplay() } }
    
    open var textColor: UIColor = .black { didSet { setNeedsDisplay() } }
    
    open var textAlignment: TextAlignment = .left { didSet { setNeedsDisplay() } }
    
    // MARK: - Draw
    
    open override func draw(_ rect: CGRect) {
        
        guard let context = UIGraphicsGetCurrentContext()
            else { return }
        
        var attributes = TextAttributes()
        attributes.font = font
        attributes.color = textColor
        attributes.paragraphStyle.alignment = textAlignment
        
        text?.draw(in: self.bounds, context: context, attributes: attributes)
    }
}

// TODO: UIAppearance
extension UILabel {
    
    public static func appearance() -> UILabel {
        
        return UILabel(frame: CGRect())
    }
}
