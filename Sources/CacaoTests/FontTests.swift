//
//  FontTests.swift
//  Cacao
//
//  Created by Alsey Coleman Miller on 5/31/16.
//  Copyright © 2016 PureSwift. All rights reserved.
//

import XCTest
import Cacao

final class FontTests: XCTestCase {
    
    static let allTests: [(String, (FontTests) -> () throws -> Void)] = [("testCreateSimpleFont", testCreateSimpleFont), ("testCreateTraitFont", testCreateTraitFont)]
    
    func testCreateSimpleFont() {
        
        guard let font = Font(name: "TimesNewRoman", size: 17)
            else { XCTFail("Could not create font"); return }
        
        let expectedFullName = "Times New Roman"
        
        XCTAssert(font.name == font.silicaFont.name)
        XCTAssert(expectedFullName == font.silicaFont.scaledFont.fullName, "\(expectedFullName) == \(font.silicaFont.scaledFont.fullName)")
    }
    
    func testCreateTraitFont() {
        
        guard let font = Font(name: "TimesNewRoman-Bold", size: 17)
            else { XCTFail("Could not create font"); return }
        
        let expectedFullName = "Times New Roman"
        
        XCTAssert(font.name == font.silicaFont.name)
        XCTAssert(expectedFullName == font.silicaFont.scaledFont.fullName, "\(expectedFullName) == \(font.silicaFont.scaledFont.fullName)")
    }
}
