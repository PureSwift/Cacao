//
//  Utilities.swift
//  CacaoTests
//
//  Created by Alsey Coleman Miller on 6/10/17.
//

import Foundation
import Cairo
import Silica
import SDL
@testable import Cacao

struct TestPath {
    
    static let unitTests: String = try! createDirectory(at: NSTemporaryDirectory() + "CacaoTests" + "/")
    
    static let assets: String = try! createDirectory(at: unitTests + "TestAssets" + "/")
    
    static let testData: String = try! createDirectory(at: unitTests + "TestData" + "/", removeContents: true)
    
    private static func createDirectory(at filePath: String, removeContents: Bool = false) throws -> String {
        
        var isDirectory: ObjCBool = false
        
        if FileManager.default.fileExists(atPath: filePath, isDirectory: &isDirectory) == false {
            
            try! FileManager.default.createDirectory(atPath: filePath, withIntermediateDirectories: false)
        }
        
        if removeContents {
            
            // remove all files in directory (previous test cache)
            let contents = try! FileManager.default.contentsOfDirectory(atPath: filePath)
            
            contents.forEach { try! FileManager.default.removeItem(atPath: filePath + $0) }
        }
        
        return filePath
    }
}
