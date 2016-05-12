//
//  View.swift
//  Cacao
//
//  Created by Alsey Coleman Miller on 5/11/16.
//  Copyright © 2016 PureSwift. All rights reserved.
//

import Silica
import Cairo

public protocol View {
    
    var frame: Rect { get }
    
    func draw(context: Silica.Context)
}

