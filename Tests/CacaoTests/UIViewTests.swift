//
//  UIViewTests.swift
//  CacaoTests
//
//  Created by Alsey Coleman Miller on 6/11/17.
//

import XCTest
import Foundation
import Silica
@testable import Cacao

final class UIViewTests: XCTestCase {
    
    func testHitTest() {
        
        let (backgroundView, view1, subview1, subview2) = testView1()
        
        backgroundView.addSubview(view1)
        
        XCTAssert(backgroundView.hitTest(CGPoint(x: 5, y: 5), with: nil) == backgroundView)
        XCTAssert(backgroundView.hitTest(view1.frame.origin, with: nil) == view1)
        XCTAssert(backgroundView.hitTest(CGPoint(x: 15, y: 15), with: nil) == view1)
        XCTAssert(backgroundView.hitTest(CGPoint(x: 20, y: 20), with: nil) == subview1)
        XCTAssert(backgroundView.hitTest(CGPoint(x: 25, y: 25), with: nil) == subview1)
        XCTAssert(backgroundView.hitTest(CGPoint(x: 40, y: 40), with: nil) == subview2)
        XCTAssert(backgroundView.hitTest(CGPoint(x: 45, y: 45), with: nil) == subview2)
    }
    
    func testConvertToView() {
        
        let testView = testView1()
        
        XCTAssert(testView.0.convert(CGPoint(x: 10, y: 10), to: testView.0) == CGPoint(x: 10, y: 10))
        XCTAssert(testView.0.convert(CGPoint(x: 15, y: 15), to: testView.1) == CGPoint(x: 5, y: 5))
        XCTAssert(testView.0.convert(CGPoint(x: 25, y: 25), to: testView.2) == CGPoint(x: 5, y: 5))
        XCTAssert(testView.0.convert(CGPoint(x: 40, y: 40), to: testView.3) == CGPoint())
        
        XCTAssert(testView.0.convert(testView.1.frame.origin, to: testView.1) == CGPoint())
        XCTAssert(testView.0.convert(testView.2.frame.origin, to: testView.2) == CGPoint())
        XCTAssert(testView.0.convert(testView.3.frame.origin, to: testView.3) == CGPoint())
    }
}

private extension UIViewTests {
    
    func testView1() -> (UIView, UIView, UIView, UIView)  {
        
        let view1 = UIView(frame: Rect(size: Size(width: 100, height: 100)))
        view1.tag = 1
        
        let view2 = UIView(frame: Rect(origin: Point(x: 10, y: 10), size: Size(width: 80, height: 80)))
        view2.backgroundColor = UIColor(cgColor: Color.black)
        view2.tag = 2
        
        let view3 = UIView(frame: Rect(origin: Point(x: 10, y: 10), size: Size(width: 60, height: 60)))
        view3.backgroundColor = UIColor(cgColor: Color.white)
        view3.tag = 3
        
        let view4 = UIView(frame: Rect(origin: Point(x: 20, y: 20), size: Size(width: 20, height: 20)))
        view4.backgroundColor = UIColor(cgColor: Color.blue)
        
        view1.addSubview(view2)
        view2.addSubview(view3)
        view3.addSubview(view4)
        
        return (view1, view2, view3, view4)
    }
}
