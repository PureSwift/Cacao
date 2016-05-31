//
//  NSStringDrawing.swift
//  Cacao
//
//  Created by Alsey Coleman Miller on 5/30/16.
//  Copyright © 2016 PureSwift. All rights reserved.
//

import Silica

public extension String {
    
    func drawInRect(_ rect: Rect, withAttributes attributes: [String: Any] = [:]) {
        
        guard let context = UIGraphicsGetCurrentContext()
            else { return }
        
        let font = attributes[NSFontAttributeName] as? UIFont ?? UIFont(name: "Helvetica", size: UIFont.labelFontSize())!
        
        context.fontSize = font.size
        context.setFont(font.CGFont)
        
        context.fillColor = (attributes[NSForegroundColorAttributeName] as? UIColor)?.CGColor ?? Color.black
        
        let paragraphStyle = attributes[NSParagraphStyleAttributeName] as? NSParagraphStyle ?? NSParagraphStyle()
        
        let glyphs = self.unicodeScalars.map { font.CGFont.scaledFont[UInt($0.value)] }
        
        let textWidth = context.advances(for: glyphs).reduce(Double(0), combine: { $0.0 +  $0.1.width })
        
        var textRect = Rect(x: rect.x, y: rect.y, width: textWidth, height: rect.height)
        
        if let paragraphStyle = attributes[NSParagraphStyleAttributeName] as? NSParagraphStyle {
            
            switch paragraphStyle.alignment {
                
            case .Left: break // always left by default
                
            case .Center: textRect.x = (rect.width - textRect.width) / 2
                
            case .Right: textRect.x = rect.width - textRect.width
                
            default: break
            }
        }
        
        context.textPosition = textRect.origin
        
        print(context.textPosition)
        
        context.show(toyText: self)
        
        print(context.textPosition)
    }
    
    func boundingRectWithSize(_ size: Size, options: NSStringDrawingOptions = NSStringDrawingOptions(), attributes: [String: Any] = [:], context: NSStringDrawingContext? = nil) -> Rect {
        
        return Rect()
    }
}

// MARK: - Supporting Types

public typealias NSParagraphStyle = NSMutableParagraphStyle
public typealias NSStringDrawingContext = Void

/// Encapsulates the paragraph or ruler attributes.
public final class NSMutableParagraphStyle {
    
    // MARK: - Properties
    
    /// The text alignment
    public var alignment = NSTextAlignment()
    
    // MARK: - Initialization
    
    public init() { }
    
    public static func `default`() -> NSMutableParagraphStyle {
        
        return NSMutableParagraphStyle()
    }
}

public enum NSTextAlignment {
    
    case Left
    case Center
    case Right
    case Justified
    case Natural
    
    public init() { self = .Left }
}

/// Rendering options for a string when it is drawn.
public struct NSStringDrawingOptions: OptionSet, IntegerLiteralConvertible {
    
    public static let UsesLineFragmentOrigin = NSStringDrawingOptions(rawValue: (1 << 0))
    public static let UsesFontLeading = NSStringDrawingOptions(rawValue: (1 << 1))
    public static let UsesDeviceMetrics = NSStringDrawingOptions(rawValue: (1 << 3))
    public static let TruncatesLastVisibleLine = NSStringDrawingOptions(rawValue: (1 << 5))
    
    public var rawValue: Int
    
    public init(rawValue: Int) {
        
        self.rawValue = rawValue
    }
    
    public init(integerLiteral value: Int) {
        
        self.rawValue = value
    }
    
    public init() {
        
        self = NSStringDrawingOptions.UsesLineFragmentOrigin
    }
}

#if os(Linux)
    
    /// Expects `UIFont` value.
    public let NSFontAttributeName = "NSFontAttributeName"
    
    /// Expects `UIColor` value.
    public let NSForegroundColorAttributeName = "NSForegroundColorAttributeName"
    
    /// Expects `NSMutableParagraphStyle` value.
    public let NSParagraphStyleAttributeName = "NSParagraphStyleAttributeName"
    
#endif

#if NeverCompile
    
    /// For source code compatiblity, without Foundation.
    ///
    /// - Note: You can later specify if you want `Cacao.NSString` or `Foundation.NSString` using typealiases.
    @inline(__always)
    public func NSString(string: String) -> String {
        
        return string
    }
    
#endif
