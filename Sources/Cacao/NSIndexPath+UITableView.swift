//
//  NSIndexPath+UITableView.swift
//  Cacao
//
//  Created by Alsey Coleman Miller on 6/24/17.
//

import struct Foundation.IndexPath

public extension IndexPath {
    
    var section: Int {
        
        @inline(__always)
        get { return self[0] }
    }
    
    var row: Int {
        
        @inline(__always)
        get { return self[1] }
    }

    @inline(__always)
    init(row: Int, section: Int) {
        
        self.init(indexes: [section, row])
    }
}
