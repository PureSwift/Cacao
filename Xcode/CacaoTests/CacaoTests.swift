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
import SwiftCoreGraphics
import SwiftUIKit

final class CacaoTests: XCTestCase {
    
    func testCanvas2() {
        
        // create UIView subclass
        
        let frame = Rect(x: 0, y: 0, width: 240, height: 120)
        
        let view = TestView(frame: frame)
        
        view.drawCanvas = TestStyleKit.drawCanvas2
        
        // export image
        
        let filename = outputDirectory + "canvas2.png"
        
        view.export(PNG: filename)
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
