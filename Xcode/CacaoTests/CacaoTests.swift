//
//  CacaoTests.swift
//  CacaoTests
//
//  Created by Alsey Coleman Miller on 5/11/16.
//  Copyright © 2016 PureSwift. All rights reserved.
//

import XCTest
import Silica
import Cacao
import SwiftCoreGraphics
import SwiftUIKit

final class CacaoTests: XCTestCase {
    
    func testExample() {
        
        final class TestView: UIView {
            
            private override func draw(_ rect: Rect) {
                
                drawCanvas1(frame: rect)
            }
            
            func drawCanvas1(frame: Rect = Rect(x: 0, y: 0, width: 240, height: 120)) {
                
                //// Color Declarations
                let color2 = UIColor(red: 1.000, green: 0.000, blue: 0.000, alpha: 1.000)
                let color3 = UIColor(red: 1.000, green: 1.000, blue: 1.000, alpha: 1.000)
                
                //// Rectangle Drawing
                let rectanglePath = UIBezierPath(rect: Rect(x: frame.minX + floor(frame.width * 0.00000 + 0.5), y: frame.minY + floor(frame.height * 0.00000 + 0.5), width: floor(frame.width * 1.00000 + 0.5) - floor(frame.width * 0.00000 + 0.5), height: floor(frame.height * 1.00000 + 0.5) - floor(frame.height * 0.00000 + 0.5)))
                color3.setFill()
                rectanglePath.fill()
                
                
                //// Oval Drawing
                let ovalPath = UIBezierPath(ovalInRect: Rect(x: frame.minX + floor(frame.width * 0.33333 + 0.5), y: frame.minY + floor(frame.height * 0.16667 + 0.5), width: floor(frame.width * 0.66667 + 0.5) - floor(frame.width * 0.33333 + 0.5), height: floor(frame.height * 0.83333 + 0.5) - floor(frame.height * 0.16667 + 0.5)))
                color2.setFill()
                ovalPath.fill()
            }

        }
        
        
    }
    
}
