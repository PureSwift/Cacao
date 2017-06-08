//
//  ContentView.swift
//  Cacao
//
//  Created by Alsey Coleman Miller on 5/29/16.
//  Copyright © 2016 PureSwift. All rights reserved.
//

#if os(Linux)
    import Glibc
#elseif os(macOS)
    import Darwin.C
#endif

import Silica
import Cacao

/// A view that lays out its content according to a `ContentMode`.
public final class ContentView: UIView {
    
    // MARK: - Properties
    
    /// Content view.
    public var content: UIView? { didSet { layoutSubviews() } }
    
    /// Content's display mode.
    public var mode: UIViewContentMode = .scaleAspectFill { didSet { layoutSubviews() } }
    
    // MARK: - Methods
    
    public override func layoutSubviews() {
        
        content?.frame = mode.rect(for: bounds, size: bounds.size)
        
        // layout all subviews
        subviews.forEach { $0.layoutSubviews() }
    }
}
