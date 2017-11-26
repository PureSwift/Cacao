//
//  SwiftLogoView.swift
//  Cacao
//
//  Created by Alsey Coleman Miller on 5/22/16.
//  Copyright © 2016 PureSwift. All rights reserved.
//

#if os(Linux)
    import Glibc
#elseif os(macOS)
    import Darwin.C
#endif

import Foundation

#if os(iOS) || os(tvOS)
    import UIKit
    import CoreGraphics
#else
    import Cacao
    import Silica
#endif

/// View that displays the Swift logo.
///
/// Drawing code generated with [PaintCode](https://www.paintcodeapp.com)
public final class SwiftLogoView: UIView {
    
    // MARK: - Properties
    
    /// Whether the view also draws "Swift" text next to the logo.
    ///
    /// Note: The logo alone has a `1:1` ratio and the logo with text has a `41:12` ratio.
    public var includesText: Bool = false { didSet { setNeedsDisplay() } }
    
    /// The multiplier for drawing.
    /// This value is multiplied by the aspect ratio to get the intrinsic content size.
    ///
    /// For example, if this value is is 10, then the logo is drawn at 10x10
    /// and the logo including text is drawn at 10x36
    public var pointSize: CGFloat = 32
    
    /// The aspect ratio for the content.
    public var aspectRatio: CGFloat {
        
        return includesText ? 41 / 12 : 1
    }
    
    /// The intrinsic content size.
    public override var intrinsicContentSize: CGSize  {
        
        return CGSize(width: pointSize, height: pointSize * aspectRatio)
    }
    
    // MARK: - Initialization
    
    public override init(frame: CGRect) {
        super.init(frame: frame)
        
        // disable user interaction
        self.isUserInteractionEnabled = false
        self.backgroundColor = .clear
    }
    
    @available(iOS, unavailable)
    public required init?(coder aDecoder: NSCoder) {
        
        fatalError("init(coder:) has not been implemented")
    }
    
    // MARK: - Drawing
    
    public override func draw(_ rect: CGRect) {
        
        let frame = contentMode.rect(for: bounds, size: intrinsicContentSize)
        
        if includesText {
            
            drawSwiftLogoWithText(frame: frame)
            
        } else {
            
            drawSwiftLogo(frame: frame)
        }
    }
    
