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
    public var content: UIView? { didSet { contentChanged(oldValue) } }
    
    // MARK: - Methods
    
    public override func layoutSubviews() {
        
        guard let content = self.content
            else { return }
        
        content.frame = contentMode.rect(for: bounds, size: content.intrinsicContentSize)
    }
    
    @inline(__always)
    private func contentChanged(_ oldValue: UIView?) {
        
        oldValue?.removeFromSuperview()
        
        guard let view = content
            else { return }
        
        addSubview(view)
        
        sendSubview(toBack: view)
        
        layoutIfNeeded()
    }
}
