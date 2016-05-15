//
//  UIWindow.swift
//  Cacao
//
//  Created by Alsey Coleman Miller on 5/15/16.
//  Copyright © 2016 PureSwift. All rights reserved.
//

import Silica
import Cacao

public final class UIWindow: UIView {
    
    // MARK: - Properties
    
    public var rootViewController: UIViewController
    
    // MARK: - Initialization
    
    public init(frame: Rect, rootViewController: UIViewController) {
        
        self.rootViewController = rootViewController
        super.init(frame: frame)
    }
}