    private func drawSwiftLogoWithText(frame: CGRect = CGRect(x: 0, y: 0, width: 164, height: 48)) {
        //// General Declarations
        // This non-generic function dramatically improves compilation times of complex expressions.
        func fastFloor(_ x: CGFloat) -> CGFloat { return floor(x) }
        
        //// Color Declarations
        let fillColor = UIColor(red: 0.915, green: 0.224, blue: 0.170, alpha: 1.000)
        let fillColor2 = UIColor(red: 0.995, green: 0.995, blue: 0.995, alpha: 1.000)
        let fillColor3 = UIColor(red: 0.100, green: 0.092, blue: 0.095, alpha: 1.000)
        
        
        //// Subframes
        let group: CGRect = CGRect(x: frame.minX + fastFloor(frame.width * 0.00061 + 0.4) + 0.1, y: frame.minY + fastFloor(frame.height * 0.01250 - 0.1) + 0.6, width: fastFloor(frame.width * 0.28780 + 0.3) - fastFloor(frame.width * 0.00061 + 0.4) + 0.1, height: fastFloor(frame.height * 0.99375 - 0.2) - fastFloor(frame.height * 0.01250 - 0.1) + 0.1)
        
        
        //// Group
        //// Bezier Drawing
        let bezierPath = UIBezierPath()
        bezierPath.move(to: CGPoint(x: group.minX + 1.00000 * group.width, y: group.minY + 0.24841 * group.height))
        bezierPath.addCurve(to: CGPoint(x: group.minX + 0.99363 * group.width, y: group.minY + 0.18259 * group.height), controlPoint1: CGPoint(x: group.minX + 1.00000 * group.width, y: group.minY + 0.22718 * group.height), controlPoint2: CGPoint(x: group.minX + 0.99788 * group.width, y: group.minY + 0.20382 * group.height))
        bezierPath.addCurve(to: CGPoint(x: group.minX + 0.97240 * group.width, y: group.minY + 0.11890 * group.height), controlPoint1: CGPoint(x: group.minX + 0.98938 * group.width, y: group.minY + 0.16136 * group.height), controlPoint2: CGPoint(x: group.minX + 0.98301 * group.width, y: group.minY + 0.14013 * group.height))
        bezierPath.addCurve(to: CGPoint(x: group.minX + 0.93418 * group.width, y: group.minY + 0.06582 * group.height), controlPoint1: CGPoint(x: group.minX + 0.96178 * group.width, y: group.minY + 0.09979 * group.height), controlPoint2: CGPoint(x: group.minX + 0.94904 * group.width, y: group.minY + 0.08068 * group.height))
        bezierPath.addCurve(to: CGPoint(x: group.minX + 0.88110 * group.width, y: group.minY + 0.02760 * group.height), controlPoint1: CGPoint(x: group.minX + 0.91932 * group.width, y: group.minY + 0.05096 * group.height), controlPoint2: CGPoint(x: group.minX + 0.90021 * group.width, y: group.minY + 0.03609 * group.height))
        bezierPath.addCurve(to: CGPoint(x: group.minX + 0.81953 * group.width, y: group.minY + 0.00637 * group.height), controlPoint1: CGPoint(x: group.minX + 0.86200 * group.width, y: group.minY + 0.01699 * group.height), controlPoint2: CGPoint(x: group.minX + 0.84076 * group.width, y: group.minY + 0.01062 * group.height))
        bezierPath.addCurve(to: CGPoint(x: group.minX + 0.75372 * group.width, y: group.minY + 0.00000 * group.height), controlPoint1: CGPoint(x: group.minX + 0.79830 * group.width, y: group.minY + 0.00212 * group.height), controlPoint2: CGPoint(x: group.minX + 0.77495 * group.width, y: group.minY + 0.00212 * group.height))
        bezierPath.addLine(to: CGPoint(x: group.minX + 0.72399 * group.width, y: group.minY + 0.00000 * group.height))
        bezierPath.addLine(to: CGPoint(x: group.minX + 0.68790 * group.width, y: group.minY + 0.00000 * group.height))
        bezierPath.addLine(to: CGPoint(x: group.minX + 0.42251 * group.width, y: group.minY + 0.00000 * group.height))
        bezierPath.addLine(to: CGPoint(x: group.minX + 0.31210 * group.width, y: group.minY + 0.00000 * group.height))
        bezierPath.addLine(to: CGPoint(x: group.minX + 0.27601 * group.width, y: group.minY + 0.00000 * group.height))
        bezierPath.addLine(to: CGPoint(x: group.minX + 0.24628 * group.width, y: group.minY + 0.00000 * group.height))
        bezierPath.addLine(to: CGPoint(x: group.minX + 0.22930 * group.width, y: group.minY + 0.00000 * group.height))
        bezierPath.addCurve(to: CGPoint(x: group.minX + 0.18047 * group.width, y: group.minY + 0.00425 * group.height), controlPoint1: CGPoint(x: group.minX + 0.21231 * group.width, y: group.minY + 0.00000 * group.height), controlPoint2: CGPoint(x: group.minX + 0.19533 * group.width, y: group.minY + 0.00212 * group.height))
        bezierPath.addCurve(to: CGPoint(x: group.minX + 0.13376 * group.width, y: group.minY + 0.01699 * group.height), controlPoint1: CGPoint(x: group.minX + 0.16348 * group.width, y: group.minY + 0.00637 * group.height), controlPoint2: CGPoint(x: group.minX + 0.14862 * group.width, y: group.minY + 0.01062 * group.height))
        bezierPath.addCurve(to: CGPoint(x: group.minX + 0.11890 * group.width, y: group.minY + 0.02335 * group.height), controlPoint1: CGPoint(x: group.minX + 0.12951 * group.width, y: group.minY + 0.01911 * group.height), controlPoint2: CGPoint(x: group.minX + 0.12314 * group.width, y: group.minY + 0.02123 * group.height))
        bezierPath.addCurve(to: CGPoint(x: group.minX + 0.07856 * group.width, y: group.minY + 0.05096 * group.height), controlPoint1: CGPoint(x: group.minX + 0.10403 * group.width, y: group.minY + 0.03185 * group.height), controlPoint2: CGPoint(x: group.minX + 0.09130 * group.width, y: group.minY + 0.04034 * group.height))
        bezierPath.addCurve(to: CGPoint(x: group.minX + 0.06582 * group.width, y: group.minY + 0.06157 * group.height), controlPoint1: CGPoint(x: group.minX + 0.07431 * group.width, y: group.minY + 0.05520 * group.height), controlPoint2: CGPoint(x: group.minX + 0.07006 * group.width, y: group.minY + 0.05732 * group.height))
        bezierPath.addCurve(to: CGPoint(x: group.minX + 0.02760 * group.width, y: group.minY + 0.11465 * group.height), controlPoint1: CGPoint(x: group.minX + 0.05096 * group.width, y: group.minY + 0.07643 * group.height), controlPoint2: CGPoint(x: group.minX + 0.03609 * group.width, y: group.minY + 0.09554 * group.height))
        bezierPath.addCurve(to: CGPoint(x: group.minX + 0.00637 * group.width, y: group.minY + 0.17834 * group.height), controlPoint1: CGPoint(x: group.minX + 0.01699 * group.width, y: group.minY + 0.13376 * group.height), controlPoint2: CGPoint(x: group.minX + 0.01062 * group.width, y: group.minY + 0.15499 * group.height))
        bezierPath.addCurve(to: CGPoint(x: group.minX + 0.00000 * group.width, y: group.minY + 0.24416 * group.height), controlPoint1: CGPoint(x: group.minX + 0.00212 * group.width, y: group.minY + 0.19958 * group.height), controlPoint2: CGPoint(x: group.minX + 0.00212 * group.width, y: group.minY + 0.22293 * group.height))
        bezierPath.addLine(to: CGPoint(x: group.minX + 0.00000 * group.width, y: group.minY + 0.27389 * group.height))
        bezierPath.addLine(to: CGPoint(x: group.minX + 0.00000 * group.width, y: group.minY + 0.30998 * group.height))
        bezierPath.addLine(to: CGPoint(x: group.minX + 0.00000 * group.width, y: group.minY + 0.47346 * group.height))
        bezierPath.addLine(to: CGPoint(x: group.minX + 0.00000 * group.width, y: group.minY + 0.68577 * group.height))
        bezierPath.addLine(to: CGPoint(x: group.minX + 0.00000 * group.width, y: group.minY + 0.72187 * group.height))
        bezierPath.addLine(to: CGPoint(x: group.minX + 0.00000 * group.width, y: group.minY + 0.75159 * group.height))
        bezierPath.addCurve(to: CGPoint(x: group.minX + 0.00637 * group.width, y: group.minY + 0.81741 * group.height), controlPoint1: CGPoint(x: group.minX + 0.00000 * group.width, y: group.minY + 0.77282 * group.height), controlPoint2: CGPoint(x: group.minX + 0.00212 * group.width, y: group.minY + 0.79618 * group.height))
        bezierPath.addCurve(to: CGPoint(x: group.minX + 0.02760 * group.width, y: group.minY + 0.88110 * group.height), controlPoint1: CGPoint(x: group.minX + 0.01062 * group.width, y: group.minY + 0.83864 * group.height), controlPoint2: CGPoint(x: group.minX + 0.01699 * group.width, y: group.minY + 0.85987 * group.height))
        bezierPath.addCurve(to: CGPoint(x: group.minX + 0.06582 * group.width, y: group.minY + 0.93418 * group.height), controlPoint1: CGPoint(x: group.minX + 0.03822 * group.width, y: group.minY + 0.90021 * group.height), controlPoint2: CGPoint(x: group.minX + 0.05096 * group.width, y: group.minY + 0.91932 * group.height))
        bezierPath.addCurve(to: CGPoint(x: group.minX + 0.11890 * group.width, y: group.minY + 0.97240 * group.height), controlPoint1: CGPoint(x: group.minX + 0.08068 * group.width, y: group.minY + 0.94904 * group.height), controlPoint2: CGPoint(x: group.minX + 0.09979 * group.width, y: group.minY + 0.96391 * group.height))
        bezierPath.addCurve(to: CGPoint(x: group.minX + 0.18047 * group.width, y: group.minY + 0.99363 * group.height), controlPoint1: CGPoint(x: group.minX + 0.13800 * group.width, y: group.minY + 0.98301 * group.height), controlPoint2: CGPoint(x: group.minX + 0.15924 * group.width, y: group.minY + 0.98938 * group.height))
        bezierPath.addCurve(to: CGPoint(x: group.minX + 0.24628 * group.width, y: group.minY + 1.00000 * group.height), controlPoint1: CGPoint(x: group.minX + 0.20170 * group.width, y: group.minY + 0.99788 * group.height), controlPoint2: CGPoint(x: group.minX + 0.22505 * group.width, y: group.minY + 0.99788 * group.height))
        bezierPath.addLine(to: CGPoint(x: group.minX + 0.27601 * group.width, y: group.minY + 1.00000 * group.height))
        bezierPath.addLine(to: CGPoint(x: group.minX + 0.31210 * group.width, y: group.minY + 1.00000 * group.height))
        bezierPath.addLine(to: CGPoint(x: group.minX + 0.68790 * group.width, y: group.minY + 1.00000 * group.height))
        bezierPath.addLine(to: CGPoint(x: group.minX + 0.72399 * group.width, y: group.minY + 1.00000 * group.height))
        bezierPath.addLine(to: CGPoint(x: group.minX + 0.75372 * group.width, y: group.minY + 1.00000 * group.height))
        bezierPath.addCurve(to: CGPoint(x: group.minX + 0.81953 * group.width, y: group.minY + 0.99363 * group.height), controlPoint1: CGPoint(x: group.minX + 0.77495 * group.width, y: group.minY + 1.00000 * group.height), controlPoint2: CGPoint(x: group.minX + 0.79830 * group.width, y: group.minY + 0.99788 * group.height))
        bezierPath.addCurve(to: CGPoint(x: group.minX + 0.88110 * group.width, y: group.minY + 0.97240 * group.height), controlPoint1: CGPoint(x: group.minX + 0.84076 * group.width, y: group.minY + 0.98938 * group.height), controlPoint2: CGPoint(x: group.minX + 0.86200 * group.width, y: group.minY + 0.98301 * group.height))
        bezierPath.addCurve(to: CGPoint(x: group.minX + 0.93418 * group.width, y: group.minY + 0.93418 * group.height), controlPoint1: CGPoint(x: group.minX + 0.90021 * group.width, y: group.minY + 0.96178 * group.height), controlPoint2: CGPoint(x: group.minX + 0.91932 * group.width, y: group.minY + 0.94904 * group.height))
        bezierPath.addCurve(to: CGPoint(x: group.minX + 0.97240 * group.width, y: group.minY + 0.88110 * group.height), controlPoint1: CGPoint(x: group.minX + 0.94904 * group.width, y: group.minY + 0.91932 * group.height), controlPoint2: CGPoint(x: group.minX + 0.96391 * group.width, y: group.minY + 0.90021 * group.height))
        bezierPath.addCurve(to: CGPoint(x: group.minX + 0.99363 * group.width, y: group.minY + 0.81741 * group.height), controlPoint1: CGPoint(x: group.minX + 0.98301 * group.width, y: group.minY + 0.86200 * group.height), controlPoint2: CGPoint(x: group.minX + 0.98938 * group.width, y: group.minY + 0.84076 * group.height))
        bezierPath.addCurve(to: CGPoint(x: group.minX + 1.00000 * group.width, y: group.minY + 0.75159 * group.height), controlPoint1: CGPoint(x: group.minX + 0.99788 * group.width, y: group.minY + 0.79618 * group.height), controlPoint2: CGPoint(x: group.minX + 0.99788 * group.width, y: group.minY + 0.77282 * group.height))
        bezierPath.addLine(to: CGPoint(x: group.minX + 1.00000 * group.width, y: group.minY + 0.72187 * group.height))
        bezierPath.addLine(to: CGPoint(x: group.minX + 1.00000 * group.width, y: group.minY + 0.68577 * group.height))
        bezierPath.addLine(to: CGPoint(x: group.minX + 1.00000 * group.width, y: group.minY + 0.30998 * group.height))
        bezierPath.addLine(to: CGPoint(x: group.minX + 1.00000 * group.width, y: group.minY + 0.27813 * group.height))
        bezierPath.addLine(to: CGPoint(x: group.minX + 1.00000 * group.width, y: group.minY + 0.24841 * group.height))
        bezierPath.close()
        fillColor.setFill()
        bezierPath.fill()
        
        
        //// Bezier 2 Drawing
        let bezier2Path = UIBezierPath()
        bezier2Path.move(to: CGPoint(x: group.minX + 0.66820 * group.width, y: group.minY + 0.77312 * group.height))
        bezier2Path.addCurve(to: CGPoint(x: group.minX + 0.33333 * group.width, y: group.minY + 0.77707 * group.height), controlPoint1: CGPoint(x: group.minX + 0.57909 * group.width, y: group.minY + 0.82461 * group.height), controlPoint2: CGPoint(x: group.minX + 0.45658 * group.width, y: group.minY + 0.82989 * group.height))
        bezier2Path.addCurve(to: CGPoint(x: group.minX + 0.09766 * group.width, y: group.minY + 0.57537 * group.height), controlPoint1: CGPoint(x: group.minX + 0.23355 * group.width, y: group.minY + 0.73461 * group.height), controlPoint2: CGPoint(x: group.minX + 0.15074 * group.width, y: group.minY + 0.66030 * group.height))
        bezier2Path.addCurve(to: CGPoint(x: group.minX + 0.18471 * group.width, y: group.minY + 0.62845 * group.height), controlPoint1: CGPoint(x: group.minX + 0.12314 * group.width, y: group.minY + 0.59660 * group.height), controlPoint2: CGPoint(x: group.minX + 0.15287 * group.width, y: group.minY + 0.61359 * group.height))
        bezier2Path.addCurve(to: CGPoint(x: group.minX + 0.52879 * group.width, y: group.minY + 0.62860 * group.height), controlPoint1: CGPoint(x: group.minX + 0.31200 * group.width, y: group.minY + 0.68811 * group.height), controlPoint2: CGPoint(x: group.minX + 0.43926 * group.width, y: group.minY + 0.68403 * group.height))
        bezier2Path.addCurve(to: CGPoint(x: group.minX + 0.52866 * group.width, y: group.minY + 0.62845 * group.height), controlPoint1: CGPoint(x: group.minX + 0.52875 * group.width, y: group.minY + 0.62856 * group.height), controlPoint2: CGPoint(x: group.minX + 0.52870 * group.width, y: group.minY + 0.62849 * group.height))
        bezier2Path.addCurve(to: CGPoint(x: group.minX + 0.21231 * group.width, y: group.minY + 0.29936 * group.height), controlPoint1: CGPoint(x: group.minX + 0.40127 * group.width, y: group.minY + 0.53079 * group.height), controlPoint2: CGPoint(x: group.minX + 0.29299 * group.width, y: group.minY + 0.40340 * group.height))
        bezier2Path.addCurve(to: CGPoint(x: group.minX + 0.16985 * group.width, y: group.minY + 0.24204 * group.height), controlPoint1: CGPoint(x: group.minX + 0.19533 * group.width, y: group.minY + 0.28238 * group.height), controlPoint2: CGPoint(x: group.minX + 0.18259 * group.width, y: group.minY + 0.26115 * group.height))
        bezier2Path.addCurve(to: CGPoint(x: group.minX + 0.47771 * group.width, y: group.minY + 0.47558 * group.height), controlPoint1: CGPoint(x: group.minX + 0.26752 * group.width, y: group.minY + 0.33121 * group.height), controlPoint2: CGPoint(x: group.minX + 0.42251 * group.width, y: group.minY + 0.44374 * group.height))
        bezier2Path.addCurve(to: CGPoint(x: group.minX + 0.26115 * group.width, y: group.minY + 0.20382 * group.height), controlPoint1: CGPoint(x: group.minX + 0.36093 * group.width, y: group.minY + 0.35244 * group.height), controlPoint2: CGPoint(x: group.minX + 0.25690 * group.width, y: group.minY + 0.19958 * group.height))
        bezier2Path.addCurve(to: CGPoint(x: group.minX + 0.61783 * group.width, y: group.minY + 0.49682 * group.height), controlPoint1: CGPoint(x: group.minX + 0.44586 * group.width, y: group.minY + 0.39066 * group.height), controlPoint2: CGPoint(x: group.minX + 0.61783 * group.width, y: group.minY + 0.49682 * group.height))
        bezier2Path.addCurve(to: CGPoint(x: group.minX + 0.63146 * group.width, y: group.minY + 0.50507 * group.height), controlPoint1: CGPoint(x: group.minX + 0.62355 * group.width, y: group.minY + 0.50002 * group.height), controlPoint2: CGPoint(x: group.minX + 0.62792 * group.width, y: group.minY + 0.50270 * group.height))
        bezier2Path.addCurve(to: CGPoint(x: group.minX + 0.64119 * group.width, y: group.minY + 0.47558 * group.height), controlPoint1: CGPoint(x: group.minX + 0.63518 * group.width, y: group.minY + 0.49561 * group.height), controlPoint2: CGPoint(x: group.minX + 0.63843 * group.width, y: group.minY + 0.48577 * group.height))
        bezier2Path.addCurve(to: CGPoint(x: group.minX + 0.56263 * group.width, y: group.minY + 0.14225 * group.height), controlPoint1: CGPoint(x: group.minX + 0.67091 * group.width, y: group.minY + 0.36730 * group.height), controlPoint2: CGPoint(x: group.minX + 0.63694 * group.width, y: group.minY + 0.24416 * group.height))
        bezier2Path.addCurve(to: CGPoint(x: group.minX + 0.79406 * group.width, y: group.minY + 0.60510 * group.height), controlPoint1: CGPoint(x: group.minX + 0.73461 * group.width, y: group.minY + 0.24628 * group.height), controlPoint2: CGPoint(x: group.minX + 0.83652 * group.width, y: group.minY + 0.44161 * group.height))
        bezier2Path.addCurve(to: CGPoint(x: group.minX + 0.79045 * group.width, y: group.minY + 0.61813 * group.height), controlPoint1: CGPoint(x: group.minX + 0.79293 * group.width, y: group.minY + 0.60951 * group.height), controlPoint2: CGPoint(x: group.minX + 0.79174 * group.width, y: group.minY + 0.61386 * group.height))
        bezier2Path.addCurve(to: CGPoint(x: group.minX + 0.79193 * group.width, y: group.minY + 0.61996 * group.height), controlPoint1: CGPoint(x: group.minX + 0.79093 * group.width, y: group.minY + 0.61875 * group.height), controlPoint2: CGPoint(x: group.minX + 0.79142 * group.width, y: group.minY + 0.61934 * group.height))
        bezier2Path.addCurve(to: CGPoint(x: group.minX + 0.84289 * group.width, y: group.minY + 0.81741 * group.height), controlPoint1: CGPoint(x: group.minX + 0.87686 * group.width, y: group.minY + 0.72611 * group.height), controlPoint2: CGPoint(x: group.minX + 0.85350 * group.width, y: group.minY + 0.83864 * group.height))
        bezier2Path.addCurve(to: CGPoint(x: group.minX + 0.66820 * group.width, y: group.minY + 0.77312 * group.height), controlPoint1: CGPoint(x: group.minX + 0.79682 * group.width, y: group.minY + 0.72728 * group.height), controlPoint2: CGPoint(x: group.minX + 0.71153 * group.width, y: group.minY + 0.75484 * group.height))
        bezier2Path.close()
        fillColor2.setFill()
        bezier2Path.fill()
        
        
        
        
        //// Bezier 3 Drawing
        let bezier3Path = UIBezierPath()
        bezier3Path.move(to: CGPoint(x: frame.minX + 0.93598 * frame.width, y: frame.minY + 0.43750 * frame.height))
        bezier3Path.addLine(to: CGPoint(x: frame.minX + 0.86524 * frame.width, y: frame.minY + 0.43750 * frame.height))
        bezier3Path.addLine(to: CGPoint(x: frame.minX + 0.86524 * frame.width, y: frame.minY + 0.40625 * frame.height))
        bezier3Path.addCurve(to: CGPoint(x: frame.minX + 0.86646 * frame.width, y: frame.minY + 0.33125 * frame.height), controlPoint1: CGPoint(x: frame.minX + 0.86524 * frame.width, y: frame.minY + 0.38125 * frame.height), controlPoint2: CGPoint(x: frame.minX + 0.86585 * frame.width, y: frame.minY + 0.35625 * frame.height))
        bezier3Path.addCurve(to: CGPoint(x: frame.minX + 0.87134 * frame.width, y: frame.minY + 0.26875 * frame.height), controlPoint1: CGPoint(x: frame.minX + 0.86707 * frame.width, y: frame.minY + 0.30625 * frame.height), controlPoint2: CGPoint(x: frame.minX + 0.86890 * frame.width, y: frame.minY + 0.28542 * frame.height))
        bezier3Path.addCurve(to: CGPoint(x: frame.minX + 0.88171 * frame.width, y: frame.minY + 0.22708 * frame.height), controlPoint1: CGPoint(x: frame.minX + 0.87378 * frame.width, y: frame.minY + 0.25208 * frame.height), controlPoint2: CGPoint(x: frame.minX + 0.87744 * frame.width, y: frame.minY + 0.23750 * frame.height))
        bezier3Path.addCurve(to: CGPoint(x: frame.minX + 0.90000 * frame.width, y: frame.minY + 0.21042 * frame.height), controlPoint1: CGPoint(x: frame.minX + 0.88659 * frame.width, y: frame.minY + 0.21667 * frame.height), controlPoint2: CGPoint(x: frame.minX + 0.89268 * frame.width, y: frame.minY + 0.21042 * frame.height))
        bezier3Path.addCurve(to: CGPoint(x: frame.minX + 0.91159 * frame.width, y: frame.minY + 0.21458 * frame.height), controlPoint1: CGPoint(x: frame.minX + 0.90488 * frame.width, y: frame.minY + 0.21042 * frame.height), controlPoint2: CGPoint(x: frame.minX + 0.90854 * frame.width, y: frame.minY + 0.21250 * frame.height))
        bezier3Path.addCurve(to: CGPoint(x: frame.minX + 0.91951 * frame.width, y: frame.minY + 0.22500 * frame.height), controlPoint1: CGPoint(x: frame.minX + 0.91463 * frame.width, y: frame.minY + 0.21875 * frame.height), controlPoint2: CGPoint(x: frame.minX + 0.91707 * frame.width, y: frame.minY + 0.22083 * frame.height))
        bezier3Path.addLine(to: CGPoint(x: frame.minX + 0.92439 * frame.width, y: frame.minY + 0.18333 * frame.height))
        bezier3Path.addCurve(to: CGPoint(x: frame.minX + 0.91463 * frame.width, y: frame.minY + 0.17083 * frame.height), controlPoint1: CGPoint(x: frame.minX + 0.92195 * frame.width, y: frame.minY + 0.17917 * frame.height), controlPoint2: CGPoint(x: frame.minX + 0.91890 * frame.width, y: frame.minY + 0.17500 * frame.height))
        bezier3Path.addCurve(to: CGPoint(x: frame.minX + 0.90122 * frame.width, y: frame.minY + 0.16458 * frame.height), controlPoint1: CGPoint(x: frame.minX + 0.91098 * frame.width, y: frame.minY + 0.16667 * frame.height), controlPoint2: CGPoint(x: frame.minX + 0.90610 * frame.width, y: frame.minY + 0.16458 * frame.height))
        bezier3Path.addCurve(to: CGPoint(x: frame.minX + 0.87683 * frame.width, y: frame.minY + 0.18333 * frame.height), controlPoint1: CGPoint(x: frame.minX + 0.89146 * frame.width, y: frame.minY + 0.16458 * frame.height), controlPoint2: CGPoint(x: frame.minX + 0.88354 * frame.width, y: frame.minY + 0.17083 * frame.height))
        bezier3Path.addCurve(to: CGPoint(x: frame.minX + 0.86037 * frame.width, y: frame.minY + 0.23542 * frame.height), controlPoint1: CGPoint(x: frame.minX + 0.87012 * frame.width, y: frame.minY + 0.19583 * frame.height), controlPoint2: CGPoint(x: frame.minX + 0.86463 * frame.width, y: frame.minY + 0.21458 * frame.height))
        bezier3Path.addCurve(to: CGPoint(x: frame.minX + 0.85183 * frame.width, y: frame.minY + 0.31250 * frame.height), controlPoint1: CGPoint(x: frame.minX + 0.85671 * frame.width, y: frame.minY + 0.25625 * frame.height), controlPoint2: CGPoint(x: frame.minX + 0.85366 * frame.width, y: frame.minY + 0.28333 * frame.height))
        bezier3Path.addCurve(to: CGPoint(x: frame.minX + 0.84939 * frame.width, y: frame.minY + 0.40833 * frame.height), controlPoint1: CGPoint(x: frame.minX + 0.85000 * frame.width, y: frame.minY + 0.34167 * frame.height), controlPoint2: CGPoint(x: frame.minX + 0.84939 * frame.width, y: frame.minY + 0.37500 * frame.height))
        bezier3Path.addLine(to: CGPoint(x: frame.minX + 0.84939 * frame.width, y: frame.minY + 0.43958 * frame.height))
        bezier3Path.addLine(to: CGPoint(x: frame.minX + 0.82622 * frame.width, y: frame.minY + 0.43958 * frame.height))
        bezier3Path.addLine(to: CGPoint(x: frame.minX + 0.82622 * frame.width, y: frame.minY + 0.48125 * frame.height))
        bezier3Path.addLine(to: CGPoint(x: frame.minX + 0.84939 * frame.width, y: frame.minY + 0.48125 * frame.height))
        bezier3Path.addLine(to: CGPoint(x: frame.minX + 0.84939 * frame.width, y: frame.minY + 0.98542 * frame.height))
        bezier3Path.addLine(to: CGPoint(x: frame.minX + 0.86524 * frame.width, y: frame.minY + 0.98542 * frame.height))
        bezier3Path.addLine(to: CGPoint(x: frame.minX + 0.86524 * frame.width, y: frame.minY + 0.47917 * frame.height))
        bezier3Path.addLine(to: CGPoint(x: frame.minX + 0.93659 * frame.width, y: frame.minY + 0.47917 * frame.height))
        bezier3Path.addLine(to: CGPoint(x: frame.minX + 0.93598 * frame.width, y: frame.minY + 0.47917 * frame.height))
        bezier3Path.addLine(to: CGPoint(x: frame.minX + 0.93598 * frame.width, y: frame.minY + 0.82500 * frame.height))
        bezier3Path.addCurve(to: CGPoint(x: frame.minX + 0.93780 * frame.width, y: frame.minY + 0.89375 * frame.height), controlPoint1: CGPoint(x: frame.minX + 0.93598 * frame.width, y: frame.minY + 0.85000 * frame.height), controlPoint2: CGPoint(x: frame.minX + 0.93659 * frame.width, y: frame.minY + 0.87292 * frame.height))
        bezier3Path.addCurve(to: CGPoint(x: frame.minX + 0.94329 * frame.width, y: frame.minY + 0.94792 * frame.height), controlPoint1: CGPoint(x: frame.minX + 0.93841 * frame.width, y: frame.minY + 0.91458 * frame.height), controlPoint2: CGPoint(x: frame.minX + 0.94085 * frame.width, y: frame.minY + 0.93333 * frame.height))
        bezier3Path.addCurve(to: CGPoint(x: frame.minX + 0.95427 * frame.width, y: frame.minY + 0.98333 * frame.height), controlPoint1: CGPoint(x: frame.minX + 0.94573 * frame.width, y: frame.minY + 0.96250 * frame.height), controlPoint2: CGPoint(x: frame.minX + 0.94939 * frame.width, y: frame.minY + 0.97500 * frame.height))
        bezier3Path.addCurve(to: CGPoint(x: frame.minX + 0.97256 * frame.width, y: frame.minY + 0.99583 * frame.height), controlPoint1: CGPoint(x: frame.minX + 0.95915 * frame.width, y: frame.minY + 0.99167 * frame.height), controlPoint2: CGPoint(x: frame.minX + 0.96524 * frame.width, y: frame.minY + 0.99583 * frame.height))
        bezier3Path.addCurve(to: CGPoint(x: frame.minX + 0.99390 * frame.width, y: frame.minY + 0.98333 * frame.height), controlPoint1: CGPoint(x: frame.minX + 0.98171 * frame.width, y: frame.minY + 0.99583 * frame.height), controlPoint2: CGPoint(x: frame.minX + 0.98841 * frame.width, y: frame.minY + 0.99167 * frame.height))
        bezier3Path.addLine(to: CGPoint(x: frame.minX + 0.99207 * frame.width, y: frame.minY + 0.94167 * frame.height))
        bezier3Path.addCurve(to: CGPoint(x: frame.minX + 0.98476 * frame.width, y: frame.minY + 0.94792 * frame.height), controlPoint1: CGPoint(x: frame.minX + 0.99024 * frame.width, y: frame.minY + 0.94375 * frame.height), controlPoint2: CGPoint(x: frame.minX + 0.98780 * frame.width, y: frame.minY + 0.94583 * frame.height))
        bezier3Path.addCurve(to: CGPoint(x: frame.minX + 0.97439 * frame.width, y: frame.minY + 0.95000 * frame.height), controlPoint1: CGPoint(x: frame.minX + 0.98171 * frame.width, y: frame.minY + 0.95000 * frame.height), controlPoint2: CGPoint(x: frame.minX + 0.97866 * frame.width, y: frame.minY + 0.95000 * frame.height))
        bezier3Path.addCurve(to: CGPoint(x: frame.minX + 0.95671 * frame.width, y: frame.minY + 0.92083 * frame.height), controlPoint1: CGPoint(x: frame.minX + 0.96585 * frame.width, y: frame.minY + 0.95000 * frame.height), controlPoint2: CGPoint(x: frame.minX + 0.96037 * frame.width, y: frame.minY + 0.93958 * frame.height))
        bezier3Path.addCurve(to: CGPoint(x: frame.minX + 0.95183 * frame.width, y: frame.minY + 0.83750 * frame.height), controlPoint1: CGPoint(x: frame.minX + 0.95366 * frame.width, y: frame.minY + 0.90208 * frame.height), controlPoint2: CGPoint(x: frame.minX + 0.95183 * frame.width, y: frame.minY + 0.87292 * frame.height))
        bezier3Path.addLine(to: CGPoint(x: frame.minX + 0.95183 * frame.width, y: frame.minY + 0.48125 * frame.height))
        bezier3Path.addLine(to: CGPoint(x: frame.minX + 0.99634 * frame.width, y: frame.minY + 0.48125 * frame.height))
        bezier3Path.addLine(to: CGPoint(x: frame.minX + 0.99634 * frame.width, y: frame.minY + 0.43958 * frame.height))
        bezier3Path.addLine(to: CGPoint(x: frame.minX + 0.95183 * frame.width, y: frame.minY + 0.43958 * frame.height))
        bezier3Path.addLine(to: CGPoint(x: frame.minX + 0.95183 * frame.width, y: frame.minY + 0.31875 * frame.height))
        bezier3Path.addLine(to: CGPoint(x: frame.minX + 0.93598 * frame.width, y: frame.minY + 0.33542 * frame.height))
        bezier3Path.addLine(to: CGPoint(x: frame.minX + 0.93598 * frame.width, y: frame.minY + 0.43750 * frame.height))
        bezier3Path.close()
        bezier3Path.move(to: CGPoint(x: frame.minX + 0.93659 * frame.width, y: frame.minY + 0.43750 * frame.height))
        bezier3Path.addLine(to: CGPoint(x: frame.minX + 0.93720 * frame.width, y: frame.minY + 0.43750 * frame.height))
        bezier3Path.addLine(to: CGPoint(x: frame.minX + 0.93659 * frame.width, y: frame.minY + 0.43750 * frame.height))
        bezier3Path.close()
        bezier3Path.move(to: CGPoint(x: frame.minX + 0.93720 * frame.width, y: frame.minY + 0.47917 * frame.height))
        bezier3Path.addLine(to: CGPoint(x: frame.minX + 0.93659 * frame.width, y: frame.minY + 0.47917 * frame.height))
        bezier3Path.addLine(to: CGPoint(x: frame.minX + 0.93720 * frame.width, y: frame.minY + 0.47917 * frame.height))
        bezier3Path.close()
        bezier3Path.move(to: CGPoint(x: frame.minX + 0.38354 * frame.width, y: frame.minY + 0.90208 * frame.height))
        bezier3Path.addCurve(to: CGPoint(x: frame.minX + 0.40549 * frame.width, y: frame.minY + 0.93750 * frame.height), controlPoint1: CGPoint(x: frame.minX + 0.38963 * frame.width, y: frame.minY + 0.91667 * frame.height), controlPoint2: CGPoint(x: frame.minX + 0.39695 * frame.width, y: frame.minY + 0.92917 * frame.height))
        bezier3Path.addCurve(to: CGPoint(x: frame.minX + 0.43171 * frame.width, y: frame.minY + 0.95208 * frame.height), controlPoint1: CGPoint(x: frame.minX + 0.41341 * frame.width, y: frame.minY + 0.94583 * frame.height), controlPoint2: CGPoint(x: frame.minX + 0.42256 * frame.width, y: frame.minY + 0.95208 * frame.height))
        bezier3Path.addCurve(to: CGPoint(x: frame.minX + 0.47073 * frame.width, y: frame.minY + 0.90833 * frame.height), controlPoint1: CGPoint(x: frame.minX + 0.44817 * frame.width, y: frame.minY + 0.95208 * frame.height), controlPoint2: CGPoint(x: frame.minX + 0.46159 * frame.width, y: frame.minY + 0.93750 * frame.height))
        bezier3Path.addCurve(to: CGPoint(x: frame.minX + 0.48476 * frame.width, y: frame.minY + 0.79375 * frame.height), controlPoint1: CGPoint(x: frame.minX + 0.47988 * frame.width, y: frame.minY + 0.87917 * frame.height), controlPoint2: CGPoint(x: frame.minX + 0.48476 * frame.width, y: frame.minY + 0.83958 * frame.height))
        bezier3Path.addCurve(to: CGPoint(x: frame.minX + 0.47439 * frame.width, y: frame.minY + 0.68750 * frame.height), controlPoint1: CGPoint(x: frame.minX + 0.48476 * frame.width, y: frame.minY + 0.75000 * frame.height), controlPoint2: CGPoint(x: frame.minX + 0.48110 * frame.width, y: frame.minY + 0.71458 * frame.height))
        bezier3Path.addCurve(to: CGPoint(x: frame.minX + 0.44024 * frame.width, y: frame.minY + 0.61250 * frame.height), controlPoint1: CGPoint(x: frame.minX + 0.46768 * frame.width, y: frame.minY + 0.66042 * frame.height), controlPoint2: CGPoint(x: frame.minX + 0.45610 * frame.width, y: frame.minY + 0.63542 * frame.height))
        bezier3Path.addCurve(to: CGPoint(x: frame.minX + 0.39878 * frame.width, y: frame.minY + 0.53125 * frame.height), controlPoint1: CGPoint(x: frame.minX + 0.42317 * frame.width, y: frame.minY + 0.59167 * frame.height), controlPoint2: CGPoint(x: frame.minX + 0.40915 * frame.width, y: frame.minY + 0.56458 * frame.height))
        bezier3Path.addCurve(to: CGPoint(x: frame.minX + 0.38354 * frame.width, y: frame.minY + 0.40208 * frame.height), controlPoint1: CGPoint(x: frame.minX + 0.38841 * frame.width, y: frame.minY + 0.49792 * frame.height), controlPoint2: CGPoint(x: frame.minX + 0.38354 * frame.width, y: frame.minY + 0.45417 * frame.height))
        bezier3Path.addCurve(to: CGPoint(x: frame.minX + 0.38841 * frame.width, y: frame.minY + 0.32500 * frame.height), controlPoint1: CGPoint(x: frame.minX + 0.38354 * frame.width, y: frame.minY + 0.37500 * frame.height), controlPoint2: CGPoint(x: frame.minX + 0.38537 * frame.width, y: frame.minY + 0.34792 * frame.height))
        bezier3Path.addCurve(to: CGPoint(x: frame.minX + 0.40183 * frame.width, y: frame.minY + 0.26458 * frame.height), controlPoint1: CGPoint(x: frame.minX + 0.39146 * frame.width, y: frame.minY + 0.30208 * frame.height), controlPoint2: CGPoint(x: frame.minX + 0.39634 * frame.width, y: frame.minY + 0.28125 * frame.height))
        bezier3Path.addCurve(to: CGPoint(x: frame.minX + 0.42195 * frame.width, y: frame.minY + 0.22500 * frame.height), controlPoint1: CGPoint(x: frame.minX + 0.40732 * frame.width, y: frame.minY + 0.24792 * frame.height), controlPoint2: CGPoint(x: frame.minX + 0.41402 * frame.width, y: frame.minY + 0.23333 * frame.height))
        bezier3Path.addCurve(to: CGPoint(x: frame.minX + 0.44756 * frame.width, y: frame.minY + 0.21042 * frame.height), controlPoint1: CGPoint(x: frame.minX + 0.42988 * frame.width, y: frame.minY + 0.21458 * frame.height), controlPoint2: CGPoint(x: frame.minX + 0.43841 * frame.width, y: frame.minY + 0.21042 * frame.height))
        bezier3Path.addCurve(to: CGPoint(x: frame.minX + 0.47439 * frame.width, y: frame.minY + 0.22083 * frame.height), controlPoint1: CGPoint(x: frame.minX + 0.45793 * frame.width, y: frame.minY + 0.21042 * frame.height), controlPoint2: CGPoint(x: frame.minX + 0.46707 * frame.width, y: frame.minY + 0.21458 * frame.height))
        bezier3Path.addCurve(to: CGPoint(x: frame.minX + 0.49085 * frame.width, y: frame.minY + 0.24375 * frame.height), controlPoint1: CGPoint(x: frame.minX + 0.48171 * frame.width, y: frame.minY + 0.22917 * frame.height), controlPoint2: CGPoint(x: frame.minX + 0.48720 * frame.width, y: frame.minY + 0.23542 * frame.height))
        bezier3Path.addLine(to: CGPoint(x: frame.minX + 0.48476 * frame.width, y: frame.minY + 0.28958 * frame.height))
        bezier3Path.addCurve(to: CGPoint(x: frame.minX + 0.47012 * frame.width, y: frame.minY + 0.26667 * frame.height), controlPoint1: CGPoint(x: frame.minX + 0.48171 * frame.width, y: frame.minY + 0.28125 * frame.height), controlPoint2: CGPoint(x: frame.minX + 0.47683 * frame.width, y: frame.minY + 0.27500 * frame.height))
        bezier3Path.addCurve(to: CGPoint(x: frame.minX + 0.44634 * frame.width, y: frame.minY + 0.25417 * frame.height), controlPoint1: CGPoint(x: frame.minX + 0.46341 * frame.width, y: frame.minY + 0.25833 * frame.height), controlPoint2: CGPoint(x: frame.minX + 0.45549 * frame.width, y: frame.minY + 0.25417 * frame.height))
        bezier3Path.addCurve(to: CGPoint(x: frame.minX + 0.42378 * frame.width, y: frame.minY + 0.26667 * frame.height), controlPoint1: CGPoint(x: frame.minX + 0.43720 * frame.width, y: frame.minY + 0.25417 * frame.height), controlPoint2: CGPoint(x: frame.minX + 0.42988 * frame.width, y: frame.minY + 0.25833 * frame.height))
        bezier3Path.addCurve(to: CGPoint(x: frame.minX + 0.40915 * frame.width, y: frame.minY + 0.30000 * frame.height), controlPoint1: CGPoint(x: frame.minX + 0.41768 * frame.width, y: frame.minY + 0.27500 * frame.height), controlPoint2: CGPoint(x: frame.minX + 0.41280 * frame.width, y: frame.minY + 0.28750 * frame.height))
        bezier3Path.addCurve(to: CGPoint(x: frame.minX + 0.40122 * frame.width, y: frame.minY + 0.34583 * frame.height), controlPoint1: CGPoint(x: frame.minX + 0.40549 * frame.width, y: frame.minY + 0.31458 * frame.height), controlPoint2: CGPoint(x: frame.minX + 0.40305 * frame.width, y: frame.minY + 0.32917 * frame.height))
        bezier3Path.addCurve(to: CGPoint(x: frame.minX + 0.39878 * frame.width, y: frame.minY + 0.39375 * frame.height), controlPoint1: CGPoint(x: frame.minX + 0.39939 * frame.width, y: frame.minY + 0.36250 * frame.height), controlPoint2: CGPoint(x: frame.minX + 0.39878 * frame.width, y: frame.minY + 0.37708 * frame.height))
        bezier3Path.addCurve(to: CGPoint(x: frame.minX + 0.40976 * frame.width, y: frame.minY + 0.49583 * frame.height), controlPoint1: CGPoint(x: frame.minX + 0.39878 * frame.width, y: frame.minY + 0.43542 * frame.height), controlPoint2: CGPoint(x: frame.minX + 0.40244 * frame.width, y: frame.minY + 0.47083 * frame.height))
        bezier3Path.addCurve(to: CGPoint(x: frame.minX + 0.44451 * frame.width, y: frame.minY + 0.56667 * frame.height), controlPoint1: CGPoint(x: frame.minX + 0.41707 * frame.width, y: frame.minY + 0.52083 * frame.height), controlPoint2: CGPoint(x: frame.minX + 0.42866 * frame.width, y: frame.minY + 0.54375 * frame.height))
        bezier3Path.addCurve(to: CGPoint(x: frame.minX + 0.46829 * frame.width, y: frame.minY + 0.60833 * frame.height), controlPoint1: CGPoint(x: frame.minX + 0.45366 * frame.width, y: frame.minY + 0.57917 * frame.height), controlPoint2: CGPoint(x: frame.minX + 0.46159 * frame.width, y: frame.minY + 0.59375 * frame.height))
        bezier3Path.addCurve(to: CGPoint(x: frame.minX + 0.48598 * frame.width, y: frame.minY + 0.65625 * frame.height), controlPoint1: CGPoint(x: frame.minX + 0.47500 * frame.width, y: frame.minY + 0.62292 * frame.height), controlPoint2: CGPoint(x: frame.minX + 0.48110 * frame.width, y: frame.minY + 0.63958 * frame.height))
        bezier3Path.addCurve(to: CGPoint(x: frame.minX + 0.49634 * frame.width, y: frame.minY + 0.71458 * frame.height), controlPoint1: CGPoint(x: frame.minX + 0.49085 * frame.width, y: frame.minY + 0.67292 * frame.height), controlPoint2: CGPoint(x: frame.minX + 0.49390 * frame.width, y: frame.minY + 0.69375 * frame.height))
        bezier3Path.addCurve(to: CGPoint(x: frame.minX + 0.50000 * frame.width, y: frame.minY + 0.78958 * frame.height), controlPoint1: CGPoint(x: frame.minX + 0.49878 * frame.width, y: frame.minY + 0.73750 * frame.height), controlPoint2: CGPoint(x: frame.minX + 0.50000 * frame.width, y: frame.minY + 0.76250 * frame.height))
        bezier3Path.addCurve(to: CGPoint(x: frame.minX + 0.49573 * frame.width, y: frame.minY + 0.87083 * frame.height), controlPoint1: CGPoint(x: frame.minX + 0.50000 * frame.width, y: frame.minY + 0.81667 * frame.height), controlPoint2: CGPoint(x: frame.minX + 0.49878 * frame.width, y: frame.minY + 0.84375 * frame.height))
        bezier3Path.addCurve(to: CGPoint(x: frame.minX + 0.48232 * frame.width, y: frame.minY + 0.93750 * frame.height), controlPoint1: CGPoint(x: frame.minX + 0.49268 * frame.width, y: frame.minY + 0.89583 * frame.height), controlPoint2: CGPoint(x: frame.minX + 0.48841 * frame.width, y: frame.minY + 0.91875 * frame.height))
        bezier3Path.addCurve(to: CGPoint(x: frame.minX + 0.46037 * frame.width, y: frame.minY + 0.98333 * frame.height), controlPoint1: CGPoint(x: frame.minX + 0.47622 * frame.width, y: frame.minY + 0.95625 * frame.height), controlPoint2: CGPoint(x: frame.minX + 0.46890 * frame.width, y: frame.minY + 0.97292 * frame.height))
        bezier3Path.addCurve(to: CGPoint(x: frame.minX + 0.42988 * frame.width, y: frame.minY + 1.00000 * frame.height), controlPoint1: CGPoint(x: frame.minX + 0.45183 * frame.width, y: frame.minY + 0.99375 * frame.height), controlPoint2: CGPoint(x: frame.minX + 0.44146 * frame.width, y: frame.minY + 1.00000 * frame.height))
        bezier3Path.addCurve(to: CGPoint(x: frame.minX + 0.41524 * frame.width, y: frame.minY + 0.99583 * frame.height), controlPoint1: CGPoint(x: frame.minX + 0.42500 * frame.width, y: frame.minY + 1.00000 * frame.height), controlPoint2: CGPoint(x: frame.minX + 0.42012 * frame.width, y: frame.minY + 0.99792 * frame.height))
        bezier3Path.addCurve(to: CGPoint(x: frame.minX + 0.40061 * frame.width, y: frame.minY + 0.98542 * frame.height), controlPoint1: CGPoint(x: frame.minX + 0.41037 * frame.width, y: frame.minY + 0.99375 * frame.height), controlPoint2: CGPoint(x: frame.minX + 0.40549 * frame.width, y: frame.minY + 0.98958 * frame.height))
        bezier3Path.addCurve(to: CGPoint(x: frame.minX + 0.38720 * frame.width, y: frame.minY + 0.96875 * frame.height), controlPoint1: CGPoint(x: frame.minX + 0.39573 * frame.width, y: frame.minY + 0.98125 * frame.height), controlPoint2: CGPoint(x: frame.minX + 0.39146 * frame.width, y: frame.minY + 0.97500 * frame.height))
        bezier3Path.addCurve(to: CGPoint(x: frame.minX + 0.37683 * frame.width, y: frame.minY + 0.95000 * frame.height), controlPoint1: CGPoint(x: frame.minX + 0.38293 * frame.width, y: frame.minY + 0.96250 * frame.height), controlPoint2: CGPoint(x: frame.minX + 0.37927 * frame.width, y: frame.minY + 0.95625 * frame.height))
        bezier3Path.addLine(to: CGPoint(x: frame.minX + 0.38354 * frame.width, y: frame.minY + 0.90208 * frame.height))
        bezier3Path.close()
        bezier3Path.move(to: CGPoint(x: frame.minX + 0.52988 * frame.width, y: frame.minY + 0.43958 * frame.height))
        bezier3Path.addLine(to: CGPoint(x: frame.minX + 0.55610 * frame.width, y: frame.minY + 0.75000 * frame.height))
        bezier3Path.addCurve(to: CGPoint(x: frame.minX + 0.56341 * frame.width, y: frame.minY + 0.83958 * frame.height), controlPoint1: CGPoint(x: frame.minX + 0.55854 * frame.width, y: frame.minY + 0.78125 * frame.height), controlPoint2: CGPoint(x: frame.minX + 0.56098 * frame.width, y: frame.minY + 0.81250 * frame.height))
        bezier3Path.addCurve(to: CGPoint(x: frame.minX + 0.56951 * frame.width, y: frame.minY + 0.92083 * frame.height), controlPoint1: CGPoint(x: frame.minX + 0.56585 * frame.width, y: frame.minY + 0.86667 * frame.height), controlPoint2: CGPoint(x: frame.minX + 0.56768 * frame.width, y: frame.minY + 0.89583 * frame.height))
        bezier3Path.addLine(to: CGPoint(x: frame.minX + 0.57073 * frame.width, y: frame.minY + 0.92083 * frame.height))
        bezier3Path.addCurve(to: CGPoint(x: frame.minX + 0.57744 * frame.width, y: frame.minY + 0.83958 * frame.height), controlPoint1: CGPoint(x: frame.minX + 0.57256 * frame.width, y: frame.minY + 0.89583 * frame.height), controlPoint2: CGPoint(x: frame.minX + 0.57500 * frame.width, y: frame.minY + 0.86875 * frame.height))
        bezier3Path.addCurve(to: CGPoint(x: frame.minX + 0.58598 * frame.width, y: frame.minY + 0.75000 * frame.height), controlPoint1: CGPoint(x: frame.minX + 0.57988 * frame.width, y: frame.minY + 0.81042 * frame.height), controlPoint2: CGPoint(x: frame.minX + 0.58293 * frame.width, y: frame.minY + 0.78125 * frame.height))
        bezier3Path.addLine(to: CGPoint(x: frame.minX + 0.61707 * frame.width, y: frame.minY + 0.43958 * frame.height))
        bezier3Path.addLine(to: CGPoint(x: frame.minX + 0.63171 * frame.width, y: frame.minY + 0.43958 * frame.height))
        bezier3Path.addLine(to: CGPoint(x: frame.minX + 0.66159 * frame.width, y: frame.minY + 0.74583 * frame.height))
        bezier3Path.addCurve(to: CGPoint(x: frame.minX + 0.67012 * frame.width, y: frame.minY + 0.83958 * frame.height), controlPoint1: CGPoint(x: frame.minX + 0.66463 * frame.width, y: frame.minY + 0.77917 * frame.height), controlPoint2: CGPoint(x: frame.minX + 0.66768 * frame.width, y: frame.minY + 0.81042 * frame.height))
        bezier3Path.addCurve(to: CGPoint(x: frame.minX + 0.67683 * frame.width, y: frame.minY + 0.92083 * frame.height), controlPoint1: CGPoint(x: frame.minX + 0.67256 * frame.width, y: frame.minY + 0.86875 * frame.height), controlPoint2: CGPoint(x: frame.minX + 0.67500 * frame.width, y: frame.minY + 0.89583 * frame.height))
        bezier3Path.addLine(to: CGPoint(x: frame.minX + 0.67805 * frame.width, y: frame.minY + 0.92083 * frame.height))
        bezier3Path.addCurve(to: CGPoint(x: frame.minX + 0.68415 * frame.width, y: frame.minY + 0.83958 * frame.height), controlPoint1: CGPoint(x: frame.minX + 0.67988 * frame.width, y: frame.minY + 0.89375 * frame.height), controlPoint2: CGPoint(x: frame.minX + 0.68171 * frame.width, y: frame.minY + 0.86667 * frame.height))
        bezier3Path.addCurve(to: CGPoint(x: frame.minX + 0.69207 * frame.width, y: frame.minY + 0.74792 * frame.height), controlPoint1: CGPoint(x: frame.minX + 0.68659 * frame.width, y: frame.minY + 0.81250 * frame.height), controlPoint2: CGPoint(x: frame.minX + 0.68902 * frame.width, y: frame.minY + 0.78125 * frame.height))
        bezier3Path.addLine(to: CGPoint(x: frame.minX + 0.72012 * frame.width, y: frame.minY + 0.43958 * frame.height))
        bezier3Path.addLine(to: CGPoint(x: frame.minX + 0.73598 * frame.width, y: frame.minY + 0.43958 * frame.height))
        bezier3Path.addLine(to: CGPoint(x: frame.minX + 0.68354 * frame.width, y: frame.minY + 0.98542 * frame.height))
        bezier3Path.addLine(to: CGPoint(x: frame.minX + 0.67073 * frame.width, y: frame.minY + 0.98542 * frame.height))
        bezier3Path.addLine(to: CGPoint(x: frame.minX + 0.64085 * frame.width, y: frame.minY + 0.68125 * frame.height))
        bezier3Path.addCurve(to: CGPoint(x: frame.minX + 0.63171 * frame.width, y: frame.minY + 0.58750 * frame.height), controlPoint1: CGPoint(x: frame.minX + 0.63780 * frame.width, y: frame.minY + 0.64792 * frame.height), controlPoint2: CGPoint(x: frame.minX + 0.63476 * frame.width, y: frame.minY + 0.61667 * frame.height))
        bezier3Path.addCurve(to: CGPoint(x: frame.minX + 0.62500 * frame.width, y: frame.minY + 0.49583 * frame.height), controlPoint1: CGPoint(x: frame.minX + 0.62927 * frame.width, y: frame.minY + 0.55833 * frame.height), controlPoint2: CGPoint(x: frame.minX + 0.62683 * frame.width, y: frame.minY + 0.52708 * frame.height))
        bezier3Path.addLine(to: CGPoint(x: frame.minX + 0.62439 * frame.width, y: frame.minY + 0.49583 * frame.height))
        bezier3Path.addCurve(to: CGPoint(x: frame.minX + 0.61646 * frame.width, y: frame.minY + 0.58958 * frame.height), controlPoint1: CGPoint(x: frame.minX + 0.62195 * frame.width, y: frame.minY + 0.52917 * frame.height), controlPoint2: CGPoint(x: frame.minX + 0.61951 * frame.width, y: frame.minY + 0.56042 * frame.height))
        bezier3Path.addCurve(to: CGPoint(x: frame.minX + 0.60732 * frame.width, y: frame.minY + 0.68333 * frame.height), controlPoint1: CGPoint(x: frame.minX + 0.61341 * frame.width, y: frame.minY + 0.61875 * frame.height), controlPoint2: CGPoint(x: frame.minX + 0.61037 * frame.width, y: frame.minY + 0.65000 * frame.height))
        bezier3Path.addLine(to: CGPoint(x: frame.minX + 0.57622 * frame.width, y: frame.minY + 0.98542 * frame.height))
        bezier3Path.addLine(to: CGPoint(x: frame.minX + 0.56280 * frame.width, y: frame.minY + 0.98542 * frame.height))
        bezier3Path.addLine(to: CGPoint(x: frame.minX + 0.51402 * frame.width, y: frame.minY + 0.43958 * frame.height))
        bezier3Path.addLine(to: CGPoint(x: frame.minX + 0.52988 * frame.width, y: frame.minY + 0.43958 * frame.height))
        bezier3Path.close()
        bezier3Path.move(to: CGPoint(x: frame.minX + 0.76951 * frame.width, y: frame.minY + 0.43958 * frame.height))
        bezier3Path.addLine(to: CGPoint(x: frame.minX + 0.78537 * frame.width, y: frame.minY + 0.43958 * frame.height))
        bezier3Path.addLine(to: CGPoint(x: frame.minX + 0.78537 * frame.width, y: frame.minY + 0.98542 * frame.height))
        bezier3Path.addLine(to: CGPoint(x: frame.minX + 0.76951 * frame.width, y: frame.minY + 0.98542 * frame.height))
        bezier3Path.addLine(to: CGPoint(x: frame.minX + 0.76951 * frame.width, y: frame.minY + 0.43958 * frame.height))
        bezier3Path.close()
        bezier3Path.move(to: CGPoint(x: frame.minX + 0.76341 * frame.width, y: frame.minY + 0.27292 * frame.height))
        bezier3Path.addCurve(to: CGPoint(x: frame.minX + 0.76707 * frame.width, y: frame.minY + 0.23958 * frame.height), controlPoint1: CGPoint(x: frame.minX + 0.76341 * frame.width, y: frame.minY + 0.26042 * frame.height), controlPoint2: CGPoint(x: frame.minX + 0.76463 * frame.width, y: frame.minY + 0.25000 * frame.height))
        bezier3Path.addCurve(to: CGPoint(x: frame.minX + 0.77683 * frame.width, y: frame.minY + 0.22500 * frame.height), controlPoint1: CGPoint(x: frame.minX + 0.76951 * frame.width, y: frame.minY + 0.23125 * frame.height), controlPoint2: CGPoint(x: frame.minX + 0.77256 * frame.width, y: frame.minY + 0.22500 * frame.height))
        bezier3Path.addCurve(to: CGPoint(x: frame.minX + 0.78659 * frame.width, y: frame.minY + 0.23958 * frame.height), controlPoint1: CGPoint(x: frame.minX + 0.78049 * frame.width, y: frame.minY + 0.22500 * frame.height), controlPoint2: CGPoint(x: frame.minX + 0.78354 * frame.width, y: frame.minY + 0.22917 * frame.height))
        bezier3Path.addCurve(to: CGPoint(x: frame.minX + 0.79085 * frame.width, y: frame.minY + 0.27292 * frame.height), controlPoint1: CGPoint(x: frame.minX + 0.78902 * frame.width, y: frame.minY + 0.24792 * frame.height), controlPoint2: CGPoint(x: frame.minX + 0.79085 * frame.width, y: frame.minY + 0.26042 * frame.height))
        bezier3Path.addCurve(to: CGPoint(x: frame.minX + 0.78659 * frame.width, y: frame.minY + 0.30625 * frame.height), controlPoint1: CGPoint(x: frame.minX + 0.79085 * frame.width, y: frame.minY + 0.28542 * frame.height), controlPoint2: CGPoint(x: frame.minX + 0.78963 * frame.width, y: frame.minY + 0.29583 * frame.height))
        bezier3Path.addCurve(to: CGPoint(x: frame.minX + 0.77683 * frame.width, y: frame.minY + 0.31875 * frame.height), controlPoint1: CGPoint(x: frame.minX + 0.78415 * frame.width, y: frame.minY + 0.31458 * frame.height), controlPoint2: CGPoint(x: frame.minX + 0.78049 * frame.width, y: frame.minY + 0.31875 * frame.height))
        bezier3Path.addCurve(to: CGPoint(x: frame.minX + 0.76707 * frame.width, y: frame.minY + 0.30625 * frame.height), controlPoint1: CGPoint(x: frame.minX + 0.77317 * frame.width, y: frame.minY + 0.31875 * frame.height), controlPoint2: CGPoint(x: frame.minX + 0.77012 * frame.width, y: frame.minY + 0.31458 * frame.height))
        bezier3Path.addCurve(to: CGPoint(x: frame.minX + 0.76341 * frame.width, y: frame.minY + 0.27292 * frame.height), controlPoint1: CGPoint(x: frame.minX + 0.76463 * frame.width, y: frame.minY + 0.29583 * frame.height), controlPoint2: CGPoint(x: frame.minX + 0.76341 * frame.width, y: frame.minY + 0.28542 * frame.height))
        bezier3Path.close()
        fillColor3.setFill()
        bezier3Path.fill()
    }
    
