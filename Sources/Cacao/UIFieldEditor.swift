//
//  UIFieldEditor.swift
//  Cacao
//
//  Created by Alsey Coleman Miller on 11/26/17.
//

import Foundation

internal final class UIFieldEditor: UIScrollView {
    
    var proxiedView: UIView? = nil
    
    public override var isFirstResponder: Bool {
        
        return proxiedView?.isFirstResponder ?? false
    }
}
