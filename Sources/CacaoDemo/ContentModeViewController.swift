//
//  ContentModeViewController.swift
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

import Cacao
import Silica

final class ContentModeViewController: UIViewController {
    
    // MARK: - Views
    
    private(set) var label: UILabel!
    
    private(set) var logoView: SwiftLogoView!
    
    private(set) var button: UIButton!
    
    private(set) var contentView: ContentView!
    
    // MARK: - Properties
    
    let modes: [UIViewContentMode] = [.center, .redraw, .scaleToFill, .scaleAspectFit, .scaleAspectFill, .top, .bottom, .left, .right, .topLeft, .topRight, .bottomLeft, .bottomRight]
    
    // MARK: - Loading
    
    internal override func loadView() {
        
        contentView = ContentView(frame: CGRect()) // since we dont use autoresizing, initial size doesnt matter
        
        label = UILabel(frame: CGRect()) // layoutSubviews will set size
        
        label.text = "\(self.modes[0])"
        
        logoView = SwiftLogoView()
        
        let button = UIButton(frame: CGRect())
        
        //button.action = changeMode
        
        label.textAlignment = .center
        
        contentView.addSubview(button)
        
        contentView.addSubview(label)
        
        contentView.content = logoView
        
        self.view = contentView
    }
    
    func layoutView() {
        
        let frame = view.frame
        
        // from Paint Code
        
        label.frame = Rect(x: frame.minX + floor(frame.width * 0.00000 + 0.5), y: frame.minY + floor(frame.height * 0.82812 + 0.5), width: floor(frame.width * 1.00000 + 0.5) - floor(frame.width * 0.00000 + 0.5), height: floor(frame.height * 1.00000 + 0.5) - floor(frame.height * 0.82812 + 0.5))
        
        button.frame = Rect(x: frame.minX + floor(frame.width * 0.00000 + 0.5), y: frame.minY + floor(frame.height * 0.00000 + 0.5), width: floor(frame.width * 1.00000 + 0.5) - floor(frame.width * 0.00000 + 0.5), height: floor(frame.height * 0.82812 + 0.5) - floor(frame.height * 0.00000 + 0.5))
    }
    
    // MARK: - Methods
 
    func changeMode(sender: UIButton) {
        
        let currentMode = contentView.contentMode
        
        let currentIndex = modes.index(of: currentMode)!
        
        var nextIndex = currentIndex + 1
        
        if currentIndex == modes.count - 1 {
            
            nextIndex = 0
        }
        
        let newMode = modes[nextIndex]
        
        contentView.contentMode = newMode
        
        label.text = "\(newMode)"
        
        print("Changing to \(newMode)")
    }
}
