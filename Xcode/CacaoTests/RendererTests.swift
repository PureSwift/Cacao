//
//  RendererTests.swift
//  Cacao
//
//  Created by Alsey Coleman Miller on 5/15/16.
//  Copyright © 2016 PureSwift. All rights reserved.
//

import XCTest
import Cairo
import Silica
import Cacao
import SwiftCoreGraphics
import SwiftUIKit

final class RendererTests: XCTestCase {
    
    func testSubviews() {
        
        let size = Size(width: 100, height: 100)
        
        let filename = outputDirectory + "subviews.pdf"
        
        let surface = Surface(pdf: filename, width: size.width, height: size.height)
        
        let renderer = try! Renderer(surface: surface, size: size)
        
        let view1 = UIView(frame: Rect(origin: Point(x: 10, y: 10), size: Size(width: 80, height: 80)))
        
        view1.backgroundColor = UIColor(cgColor: Color.black)
        
        let subview1 = UIView(frame: Rect(origin: Point(x: 10, y: 10), size: Size(width: 60, height: 60)))
        
        subview1.backgroundColor = UIColor(cgColor: Color.white)
        
        let subview2 = UIView(frame: Rect(origin: Point(x: 20, y: 20), size: Size(width: 20, height: 20)))
        
        subview2.backgroundColor = UIColor(cgColor: Color.blue)
        
        subview1.subviews.append(subview2)
        
        view1.subviews.append(subview1)
        
        renderer.views.append(view1)
        
        try! renderer.render()
        
        print("Wrote to \(filename)")
    }
}
