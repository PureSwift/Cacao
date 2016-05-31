//
//  main.swift
//  Cacao
//
//  Created by Alsey Coleman Miller on 5/21/16.
//  Copyright © 2016 PureSwift. All rights reserved.
//

import XCTest
import Foundation
import CCairo
import Cairo
import Silica
import Cacao

#if os(OSX) || os(iOS) || os(watchOS)
    func XCTMain(_ testCases: [XCTestCaseEntry]) { fatalError("Not Implemented. Linux only") }
    
    func testCase<T: XCTestCase>(_ allTests: [(String, (T) -> () throws -> Void)]) -> XCTestCaseEntry { fatalError("Not Implemented. Linux only") }
    
    struct XCTestCaseEntry { }
#endif

XCTMain([testCase(ScreenTests.allTests),
         testCase(StyleKitTests.allTests),
         testCase(FontTests.allTests)
        ])
