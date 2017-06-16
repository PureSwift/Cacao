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
    
    static let allTests = [
        ("testHitTest", testHitTest),
        ("testConvertToView", testConvertToView)
    ]
    
    func testHitTest() {
        
        let (backgroundView, view1, subview1, subview2) = loadTestView1()
        
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
        
        let testView = loadTestView1()
        
        XCTAssert(testView.0.convert(CGPoint(x: 10, y: 10), to: testView.0) == CGPoint(x: 10, y: 10))
        XCTAssert(testView.0.convert(CGPoint(x: 15, y: 15), to: testView.1) == CGPoint(x: 5, y: 5))
        XCTAssert(testView.0.convert(CGPoint(x: 25, y: 25), to: testView.2) == CGPoint(x: 5, y: 5))
        XCTAssert(testView.0.convert(CGPoint(x: 40, y: 40), to: testView.3) == CGPoint())
        
        XCTAssert(testView.0.convert(testView.1.frame.origin, to: testView.1) == CGPoint())
        // this is what UIKit also gives us
        XCTAssert(testView.0.convert(testView.2.frame.origin, to: testView.2) == CGPoint(x: -10, y: -10))
        XCTAssert(testView.0.convert(testView.3.frame.origin, to: testView.3) == CGPoint(x: -20, y: -20))
    }
    
    /* Private API
    func testRootSuperviewOffset() {
        
        let testView = loadTestView1()
        
        XCTAssert(testView.0.offset(for: testView.0) == CGSize())
        XCTAssert(testView.0.offset(for: testView.1) == CGSize(width: 10, height: 10))
        XCTAssert(testView.0.offset(for: testView.2) == CGSize(width: 20, height: 20))
        XCTAssert(testView.0.offset(for: testView.3) == CGSize(width: 40, height: 40))
    }*/
}

private extension UIViewTests {
    
    func loadTestView1() -> (UIView, UIView, UIView, UIView)  {
        
        let view1 = UIView(frame: CGRect(origin: .zero, size: CGSize(width: 100, height: 100)))
        view1.tag = 1
        
        let view2 = UIView(frame: CGRect(origin: CGPoint(x: 10, y: 10), size: CGSize(width: 80, height: 80)))
        view2.backgroundColor = UIColor(cgColor: CGColor.black)
        view2.tag = 2
        
        let view3 = UIView(frame: CGRect(origin: CGPoint(x: 10, y: 10), size: CGSize(width: 60, height: 60)))
        view3.backgroundColor = UIColor(cgColor: CGColor.white)
        view3.tag = 3
        
        let view4 = UIView(frame: CGRect(origin: CGPoint(x: 20, y: 20), size: CGSize(width: 20, height: 20)))
        view4.backgroundColor = UIColor(cgColor: CGColor.blue)
        
        view1.addSubview(view2)
        view2.addSubview(view3)
        view3.addSubview(view4)
        
        return (view1, view2, view3, view4)
    }
}
