//
//  CacaoTests.swift
//  CacaoTests
//
//  Created by Alsey Coleman Miller on 5/11/16.
//  Copyright © 2016 PureSwift. All rights reserved.
//

import XCTest
import Foundation
import Cairo
import Silica
import Cacao

final class StyleKitTests: XCTestCase {
    
    static let allTests: [(String, (StyleKitTests) -> () throws -> Void)] = [("testSimpleShapes", testSimpleShapes), ("testAdvancedShapes", testAdvancedShapes), ("testDrawSingleLineText", testDrawSingleLineText), ("testDrawMultilineText", testDrawMultilineText)]
    
    func testSimpleShapes() {
        
        let filename = TestPath.testData + "simpleShapes.pdf"
        
        let frame = CGRect(x: 0, y: 0, width: 240, height: 120)
        
        let surface = try! Surface.PDF(filename: filename,
                                       width: Double(frame.size.width),
                                       height: Double(frame.size.height))
        
        let context = try! CGContext(surface: surface, size: frame.size)
        
        UIGraphicsPushContext(context)
        
        TestStyleKit.drawSimpleShapes()
        
        UIGraphicsPopContext()
        
        print("Wrote to \(filename)")
    }
    
    func testAdvancedShapes() {
        
        let filename = TestPath.testData + "advancedShapes.pdf"
        
        let frame = CGRect(x: 0, y: 0, width: 240, height: 120)
        
        let surface = try! Surface.PDF(filename: filename,
                                       width: Double(frame.size.width),
                                       height: Double(frame.size.height))
        
        let context = try! CGContext(surface: surface, size: frame.size)
        
        UIGraphicsPushContext(context)
        
        TestStyleKit.drawAdvancedShapes()
        
        UIGraphicsPopContext()
        
        print("Wrote to \(filename)")
    }
    
    func testDrawSingleLineText() {
        
        let filename = TestPath.testData + "singleLineText.pdf"
        
        let frame = CGRect(x: 0, y: 0, width: 240, height: 120)
        
        let surface = try! Surface.PDF(filename: filename,
                                       width: Double(frame.size.width),
                                       height: Double(frame.size.height))
        
        let context = try! CGContext(surface: surface, size: frame.size)
        
        UIGraphicsPushContext(context)
        
        TestStyleKit.drawSingleLineText()
        
        UIGraphicsPopContext()
        
        print("Wrote to \(filename)")
    }
    
    func testDrawMultilineText() {
        
        let filename = TestPath.testData + "multilineText.pdf"
        
        let frame = CGRect(x: 0, y: 0, width: 240, height: 180)
        
        let surface = try! Surface.PDF(filename: filename,
                                       width: Double(frame.size.width),
                                       height: Double(frame.size.height))
        
        let context = try! CGContext(surface: surface, size: frame.size)
        
        UIGraphicsPushContext(context)
        
        TestStyleKit.drawMultiLineText()
        
        UIGraphicsPopContext()
        
        print("Wrote to \(filename)")
    }
}
