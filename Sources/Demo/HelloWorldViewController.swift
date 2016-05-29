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
    
    lazy var view: View = self.loadView()
    
    lazy var button: ContentView<SwiftLogoView> = ContentView(frame: Rect(x: 0, y: 0, width: 150, height: 150), content: SwiftLogoView(frame: Rect(x: 0, y: 0, width: 100, height: 100)))
    
    lazy var logoView: SwiftLogoView = SwiftLogoView(frame: Rect(x: 0, y: 0, width: 150, height: 150))
    
    private func loadView() -> UIView {
        
        let defaultFrame = Rect(size: Size(width: 320, height: 480))
        
        let backgroundView = UIView(frame: defaultFrame)
        
        backgroundView.backgroundColor = UIColor(red: 0.0, green: 0.0, blue: 1.0)
        
        backgroundView.addSubview(button)
        
        return backgroundView
    }
}