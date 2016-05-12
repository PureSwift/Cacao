//
//  TestView.swift
//  Cacao
//
//  Created by Alsey Coleman Miller on 5/12/16.
//  Copyright © 2016 PureSwift. All rights reserved.
//

import Cairo
import Silica
import Cacao
import SwiftCoreGraphics
import SwiftUIKit

final class TestView: UIView {
    
    var drawCanvas: Rect -> () = { _ in }
    
    override func draw(_ rect: Rect) {
        
        drawCanvas(rect)
    }
    
    func export(PNG filename: String) {
        
        let surface = Surface(format: ImageFormat.ARGB32, width: Int(frame.width), height: Int(frame.height))
        
        let context = try! Silica.Context(surface: surface, size: frame.size)
        
        draw(context: context)
        
        surface.writePNG(to: filename)
        
        print("Wrote to \(filename)")
    }
}