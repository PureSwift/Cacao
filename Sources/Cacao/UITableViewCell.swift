//
//  UITableViewCell.swift
//  Cacao
//
//  Created by Alsey Coleman Miller on 6/26/17.
//

import Foundation

/// A cell in a table view.
///
/// This class includes properties and methods for setting and managing cell content
/// and background (including text, images, and custom views), managing the cell
/// selection and highlight state, managing accessory views, and initiating the
/// editing of the cell contents.
open class UITableViewCell: UIView {
    
    /// A string used to identify a cell that is reusable.
    public let reuseIdentifier: String?
    
    private let style: UITableViewCellStyle
    
    public var selected: Bool = false
    
    public var highlighted: Bool = false
    
    public required init(style: UITableViewCellStyle, reuseIdentifier: String?) {
        
        self.style = style
        self.reuseIdentifier = reuseIdentifier
    }
    
    /// Prepares a reusable cell for reuse by the table view's delegate.
    open func prepareForReuse() { } // override
}

// MARK: - Supporting Types

internal extension UITableViewCell {
    
    final class Separator: UIView {
        
        var style: UITableViewCellSeparatorStyle = .none  {
            didSet {
                setNeedsDisplay()
                isHidden = style == .none
            }
        }
        
        var color: UIColor? {
            didSet { setNeedsDisplay() }
        }
        
        override init(frame: CGRect) {
            super.init(frame: frame)
            
            self.isHidden = true
        }
        
        override func draw(_ rect: CGRect) {
            
            guard let context = UIGraphicsGetCurrentContext(),
                let color = self.color,
                style != .none
                else { return }
            
            color.setStroke()
            
            let line = UIBezierPath()
            line.move(to: .zero)
            line.addLine(to: CGPoint(x: bounds.size.width, y: 0))
            line.lineWidth = 1
            
            switch style {
                
            case .none:
                
                break
                
            case .singleLine:
                
                line.stroke()
                
            case .singleLineEtched:
                
                context.saveGState()
                context.setLineDash(phase: 0, lengths: [2, 2])
                line.stroke()
                context.restoreGState()
            }
        }
    }
}

public enum UITableViewCellAccessoryType: Int {
    
    case none
    case disclosureIndicator
    case detailDisclosureButton
    case checkmark
}

public enum UITableViewCellSeparatorStyle: Int {
    
    case none
    case singleLine
    case singleLineEtched
}

public enum UITableViewCellStyle: Int {
    
    case `default`
    case value1
    case value2
    case subtitle
}

public enum UITableViewCellSelectionStyle: Int {
    
    case none
    case blue
    case gray
}

public enum UITableViewCellEditingStyle: Int {
    
    case none
    case delete
    case insert
}

// MARK: - ReusableView Protocol

internal protocol ReusableView {
    
    var reuseIdentifier: String? { get }
    
    func prepareForReuse()
}

extension UITableViewCell: ReusableView { }

