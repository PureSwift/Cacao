//
//  HelloWorldViewController.swift
//  Cacao
//
//  Created by Alsey Coleman Miller on 5/22/16.
//  Copyright © 2016 PureSwift. All rights reserved.
//

import Cacao
import Silica

final class HelloWorldViewController: ViewController {
    
    var needsDisplay: Bool = false
    
    func view(frame: Rect) -> View {
        
        let backgroundView = UIView(frame: frame)
        
        backgroundView.backgroundColor = UIColor(red: 0.0, green: 0.0, blue: 1.0)
        
        let logoView = SwiftLogoView(frame: Rect(x: 0, y: 0, width: 150, height: 150))
        
        backgroundView.addSubview(logoView)
        
        return backgroundView
    }
}