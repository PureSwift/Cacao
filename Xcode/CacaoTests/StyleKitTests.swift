//
//  CacaoTests.swift
//  CacaoTests
//
//  Created by Alsey Coleman Miller on 5/11/16.
//  Copyright © 2016 PureSwift. All rights reserved.
//

import XCTest
import Cairo
import Silica
import Cacao

final class StyleKitTests: XCTestCase {
    
    func testSimpleShapes() {
        
        let filename = outputDirectory + "simpleShapes.pdf"
        
        let frame = Rect(x: 0, y: 0, width: 240, height: 120)
        
        let surface = Surface(pdf: filename, width: frame.width, height: frame.height)
        
        let context = try! Silica.Context(surface: surface, size: frame.size)
        
        UIGraphicsPushContext(context)
        
        TestStyleKit.drawSimpleShapes(frame: frame)
        
        UIGraphicsPopContext()
        
        print("Wrote to \(filename)")
    }
    
    func testAdvancedShapes() {
        
        let filename = outputDirectory + "advancedShapes.pdf"
        
        let frame = Rect(x: 0, y: 0, width: 240, height: 120)
        
        let surface = Surface(pdf: filename, width: frame.width, height: frame.height)
        
        let context = try! Silica.Context(surface: surface, size: frame.size)
        
        UIGraphicsPushContext(context)
        
        TestStyleKit.drawAdvancedShapes(frame: frame)
        
        UIGraphicsPopContext()
        
        print("Wrote to \(filename)")
    }
}

let outputDirectory: String = {
    
    let outputDirectory = NSTemporaryDirectory() + "CacaoTests" + "/"
    
    var isDirectory: ObjCBool = false
    
    if NSFileManager.default().fileExists(atPath: outputDirectory, isDirectory: &isDirectory) == false {
        
        try! NSFileManager.default().createDirectory(atPath: outputDirectory, withIntermediateDirectories: false)
    }
    
    return outputDirectory
}()
