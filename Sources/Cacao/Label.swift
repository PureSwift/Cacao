//
//  Label.swift
//  Cacao
//
//  Created by Alsey Coleman Miller on 5/29/16.
//  Copyright © 2016 PureSwift. All rights reserved.
//

import Silica

open class UILabel: UIView {
    
    public static func appearance() -> UILabel {
        
        
    }
    
    // MARK: - Properties
    
    public var frame: Rect { didSet { layoutSubviews() } }
    
    public var userInteractionEnabled: Bool { return false }
    
    public var clipsToBounds: Bool { return false }
    
    public var hidden: Bool = false
    
    public var text: String
    
    public var font: Font = Label.appearance.font
    
    public var color: Color = Label.appearance.color
    
    public var textAlignment: TextAlignment = .left
    
    // MARK: - Draw
    
    public override func draw() {
        
        let bounds = Rect(size: frame.size)
        
        var attributes = TextAttributes()
        attributes.font = font
        attributes.color = color
        attributes.paragraphStyle.alignment = textAlignment
        
        text.draw(in: bounds, context: context, attributes: attributes)
    }
    
    // MARK: - Size
    
    
}

extension UILabel: UIAppearance {
    
    public class func appearance() -> UILabel {
        
        struct Static {
            static let value = create()
            static func create() -> UILabel {
                
                let font = UIFont(name: "Helvetica", size: 17)!
                
                let color = UIColor.black
                
                let label = UILabel()
            }
        }
        
        return Static.value
    }
}