    private func drawSwiftLogo(frame: CGRect = CGRect(x: 0, y: 0, width: 100, height: 100)) {
        //// General Declarations
        // This non-generic function dramatically improves compilation times of complex expressions.
        func fastFloor(_ x: CGFloat) -> CGFloat { return floor(x) }
        
        //// Color Declarations
        let fillColor = UIColor(red: 0.915, green: 0.224, blue: 0.170, alpha: 1.000)
        let fillColor2 = UIColor(red: 0.995, green: 0.995, blue: 0.995, alpha: 1.000)
        
        
        //// Subframes
        let group: CGRect = CGRect(x: frame.minX + fastFloor(frame.width * 0.00000 + 0.5), y: frame.minY + fastFloor(frame.height * 0.00000 + 0.5), width: fastFloor(frame.width * 1.00100 + 0.4) - fastFloor(frame.width * 0.00000 + 0.5) + 0.1, height: fastFloor(frame.height * 1.00100 + 0.4) - fastFloor(frame.height * 0.00000 + 0.5) + 0.1)
        
        
        //// Group
        //// Bezier Drawing
        let bezierPath = UIBezierPath()
        bezierPath.move(to: CGPoint(x: group.minX + 1.00000 * group.width, y: group.minY + 0.24841 * group.height))
        bezierPath.addCurve(to: CGPoint(x: group.minX + 0.99363 * group.width, y: group.minY + 0.18259 * group.height), controlPoint1: CGPoint(x: group.minX + 1.00000 * group.width, y: group.minY + 0.22718 * group.height), controlPoint2: CGPoint(x: group.minX + 0.99788 * group.width, y: group.minY + 0.20382 * group.height))
        bezierPath.addCurve(to: CGPoint(x: group.minX + 0.97240 * group.width, y: group.minY + 0.11890 * group.height), controlPoint1: CGPoint(x: group.minX + 0.98938 * group.width, y: group.minY + 0.16136 * group.height), controlPoint2: CGPoint(x: group.minX + 0.98301 * group.width, y: group.minY + 0.14013 * group.height))
        bezierPath.addCurve(to: CGPoint(x: group.minX + 0.93418 * group.width, y: group.minY + 0.06582 * group.height), controlPoint1: CGPoint(x: group.minX + 0.96178 * group.width, y: group.minY + 0.09979 * group.height), controlPoint2: CGPoint(x: group.minX + 0.94904 * group.width, y: group.minY + 0.08068 * group.height))
        bezierPath.addCurve(to: CGPoint(x: group.minX + 0.88110 * group.width, y: group.minY + 0.02760 * group.height), controlPoint1: CGPoint(x: group.minX + 0.91932 * group.width, y: group.minY + 0.05096 * group.height), controlPoint2: CGPoint(x: group.minX + 0.90021 * group.width, y: group.minY + 0.03609 * group.height))
        bezierPath.addCurve(to: CGPoint(x: group.minX + 0.81953 * group.width, y: group.minY + 0.00637 * group.height), controlPoint1: CGPoint(x: group.minX + 0.86200 * group.width, y: group.minY + 0.01699 * group.height), controlPoint2: CGPoint(x: group.minX + 0.84076 * group.width, y: group.minY + 0.01062 * group.height))
        bezierPath.addCurve(to: CGPoint(x: group.minX + 0.75372 * group.width, y: group.minY + 0.00000 * group.height), controlPoint1: CGPoint(x: group.minX + 0.79830 * group.width, y: group.minY + 0.00212 * group.height), controlPoint2: CGPoint(x: group.minX + 0.77495 * group.width, y: group.minY + 0.00212 * group.height))
        bezierPath.addLine(to: CGPoint(x: group.minX + 0.72399 * group.width, y: group.minY + 0.00000 * group.height))
        bezierPath.addLine(to: CGPoint(x: group.minX + 0.68790 * group.width, y: group.minY + 0.00000 * group.height))
        bezierPath.addLine(to: CGPoint(x: group.minX + 0.42251 * group.width, y: group.minY + 0.00000 * group.height))
        bezierPath.addLine(to: CGPoint(x: group.minX + 0.31210 * group.width, y: group.minY + 0.00000 * group.height))
        bezierPath.addLine(to: CGPoint(x: group.minX + 0.27601 * group.width, y: group.minY + 0.00000 * group.height))
        bezierPath.addLine(to: CGPoint(x: group.minX + 0.24628 * group.width, y: group.minY + 0.00000 * group.height))
        bezierPath.addLine(to: CGPoint(x: group.minX + 0.22930 * group.width, y: group.minY + 0.00000 * group.height))
        bezierPath.addCurve(to: CGPoint(x: group.minX + 0.18047 * group.width, y: group.minY + 0.00425 * group.height), controlPoint1: CGPoint(x: group.minX + 0.21231 * group.width, y: group.minY + 0.00000 * group.height), controlPoint2: CGPoint(x: group.minX + 0.19533 * group.width, y: group.minY + 0.00212 * group.height))
        bezierPath.addCurve(to: CGPoint(x: group.minX + 0.13376 * group.width, y: group.minY + 0.01699 * group.height), controlPoint1: CGPoint(x: group.minX + 0.16348 * group.width, y: group.minY + 0.00637 * group.height), controlPoint2: CGPoint(x: group.minX + 0.14862 * group.width, y: group.minY + 0.01062 * group.height))
        bezierPath.addCurve(to: CGPoint(x: group.minX + 0.11890 * group.width, y: group.minY + 0.02335 * group.height), controlPoint1: CGPoint(x: group.minX + 0.12951 * group.width, y: group.minY + 0.01911 * group.height), controlPoint2: CGPoint(x: group.minX + 0.12314 * group.width, y: group.minY + 0.02123 * group.height))
        bezierPath.addCurve(to: CGPoint(x: group.minX + 0.07856 * group.width, y: group.minY + 0.05096 * group.height), controlPoint1: CGPoint(x: group.minX + 0.10403 * group.width, y: group.minY + 0.03185 * group.height), controlPoint2: CGPoint(x: group.minX + 0.09130 * group.width, y: group.minY + 0.04034 * group.height))
        bezierPath.addCurve(to: CGPoint(x: group.minX + 0.06582 * group.width, y: group.minY + 0.06157 * group.height), controlPoint1: CGPoint(x: group.minX + 0.07431 * group.width, y: group.minY + 0.05520 * group.height), controlPoint2: CGPoint(x: group.minX + 0.07006 * group.width, y: group.minY + 0.05732 * group.height))
        bezierPath.addCurve(to: CGPoint(x: group.minX + 0.02760 * group.width, y: group.minY + 0.11465 * group.height), controlPoint1: CGPoint(x: group.minX + 0.05096 * group.width, y: group.minY + 0.07643 * group.height), controlPoint2: CGPoint(x: group.minX + 0.03609 * group.width, y: group.minY + 0.09554 * group.height))
        bezierPath.addCurve(to: CGPoint(x: group.minX + 0.00637 * group.width, y: group.minY + 0.17834 * group.height), controlPoint1: CGPoint(x: group.minX + 0.01699 * group.width, y: group.minY + 0.13376 * group.height), controlPoint2: CGPoint(x: group.minX + 0.01062 * group.width, y: group.minY + 0.15499 * group.height))
        bezierPath.addCurve(to: CGPoint(x: group.minX + 0.00000 * group.width, y: group.minY + 0.24416 * group.height), controlPoint1: CGPoint(x: group.minX + 0.00212 * group.width, y: group.minY + 0.19958 * group.height), controlPoint2: CGPoint(x: group.minX + 0.00212 * group.width, y: group.minY + 0.22293 * group.height))
        bezierPath.addLine(to: CGPoint(x: group.minX + 0.00000 * group.width, y: group.minY + 0.27389 * group.height))
        bezierPath.addLine(to: CGPoint(x: group.minX + 0.00000 * group.width, y: group.minY + 0.30998 * group.height))
        bezierPath.addLine(to: CGPoint(x: group.minX + 0.00000 * group.width, y: group.minY + 0.47346 * group.height))
        bezierPath.addLine(to: CGPoint(x: group.minX + 0.00000 * group.width, y: group.minY + 0.68577 * group.height))
        bezierPath.addLine(to: CGPoint(x: group.minX + 0.00000 * group.width, y: group.minY + 0.72187 * group.height))
        bezierPath.addLine(to: CGPoint(x: group.minX + 0.00000 * group.width, y: group.minY + 0.75159 * group.height))
        bezierPath.addCurve(to: CGPoint(x: group.minX + 0.00637 * group.width, y: group.minY + 0.81741 * group.height), controlPoint1: CGPoint(x: group.minX + 0.00000 * group.width, y: group.minY + 0.77282 * group.height), controlPoint2: CGPoint(x: group.minX + 0.00212 * group.width, y: group.minY + 0.79618 * group.height))
        bezierPath.addCurve(to: CGPoint(x: group.minX + 0.02760 * group.width, y: group.minY + 0.88110 * group.height), controlPoint1: CGPoint(x: group.minX + 0.01062 * group.width, y: group.minY + 0.83864 * group.height), controlPoint2: CGPoint(x: group.minX + 0.01699 * group.width, y: group.minY + 0.85987 * group.height))
        bezierPath.addCurve(to: CGPoint(x: group.minX + 0.06582 * group.width, y: group.minY + 0.93418 * group.height), controlPoint1: CGPoint(x: group.minX + 0.03822 * group.width, y: group.minY + 0.90021 * group.height), controlPoint2: CGPoint(x: group.minX + 0.05096 * group.width, y: group.minY + 0.91932 * group.height))
        bezierPath.addCurve(to: CGPoint(x: group.minX + 0.11890 * group.width, y: group.minY + 0.97240 * group.height), controlPoint1: CGPoint(x: group.minX + 0.08068 * group.width, y: group.minY + 0.94904 * group.height), controlPoint2: CGPoint(x: group.minX + 0.09979 * group.width, y: group.minY + 0.96391 * group.height))
        bezierPath.addCurve(to: CGPoint(x: group.minX + 0.18047 * group.width, y: group.minY + 0.99363 * group.height), controlPoint1: CGPoint(x: group.minX + 0.13800 * group.width, y: group.minY + 0.98301 * group.height), controlPoint2: CGPoint(x: group.minX + 0.15924 * group.width, y: group.minY + 0.98938 * group.height))
        bezierPath.addCurve(to: CGPoint(x: group.minX + 0.24628 * group.width, y: group.minY + 1.00000 * group.height), controlPoint1: CGPoint(x: group.minX + 0.20170 * group.width, y: group.minY + 0.99788 * group.height), controlPoint2: CGPoint(x: group.minX + 0.22505 * group.width, y: group.minY + 0.99788 * group.height))
        bezierPath.addLine(to: CGPoint(x: group.minX + 0.27601 * group.width, y: group.minY + 1.00000 * group.height))
        bezierPath.addLine(to: CGPoint(x: group.minX + 0.31210 * group.width, y: group.minY + 1.00000 * group.height))
        bezierPath.addLine(to: CGPoint(x: group.minX + 0.68790 * group.width, y: group.minY + 1.00000 * group.height))
        bezierPath.addLine(to: CGPoint(x: group.minX + 0.72399 * group.width, y: group.minY + 1.00000 * group.height))
        bezierPath.addLine(to: CGPoint(x: group.minX + 0.75372 * group.width, y: group.minY + 1.00000 * group.height))
        bezierPath.addCurve(to: CGPoint(x: group.minX + 0.81953 * group.width, y: group.minY + 0.99363 * group.height), controlPoint1: CGPoint(x: group.minX + 0.77495 * group.width, y: group.minY + 1.00000 * group.height), controlPoint2: CGPoint(x: group.minX + 0.79830 * group.width, y: group.minY + 0.99788 * group.height))
        bezierPath.addCurve(to: CGPoint(x: group.minX + 0.88110 * group.width, y: group.minY + 0.97240 * group.height), controlPoint1: CGPoint(x: group.minX + 0.84076 * group.width, y: group.minY + 0.98938 * group.height), controlPoint2: CGPoint(x: group.minX + 0.86200 * group.width, y: group.minY + 0.98301 * group.height))
        bezierPath.addCurve(to: CGPoint(x: group.minX + 0.93418 * group.width, y: group.minY + 0.93418 * group.height), controlPoint1: CGPoint(x: group.minX + 0.90021 * group.width, y: group.minY + 0.96178 * group.height), controlPoint2: CGPoint(x: group.minX + 0.91932 * group.width, y: group.minY + 0.94904 * group.height))
        bezierPath.addCurve(to: CGPoint(x: group.minX + 0.97240 * group.width, y: group.minY + 0.88110 * group.height), controlPoint1: CGPoint(x: group.minX + 0.94904 * group.width, y: group.minY + 0.91932 * group.height), controlPoint2: CGPoint(x: group.minX + 0.96391 * group.width, y: group.minY + 0.90021 * group.height))
        bezierPath.addCurve(to: CGPoint(x: group.minX + 0.99363 * group.width, y: group.minY + 0.81741 * group.height), controlPoint1: CGPoint(x: group.minX + 0.98301 * group.width, y: group.minY + 0.86200 * group.height), controlPoint2: CGPoint(x: group.minX + 0.98938 * group.width, y: group.minY + 0.84076 * group.height))
        bezierPath.addCurve(to: CGPoint(x: group.minX + 1.00000 * group.width, y: group.minY + 0.75159 * group.height), controlPoint1: CGPoint(x: group.minX + 0.99788 * group.width, y: group.minY + 0.79618 * group.height), controlPoint2: CGPoint(x: group.minX + 0.99788 * group.width, y: group.minY + 0.77282 * group.height))
        bezierPath.addLine(to: CGPoint(x: group.minX + 1.00000 * group.width, y: group.minY + 0.72187 * group.height))
        bezierPath.addLine(to: CGPoint(x: group.minX + 1.00000 * group.width, y: group.minY + 0.68577 * group.height))
        bezierPath.addLine(to: CGPoint(x: group.minX + 1.00000 * group.width, y: group.minY + 0.30998 * group.height))
        bezierPath.addLine(to: CGPoint(x: group.minX + 1.00000 * group.width, y: group.minY + 0.27813 * group.height))
        bezierPath.addLine(to: CGPoint(x: group.minX + 1.00000 * group.width, y: group.minY + 0.24841 * group.height))
        bezierPath.close()
        fillColor.setFill()
        bezierPath.fill()
        
        
        //// Bezier 2 Drawing
        let bezier2Path = UIBezierPath()
        bezier2Path.move(to: CGPoint(x: group.minX + 0.66820 * group.width, y: group.minY + 0.77312 * group.height))
        bezier2Path.addCurve(to: CGPoint(x: group.minX + 0.33333 * group.width, y: group.minY + 0.77707 * group.height), controlPoint1: CGPoint(x: group.minX + 0.57909 * group.width, y: group.minY + 0.82461 * group.height), controlPoint2: CGPoint(x: group.minX + 0.45658 * group.width, y: group.minY + 0.82989 * group.height))
        bezier2Path.addCurve(to: CGPoint(x: group.minX + 0.09766 * group.width, y: group.minY + 0.57537 * group.height), controlPoint1: CGPoint(x: group.minX + 0.23355 * group.width, y: group.minY + 0.73461 * group.height), controlPoint2: CGPoint(x: group.minX + 0.15074 * group.width, y: group.minY + 0.66030 * group.height))
        bezier2Path.addCurve(to: CGPoint(x: group.minX + 0.18471 * group.width, y: group.minY + 0.62845 * group.height), controlPoint1: CGPoint(x: group.minX + 0.12314 * group.width, y: group.minY + 0.59660 * group.height), controlPoint2: CGPoint(x: group.minX + 0.15287 * group.width, y: group.minY + 0.61359 * group.height))
        bezier2Path.addCurve(to: CGPoint(x: group.minX + 0.52879 * group.width, y: group.minY + 0.62860 * group.height), controlPoint1: CGPoint(x: group.minX + 0.31200 * group.width, y: group.minY + 0.68811 * group.height), controlPoint2: CGPoint(x: group.minX + 0.43926 * group.width, y: group.minY + 0.68403 * group.height))
        bezier2Path.addCurve(to: CGPoint(x: group.minX + 0.52866 * group.width, y: group.minY + 0.62845 * group.height), controlPoint1: CGPoint(x: group.minX + 0.52875 * group.width, y: group.minY + 0.62856 * group.height), controlPoint2: CGPoint(x: group.minX + 0.52870 * group.width, y: group.minY + 0.62849 * group.height))
        bezier2Path.addCurve(to: CGPoint(x: group.minX + 0.21231 * group.width, y: group.minY + 0.29936 * group.height), controlPoint1: CGPoint(x: group.minX + 0.40127 * group.width, y: group.minY + 0.53079 * group.height), controlPoint2: CGPoint(x: group.minX + 0.29299 * group.width, y: group.minY + 0.40340 * group.height))
        bezier2Path.addCurve(to: CGPoint(x: group.minX + 0.16985 * group.width, y: group.minY + 0.24204 * group.height), controlPoint1: CGPoint(x: group.minX + 0.19533 * group.width, y: group.minY + 0.28238 * group.height), controlPoint2: CGPoint(x: group.minX + 0.18259 * group.width, y: group.minY + 0.26115 * group.height))
        bezier2Path.addCurve(to: CGPoint(x: group.minX + 0.47771 * group.width, y: group.minY + 0.47558 * group.height), controlPoint1: CGPoint(x: group.minX + 0.26752 * group.width, y: group.minY + 0.33121 * group.height), controlPoint2: CGPoint(x: group.minX + 0.42251 * group.width, y: group.minY + 0.44374 * group.height))
        bezier2Path.addCurve(to: CGPoint(x: group.minX + 0.26115 * group.width, y: group.minY + 0.20382 * group.height), controlPoint1: CGPoint(x: group.minX + 0.36093 * group.width, y: group.minY + 0.35244 * group.height), controlPoint2: CGPoint(x: group.minX + 0.25690 * group.width, y: group.minY + 0.19958 * group.height))
        bezier2Path.addCurve(to: CGPoint(x: group.minX + 0.61783 * group.width, y: group.minY + 0.49682 * group.height), controlPoint1: CGPoint(x: group.minX + 0.44586 * group.width, y: group.minY + 0.39066 * group.height), controlPoint2: CGPoint(x: group.minX + 0.61783 * group.width, y: group.minY + 0.49682 * group.height))
        bezier2Path.addCurve(to: CGPoint(x: group.minX + 0.63146 * group.width, y: group.minY + 0.50507 * group.height), controlPoint1: CGPoint(x: group.minX + 0.62355 * group.width, y: group.minY + 0.50002 * group.height), controlPoint2: CGPoint(x: group.minX + 0.62792 * group.width, y: group.minY + 0.50270 * group.height))
        bezier2Path.addCurve(to: CGPoint(x: group.minX + 0.64119 * group.width, y: group.minY + 0.47558 * group.height), controlPoint1: CGPoint(x: group.minX + 0.63518 * group.width, y: group.minY + 0.49561 * group.height), controlPoint2: CGPoint(x: group.minX + 0.63843 * group.width, y: group.minY + 0.48577 * group.height))
        bezier2Path.addCurve(to: CGPoint(x: group.minX + 0.56263 * group.width, y: group.minY + 0.14225 * group.height), controlPoint1: CGPoint(x: group.minX + 0.67091 * group.width, y: group.minY + 0.36730 * group.height), controlPoint2: CGPoint(x: group.minX + 0.63694 * group.width, y: group.minY + 0.24416 * group.height))
        bezier2Path.addCurve(to: CGPoint(x: group.minX + 0.79406 * group.width, y: group.minY + 0.60510 * group.height), controlPoint1: CGPoint(x: group.minX + 0.73461 * group.width, y: group.minY + 0.24628 * group.height), controlPoint2: CGPoint(x: group.minX + 0.83652 * group.width, y: group.minY + 0.44161 * group.height))
        bezier2Path.addCurve(to: CGPoint(x: group.minX + 0.79045 * group.width, y: group.minY + 0.61813 * group.height), controlPoint1: CGPoint(x: group.minX + 0.79293 * group.width, y: group.minY + 0.60951 * group.height), controlPoint2: CGPoint(x: group.minX + 0.79174 * group.width, y: group.minY + 0.61386 * group.height))
        bezier2Path.addCurve(to: CGPoint(x: group.minX + 0.79193 * group.width, y: group.minY + 0.61996 * group.height), controlPoint1: CGPoint(x: group.minX + 0.79093 * group.width, y: group.minY + 0.61875 * group.height), controlPoint2: CGPoint(x: group.minX + 0.79142 * group.width, y: group.minY + 0.61934 * group.height))
        bezier2Path.addCurve(to: CGPoint(x: group.minX + 0.84289 * group.width, y: group.minY + 0.81741 * group.height), controlPoint1: CGPoint(x: group.minX + 0.87686 * group.width, y: group.minY + 0.72611 * group.height), controlPoint2: CGPoint(x: group.minX + 0.85350 * group.width, y: group.minY + 0.83864 * group.height))
        bezier2Path.addCurve(to: CGPoint(x: group.minX + 0.66820 * group.width, y: group.minY + 0.77312 * group.height), controlPoint1: CGPoint(x: group.minX + 0.79682 * group.width, y: group.minY + 0.72728 * group.height), controlPoint2: CGPoint(x: group.minX + 0.71153 * group.width, y: group.minY + 0.75484 * group.height))
        bezier2Path.close()
        fillColor2.setFill()
        bezier2Path.fill()
    }
}

