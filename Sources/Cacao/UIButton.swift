//
//  Button.swift
//  Cacao
//
//  Created by Alsey Coleman Miller on 5/28/16.
//  Copyright © 2016 PureSwift. All rights reserved.
//

import Silica

public final class UIButton: UIControl {
    
    // MARK: - Methods
    
    public override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        
        guard isHidden == false
            && isUserInteractionEnabled
            && pointInside(point)
            else { return nil }
        
        // swallows touches intended for subviews
        
        return self
    }
    
    public override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        
        sendActions(for: .touchUpInside)
    }
}
 
