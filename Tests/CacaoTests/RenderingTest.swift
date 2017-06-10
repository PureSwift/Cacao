//
//  RenderingTest.swift
//  CacaoTests
//
//  Created by Alsey Coleman Miller on 6/9/17.
//

import XCTest
import Cairo
import Silica
import SDL
@testable import Cacao

final class RenderingTest: XCTestCase {
    
    static let allTests = [("testViewSurface", testViewSurface)]

    func testViewSurface() {
        
        let imageSize = Size(width: 240, height: 120)
        
        let window = Window(title: "\(#function)", frame: (x: .undefined, y: .undefined, width: Int(imageSize.width), height: Int(imageSize.height)))!
        
        let screen = UIScreen(window: window, size: imageSize)
        UIScreen.main = screen
        defer { UIScreen.main = nil }
        
        let view = TestView(frame: CGRect(size: imageSize))
        
        view.drawMethod = TestStyleKit.drawAdvancedShapes
        
        view.backgroundColor = UIColor.white
        
        for frame in 1 ... 10 {
            
            let filePath = TestPath.testData + "testViewSurface\(frame).png"
            
            // render
            screen.update()
            
            let scale = screen.scale
            let nativeSize = (width: Int(view.bounds.size.width * scale),
                              height: Int(view.bounds.size.height * scale))
            
            // get surface
            view.texture!.withUnsafeMutableBytes {
                
                let surface = try! Cairo.Surface.Image(mutableBytes: $0.assumingMemoryBound(to: UInt8.self), format: .argb32, width: nativeSize.width, height: nativeSize.height, stride: $1)
                
                surface.writePNG(atPath: filePath)
            }
            
            print("Wrote to \(filePath)")
        }
    }
}

private extension RenderingTest {
    
    final class TestView: UIWindow {
        
        var drawMethod: () -> () = { }
        
        override func draw(_ rect: Rect) {
            
            drawMethod()
        }
    }
}
