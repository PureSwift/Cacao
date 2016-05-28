//
//  View.swift
//  Cacao
//
//  Created by Alsey Coleman Miller on 5/27/16.
//  Copyright © 2016 PureSwift. All rights reserved.
//

import Silica

public protocol View {
    
    var frame: Rect { get set }
    
    var subviews: [View] { get set }
}

public protocol DrawableView: View {
    
    func draw(context: Silica.Context)
}
