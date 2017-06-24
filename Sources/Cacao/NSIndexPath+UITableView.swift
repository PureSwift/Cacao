//
//  NSIndexPath+UITableView.swift
//  Cacao
//
//  Created by Alsey Coleman Miller on 6/24/17.
//

import struct Foundation.IndexPath

public extension IndexPath {
    
    var section: Int { return self[0] }
    var row: Int { return self[1] }

    init(row: Int, in section: Int) {
        
        self.init(indexes: [section, row])
    }
}