internal extension UIViewContentMode {
    
    func rect(for bounds: CGRect, size: CGSize) -> CGRect {
        
        switch self {
            
        case .redraw: fallthrough
            
        case .scaleToFill:
            
            return CGRect(origin: .zero, size: bounds.size)
            
        case .scaleAspectFit:
            
            let widthRatio = bounds.width / size.width
            let heightRatio = bounds.height / size.height
            
            var newSize = bounds.size
            
            if (widthRatio < heightRatio) {
                
                newSize.height = bounds.size.width / size.width * size.height
                
            } else if (heightRatio < widthRatio) {
                
                newSize.width = bounds.size.height / size.height * size.width
            }
            
            newSize = CGSize(width: ceil(newSize.width), height: ceil(newSize.height))
            
            var origin = bounds.origin
            origin.x += (bounds.size.width - newSize.width) / 2.0
            origin.y += (bounds.size.height - newSize.height) / 2.0
            
            return CGRect(origin: origin, size: newSize)
            
        case .scaleAspectFill:
            
            let widthRatio = (bounds.size.width / size.width)
            let heightRatio = (bounds.size.height / size.height)
            
            var newSize = bounds.size
            
            if (widthRatio > heightRatio) {
                
                newSize.height = bounds.size.width / size.width * size.height
                
            } else if (heightRatio > widthRatio) {
                
                newSize.width = bounds.size.height / size.height * size.width
            }
            
            newSize = CGSize(width: ceil(newSize.width), height: ceil(newSize.height))
            
            var origin = CGPoint()
            origin.x = (bounds.size.width - newSize.width) / 2.0
            origin.y = (bounds.size.height - newSize.height) / 2.0
            
            return CGRect(origin: origin, size: newSize)
            
        case .center:
            
            var rect = CGRect(origin: .zero, size: size)
            
            rect.origin.x = (bounds.size.width - rect.size.width) / 2.0
            rect.origin.y = (bounds.size.height - rect.size.height) / 2.0
            
            return rect
            
        case .top:
            
            var rect = CGRect(origin: .zero, size: size)
            
            rect.origin.y = 0.0
            rect.origin.x = (bounds.size.width - rect.size.width) / 2.0
            
            return rect
            
        case .bottom:
            
            var rect = CGRect(origin: .zero, size: size)
            
            rect.origin.x = (bounds.size.width - rect.size.width) / 2.0
            rect.origin.y = bounds.size.height - rect.size.height
            
            return rect
            
        case .left:
            
            var rect = CGRect(origin: .zero, size: size)
            
            rect.origin.x = 0.0
            rect.origin.y = (bounds.size.height - rect.size.height) / 2.0
            
            return rect
            
        case .right:
            
            var rect = CGRect(origin: .zero, size: size)
            
            rect.origin.x = bounds.size.width - rect.size.width
            rect.origin.y = (bounds.size.height - rect.size.height) / 2.0
            
            return rect
            
        case .topLeft:
            
            return CGRect(origin: .zero, size: size)
            
        case .topRight:
            
            var rect = CGRect(origin: .zero, size: size)
            
            rect.origin.x = bounds.size.width - rect.size.width
            rect.origin.y = 0.0
            
            return rect
            
        case .bottomLeft:
            
            var rect = CGRect(origin: .zero, size: size)
            
            rect.origin.x = 0.0
            rect.origin.y = bounds.size.height - rect.size.height
            
            return rect
            
        case .bottomRight:
            
            var rect = CGRect(origin: .zero, size: size)
            
            rect.origin.x = bounds.size.width - rect.size.width
            rect.origin.y = bounds.size.height - rect.size.height
            
            return rect
        }
    }
}

