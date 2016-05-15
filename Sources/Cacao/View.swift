//
//  View.swift
//  Cacao
//
//  Created by Alsey Coleman Miller on 5/11/16.
//  Copyright © 2016 PureSwift. All rights reserved.
//

import Silica

public protocol View {
    
    var frame: Rect { get }
    
    var subviews: [View] { get }
    
    var needsLayout: Bool { get set }
    
    func draw(context: Silica.Context)
}