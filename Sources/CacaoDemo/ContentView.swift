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
    public var mode: UIContentMode { didSet { layoutSubviews() } }
    
    // MARK: - Initialization
    
    public init(frame: Rect = Rect(), content: View, mode: ContentMode = ContentMode()) {
        
        self.frame = frame
        self.content = content
        self.mode = mode
        self.size = content.frame.size
        self.layoutSubviews()
    }
    
    // MARK: - Methods
    
    public func layoutSubviews() {
        
        let bounds = Rect(size: frame.size)
        
        content.frame = mode.rect(for: bounds, size: size)
        
        // layout all subviews
        subviews.forEach { $0.layoutSubviews() }
    }
}
