//
//  Button.swift
//  Cacao
//
//  Created by Alsey Coleman Miller on 5/28/16.
//  Copyright © 2016 PureSwift. All rights reserved.
//

import struct Foundation.CGFloat
import struct Foundation.CGPoint
import struct Foundation.CGSize
import struct Foundation.CGRect
import Silica

public final class UIButton: UIControl {
    
    // MARK: - Methods
    
    public override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        
        guard isHidden == false,
            alpha > 0,
            isUserInteractionEnabled,
            self.point(inside: point, with: event)
            else { return nil }
        
        // swallows touches intended for subviews
        
        return self
    }
    
    public override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        
        sendActions(for: .touchDown)
    }
    
    public override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        
        sendActions(for: .touchUpInside)
    }
}
 
