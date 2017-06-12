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
@testable import Cacao
@testable import CacaoTests

XCTMain([testCase(StyleKitTests.allTests),
         testCase(FontTests.allTests),
         testCase(RenderingTests.allTests),
         testCase(UIViewTests.allTests)
        ])
